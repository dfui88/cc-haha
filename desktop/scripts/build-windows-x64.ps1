[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$TauriArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktopDir = (Resolve-Path (Join-Path $scriptDir '..')).Path
$repoRoot = (Resolve-Path (Join-Path $desktopDir '..')).Path

$targetTriple = 'x86_64-pc-windows-msvc'
$tauriTargetDir = Join-Path $desktopDir 'src-tauri\target'
$canonicalOutputDir = Join-Path $desktopDir 'build-artifacts\windows-x64'
$activeOutputDir = $canonicalOutputDir
$appVersion = (Get-Content -Path (Join-Path $desktopDir 'src-tauri\tauri.conf.json') -Raw | ConvertFrom-Json).version

$script:StartTime = Get-Date
function Write-Step {
  param([string]$Message)
  Write-Host "[build-windows-x64] $Message"
}

function Assert-WindowsHost {
  if ($env:OS -ne 'Windows_NT') {
    throw '[build-windows-x64] This script must run on Windows.'
  }
}

function Assert-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "[build-windows-x64] Missing required command: $Name"
  }
}

function Import-VsDevEnvironment {
  $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path $vswhere)) {
    throw '[build-windows-x64] Could not find vswhere.exe. Install Visual Studio 2022 Build Tools with the C++ workload.'
  }

  $installationPath = & $vswhere `
    -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath |
    Select-Object -First 1

  if (-not $installationPath) {
    throw '[build-windows-x64] Missing Visual C++ build tools. Install the "Desktop development with C++" / VC.Tools.x86.x64 workload first.'
  }

  $vsDevCmd = Join-Path $installationPath 'Common7\Tools\VsDevCmd.bat'
  if (-not (Test-Path $vsDevCmd)) {
    throw "[build-windows-x64] Could not find VsDevCmd.bat under $installationPath"
  }

  Write-Step "Importing MSVC environment from $vsDevCmd"

  $env:VSCMD_SKIP_SENDTELEMETRY = '1'
  $envDump = & cmd.exe /d /s /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "[build-windows-x64] Failed to initialize Visual Studio build environment (exit $LASTEXITCODE)"
  }

  foreach ($line in $envDump) {
    if ($line -match '^(.*?)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
  }
}

function Get-RustCargoBinDir {
  return Join-Path $env:USERPROFILE '.cargo\bin'
}

function Ensure-RustInPath {
  $cargoBinDir = Get-RustCargoBinDir
  if ((Test-Path $cargoBinDir) -and -not (($env:Path -split ';') -contains $cargoBinDir)) {
    $env:Path = "$cargoBinDir;$env:Path"
  }
}

function Get-LatestArtifact {
  param(
    [string[]]$SearchRoots,
    [string[]]$Patterns
  )

  foreach ($root in $SearchRoots) {
    if (-not (Test-Path $root)) {
      continue
    }

    foreach ($pattern in $Patterns) {
      $match = Get-ChildItem -Path $root -File -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -Last 1

      if ($match) {
        return $match
      }
    }
  }

  return $null
}

function Get-StagedArtifactName {
  param([string]$ArtifactName)

  $ver = $script:appVersion
  switch -Regex ($ArtifactName) {
    '^latest\.json$' { return 'latest.json' }
    '\.msi\.zip\.sig$' { return "Claude-Code-Haha_${ver}_windows_x64_zh-CN.msi.zip.sig" }
    '\.msi\.zip$' { return "Claude-Code-Haha_${ver}_windows_x64_zh-CN.msi.zip" }
    '\.msi\.sig$' { return "Claude-Code-Haha_${ver}_windows_x64_zh-CN.msi.sig" }
    '\.msi$' { return "Claude-Code-Haha_${ver}_windows_x64_zh-CN.msi" }
    default { return $ArtifactName }
  }
}

function Resolve-OutputDirectory {
  param([string]$PreferredPath)

  New-Item -ItemType Directory -Force -Path $PreferredPath | Out-Null

  $existingArtifacts = Get-ChildItem -Path $PreferredPath -Force -ErrorAction SilentlyContinue
  foreach ($artifact in $existingArtifacts) {
    try {
      Remove-Item -LiteralPath $artifact.FullName -Force -Recurse
    } catch {
      $fallbackPath = "$PreferredPath-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
      Write-Step "Could not clear locked artifact '$($artifact.FullName)'. Using fallback output directory: $fallbackPath"
      New-Item -ItemType Directory -Force -Path $fallbackPath | Out-Null
      return $fallbackPath
    }
  }

  return $PreferredPath
}

function Update-Version {
  param([string]$DesktopDir)

  $configPath = Join-Path $DesktopDir 'src-tauri\tauri.conf.json'
  $content = Get-Content $configPath -Raw
  if ($content -match '"version"\s*:\s*"(\d+)\.(\d+)\.(\d+)"') {
    $currentVersion = "{0}.{1}.{2}" -f $matches[1], $matches[2], $matches[3]
  } else {
    throw "[build-windows-x64] Could not parse version from tauri.conf.json"
  }

  $versionParts = $currentVersion -split '\.'
  $newVersion = "{0}.{1}.{2}" -f $versionParts[0], $versionParts[1], ([int]$versionParts[2] + 1)

  # Update tauri.conf.json
  $content -replace '("version"\s*:\s*)"[\d.]+"', "`$1`"$newVersion`"" | Set-Content $configPath -NoNewline

  # Update package.json
  $pkgPath = Join-Path $DesktopDir 'package.json'
  (Get-Content $pkgPath -Raw) -replace '("version"\s*:\s*)"[\d.]+"', "`$1`"$newVersion`"" | Set-Content $pkgPath -NoNewline

  # Update Cargo.toml
  $cargoPath = Join-Path $DesktopDir 'src-tauri\Cargo.toml'
  (Get-Content $cargoPath -Raw) -replace '(?m)^version = "[\d.]+"', "version = `"$newVersion`"" | Set-Content $cargoPath -NoNewline

  # Update the script-level variable so subsequent steps use the new version
  $script:appVersion = $newVersion

  Write-Step "Version bumped: $currentVersion -> $newVersion"
}

function Write-ReleaseNotes {
  param(
    [string]$OutputDir,
    [string]$Version
  )

  $notesPath = Join-Path $OutputDir "${Version}changelog.txt"
  $date = Get-Date -Format 'yyyy-MM-dd'

  # Collect release notes from env var or interactive input
  $notes = @()
  if ($env:RELEASE_NOTES) {
    $notes = $env:RELEASE_NOTES -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    Write-Step "Using release notes from RELEASE_NOTES env var"
  } elseif ($host.Name -ne 'ServerMode' -and $host.UI.RawUI.WindowSize) {
    try {
      Write-Host ""
      Write-Host "=== Enter release notes for v$Version (leave blank line to finish) ===" -ForegroundColor Cyan
      $notes = @()
      do {
        $line = Read-Host "  -"
        if ($line -ne '') { $notes += $line }
      } while ($line -ne '')
      Write-Host "==========================================" -ForegroundColor Cyan
    } catch {
      $notes = @("Auto build")
      Write-Step "Non-interactive mode, using default release notes"
    }
  } else {
    $notes = @("Auto build")
    Write-Step "No RELEASE_NOTES set and non-interactive, using default note"
  }

  # Build new entry
  $header = "v$Version ($date)"
  $separator = "-" * $header.Length
  $entry = @(
    $header
    $separator
    ($notes | ForEach-Object { "- $_" })
    ""
  )

  # Prepend to existing file or create new
  $existing = @()
  if (Test-Path $notesPath) {
    $existing = Get-Content $notesPath
  }
  ($entry + $existing) | Set-Content $notesPath -Encoding UTF8

  Write-Step "Release notes written: $notesPath ($($notes.Count) changes)"
}

Assert-WindowsHost
Assert-Command bun

Ensure-RustInPath
Import-VsDevEnvironment

Assert-Command cargo
Assert-Command rustc
Assert-Command bunx

# Smart dependency check - skip bun install when node_modules already exist
# Set $env:FORCE_INSTALL = "1" to force re-install
$skipInstall = $env:SKIP_INSTALL -eq '1'
if (-not $skipInstall) {
    $needRoot = -not (Test-Path (Join-Path $repoRoot 'node_modules'))
    $needDesktop = -not (Test-Path (Join-Path $desktopDir 'node_modules'))
    $adaptersDir = Join-Path $repoRoot 'adapters'
    $adaptersPkg = Join-Path $adaptersDir 'package.json'
    $needAdapters = (Test-Path $adaptersPkg) -and -not (Test-Path (Join-Path $adaptersDir 'node_modules'))

    if ($needRoot -or $needDesktop -or $needAdapters -or $env:FORCE_INSTALL -eq '1') {

        Write-Step 'Installing root dependencies...'
        Push-Location $repoRoot
        try { & bun install; if ($LASTEXITCODE -ne 0) { throw "[build-windows-x64] bun install failed in repo root (exit $LASTEXITCODE)" } }
        finally { Pop-Location }

        Write-Step 'Installing desktop dependencies...'
        Push-Location $desktopDir
        try { & bun install; if ($LASTEXITCODE -ne 0) { throw "[build-windows-x64] bun install failed in desktop (exit $LASTEXITCODE)" } }
        finally { Pop-Location }

        if (Test-Path $adaptersPkg) {
            Write-Step 'Installing adapter dependencies...'
            Push-Location $adaptersDir
            try { & bun install; if ($LASTEXITCODE -ne 0) { throw "[build-windows-x64] bun install failed in adapters (exit $LASTEXITCODE)" } }
            finally { Pop-Location }
        }

    } else {
        Write-Step "Dependencies up-to-date, skipping bun install (set FORCE_INSTALL=1 to force)"
    }
} else {
    Write-Step "Skipping bun install (SKIP_INSTALL=1)"
}
$tauriBuildArgs = @(
  'tauri',
  'build',
  '--target',
  $targetTriple,
  '--bundles',
  'msi',
  '--ci'
)

$tempConfigPath = $null
if (-not $env:TAURI_SIGNING_PRIVATE_KEY) {
  # Fallback: read from TAURI_SIGNING_PRIVATE_KEY_PATH if set
  if ($env:TAURI_SIGNING_PRIVATE_KEY_PATH -and (Test-Path $env:TAURI_SIGNING_PRIVATE_KEY_PATH)) {
    $env:TAURI_SIGNING_PRIVATE_KEY = Get-Content $env:TAURI_SIGNING_PRIVATE_KEY_PATH -Raw
    Write-Step "TAURI_SIGNING_PRIVATE_KEY loaded from $($env:TAURI_SIGNING_PRIVATE_KEY_PATH)"
  }
}

if (-not $env:TAURI_SIGNING_PRIVATE_KEY) {
  $tempConfigPath = Join-Path ([System.IO.Path]::GetTempPath()) 'cc-haha.tauri.local.windows.json'
  $tempConfig = @{
    bundle = @{
      createUpdaterArtifacts = $false
    }
  } | ConvertTo-Json -Depth 10
  Set-Content -Path $tempConfigPath -Value $tempConfig -Encoding UTF8
  Write-Step 'TAURI_SIGNING_PRIVATE_KEY not set, disabling updater artifacts for local build'
  $tauriBuildArgs += @('--config', $tempConfigPath)
}

if ($null -ne $TauriArgs) {
  $remainingArgs = @($TauriArgs)
  if ($remainingArgs.Count -gt 0) {
    $tauriBuildArgs += $remainingArgs
  }
}

# Force sidecar timestamp to current build time so the packaged MSI
# reflects the correct build date instead of the original compile time
$sidecarPaths = @(
  (Join-Path $tauriTargetDir "$targetTriple\release\claude-sidecar.exe"),
  (Join-Path $desktopDir "src-tauri\binaries\claude-sidecar-$targetTriple.exe")
)
foreach ($p in $sidecarPaths) {
  if (Test-Path $p) {
    Write-Step "Updating timestamp: $p"
    (Get-Item $p).LastWriteTime = Get-Date
  }
}

# Bump patch version before each build so users can distinguish MSI versions
Update-Version -DesktopDir $desktopDir

# Prepare output directory early (before cargo build) so notes files survive
# even if the Bash tool 10-minute timeout kills the process post-build.
$activeOutputDir = Resolve-OutputDirectory -PreferredPath $canonicalOutputDir

# Gather build environment info while we can (git, toolchain versions)
$gitCommit = & git -C $repoRoot log --oneline -1 2>$null
if (-not $gitCommit) { $gitCommit = 'N/A' }
$gitBranch = & git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null
if (-not $gitBranch) { $gitBranch = 'N/A' }
$osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
if (-not $osInfo) { $osInfo = 'Windows' }
$bunVersion = & bun --version 2>$null
if (-not $bunVersion) { $bunVersion = 'N/A' }
$rustVersion = & rustc --version 2>$null
if (-not $rustVersion) { $rustVersion = 'N/A' }

# Write BUILD_NOTES.txt early (insurance: if build times out, notes still exist)
$msiPlaceholder = '(see BUILD_NOTES.txt after build completes)'
$buildNotes = @(
    "========================================"
    "  Claude Code Haha - Build Notes"
    "========================================"
    ""
    "Version      : $appVersion"
    "Build time   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    "Target       : $targetTriple"
    "OS           : $osInfo"
    ""
    "--- Git ---"
    "Branch       : $gitBranch"
    "Commit       : $gitCommit"
    ""
    "--- Toolchain ---"
    "Bun          : $bunVersion"
    "Rust         : $rustVersion"
    ""
    "--- Output ---"
    "MSI (zh-CN)  : $msiPlaceholder"
    "Output dir   : $activeOutputDir"
    ""
    "--- Prerequisites ---"
    "1. Visual Studio 2022 Build Tools (C++ workload)"
    "2. Rust (rustup) and Bun"
    "3. Run: .\scripts\build-windows-x64.ps1"
    ""
    "--- System Requirements ---"
    "OS           : Windows 10 1809+ / Windows 11"
    "Arch         : x86_64"
    "WebView2     : Built-in on Win11, download required on Win10"
    ""
    "--- Installation ---"
    "Double-click the MSI file to install."
    "Launch Claude Code Haha from the Start Menu after installation."
    ""
    "--- Signing ---"
    $(if ($env:TAURI_SIGNING_PRIVATE_KEY) { "Signed (TAURI_SIGNING_PRIVATE_KEY configured)" } else { "Not signed (local/dev build)" })
    ""
    "========================================"
)
Set-Content -Path (Join-Path $activeOutputDir 'BUILD_NOTES.txt') -Value $buildNotes -Encoding UTF8
Write-Step "Build notes written early: $(Join-Path $activeOutputDir 'BUILD_NOTES.txt')"

# Collect fix notes from env var (semicolon-separated)
$fixNotesLines = @()
if ($env:FIX_NOTES) {
    $fixNotesLines = $env:FIX_NOTES -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    Write-Step "Using fix notes from FIX_NOTES env var"
} else {
    $fixNotesLines = @("额外修复内容")
    Write-Step "No FIX_NOTES set, using default"
}

# Write fix+version.txt early (Chinese repair notes)
$repairNotes = @(
    "================================"
    "  Claude Code Haha - 构建修复说明"
    "================================"
    ""
    "版本号        : $appVersion"
    "构建时间      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    "目标平台      : $targetTriple"
    ""
    "--- Git ---"
    "分支          : $gitBranch"
    "提交          : $gitCommit"
    ""
    "--- 构建工具 ---"
    "Bun           : $bunVersion"
    "Rust          : $rustVersion"
    ""
    "--- 输出 ---"
    "MSI 安装包    : $msiPlaceholder"
    "输出目录      : $activeOutputDir"
    ""
    "--- 系统要求 ---"
    "操作系统      : Windows 10 1809+ / Windows 11"
    "架构          : x86_64"
    ""
    "--- 安装说明 ---"
    "双击 MSI 文件即可安装。安装完成后从开始菜单启动 Claude Code Haha。"
    ""
    "================================"
    "--- 修复说明 ---"
    ($fixNotesLines | ForEach-Object { "$_" })
    "================================"
)
Set-Content -Path (Join-Path $activeOutputDir "fix+$appVersion.txt") -Value $repairNotes -Encoding UTF8
Write-Step "修复说明已生成(early): fix+$appVersion.txt"

Write-Step "Building Windows desktop app for $targetTriple"

Push-Location $desktopDir
try {
  $env:TAURI_ENV_TARGET_TRIPLE = $targetTriple
  & bunx @tauriBuildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "[build-windows-x64] tauri build failed (exit $LASTEXITCODE)"
  }
} finally {
  Pop-Location
  if ($tempConfigPath -and (Test-Path $tempConfigPath)) {
    Remove-Item -LiteralPath $tempConfigPath -Force
  }
}

# NOTE: Resolve-OutputDirectory already ran before cargo build (see above).
# Skipping it here to preserve early-written notes and freshly-copied artifacts.
# $activeOutputDir is already set from the pre-build call.

$bundleRoots = @(
  (Join-Path $tauriTargetDir "$targetTriple\release\bundle"),
  (Join-Path $tauriTargetDir 'release\bundle')
)

$artifactPatterns = @('*.msi', '*.msi.sig', '*.msi.zip', '*.msi.zip.sig', 'latest.json')
$copiedArtifacts = New-Object System.Collections.Generic.List[string]

foreach ($root in $bundleRoots) {
  if (-not (Test-Path $root)) {
    continue
  }

  foreach ($pattern in $artifactPatterns) {
    # Only copy the most recently built artifact (skip older historical MSI artifacts)
    $artifacts = Get-ChildItem -Path $root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    foreach ($artifact in $artifacts) {
      # Skip en-US MSI — only copy zh-CN to output directory
      if ($artifact.Name -match '_en-US\.msi') {
        Write-Step "Skipping en-US MSI: $($artifact.Name)"
        continue
      }
      $destinationName = Get-StagedArtifactName -ArtifactName $artifact.Name
      $destination = Join-Path $activeOutputDir $destinationName
      try {
        Copy-Item -LiteralPath $artifact.FullName -Destination $destination -Force -ErrorAction Stop
      } catch {
        Write-Step "WARNING: Could not copy artifact '$($artifact.Name)': $_"
        continue
      }
      # Update timestamp to current build time (Copy-Item preserves source timestamp)
      (Get-Item $destination).LastWriteTime = Get-Date

      # Force MSI ProductLanguage to 2052 (zh-CN) so installer UI shows Chinese
      if ($destination -match '\.msi$' -and -not ($destination -match '\.msi\.(sig|zip)$')) {
        try {
          $msiDb = (New-Object -ComObject WindowsInstaller.Installer).OpenDatabase($destination, 1)
          $view = $msiDb.OpenView("UPDATE \`"Property\`" SET \`"Value\`"='2052' WHERE \`"Property\`"='ProductLanguage'")
          $view.Execute()
          $view.Close()
          $msiDb.Commit()
          [System.Runtime.Interopservices.Marshal]::ReleaseComObject($msiDb) | Out-Null
          Write-Step "Forced ProductLanguage to 2052 (zh-CN) for MSI: $destinationName"
        } catch {
          Write-Step "WARNING: Could not set ProductLanguage for MSI: $_"
        }
      }
      if (-not $copiedArtifacts.Contains($destination)) {
        $copiedArtifacts.Add($destination) | Out-Null
      }
    }
  }
}

$msiInstaller = Get-LatestArtifact -SearchRoots @(
  (Join-Path $tauriTargetDir "$targetTriple\release\bundle\msi"),
  (Join-Path $tauriTargetDir 'release\bundle\msi')
) -Patterns @('*_zh-CN.msi')

$msiInstallerPath = if ($msiInstaller) { $msiInstaller.FullName } else { 'not found' }

$buildInfo = @(
  "App version: $appVersion"
  "Target triple: $targetTriple"
  "Canonical output: $canonicalOutputDir"
  "Actual output: $activeOutputDir"
  "Windows installer (MSI): $msiInstallerPath"
  "Artifacts copied: $($copiedArtifacts.Count)"
  "Built at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
)

Set-Content -Path (Join-Path $activeOutputDir 'BUILD_INFO.txt') -Value $buildInfo -Encoding UTF8

# Prompt for release notes so users can see what changed in this build
# Pre-set to avoid Read-Host hanging in non-interactive mode (e.g. CI / background)
if (-not $env:RELEASE_NOTES) { $env:RELEASE_NOTES = 'Auto build' }
try {
  Write-ReleaseNotes -OutputDir $activeOutputDir -Version $script:appVersion
} catch {
  Write-Step "WARNING: Write-ReleaseNotes failed: $_"
}

# Generate latest.json for Tauri updater (Tauri 2.x does not produce this automatically)
function Write-LatestJson {
  param(
    [string]$OutputDir,
    [string]$Version,
    [string]$SignaturePath,
    [string]$MsiName
  )

  if (-not (Test-Path $SignaturePath)) {
    Write-Step "WARNING: Signature file not found at $SignaturePath, skipping latest.json"
    return
  }

  # Read signature as raw text (not PowerShell object) to avoid extra properties
  $signature = [System.IO.File]::ReadAllText($SignaturePath).Trim()
  $utcDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  $latestJson = @{
    version  = $Version
    notes    = "Auto build v$Version"
    pub_date = $utcDate
    platforms = @{
      "windows-x86_64" = @{
        signature = $signature
        url       = "https://github.com/dfui88/cc-haha/releases/download/v$Version/$MsiName"
      }
    }
  }

  $jsonPath = Join-Path $OutputDir 'latest.json'
  $latestJson | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
  Write-Step "latest.json generated: $jsonPath"
}

# Generate latest.json from the zh-CN .msi.sig
$zhSigPath = Join-Path $activeOutputDir "Claude-Code-Haha_${appVersion}_windows_x64_zh-CN.msi.sig"
$zhMsiName = "Claude-Code-Haha_${appVersion}_windows_x64_zh-CN.msi"
if (Test-Path $zhSigPath) {
  Write-LatestJson -OutputDir $activeOutputDir -Version $appVersion -SignaturePath $zhSigPath -MsiName $zhMsiName
} else {
  Write-Step "WARNING: zh-CN .msi.sig not found at $zhSigPath, skipping latest.json"
}

# Wrapper to prevent post-build errors from silently stopping the script
  # Generate human-readable build notes (BUILD_NOTES.txt) alongside the MSI.
# Using English-only strings in the script to avoid Windows PowerShell encoding
# issues with non-ASCII characters.
$buildNotesPath = Join-Path $activeOutputDir "BUILD_NOTES.txt"
$gitCommit = & git -C $repoRoot log --oneline -1 2>$null
if (-not $gitCommit) { $gitCommit = 'N/A' }
$gitBranch = & git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null
if (-not $gitBranch) { $gitBranch = 'N/A' }
$osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
if (-not $osInfo) { $osInfo = 'Windows' }
$bunVersion = & bun --version 2>$null
if (-not $bunVersion) { $bunVersion = 'N/A' }
$rustVersion = & rustc --version 2>$null
if (-not $rustVersion) { $rustVersion = 'N/A' }

$buildNotes = @(
  "========================================"
  "  Claude Code Haha - Build Notes"
  "========================================"
  ""
  "Version      : $appVersion"
  "Build time   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
  "Target       : $targetTriple"
  "OS           : $osInfo"
  ""
  "--- Git ---"
  "Branch       : $gitBranch"
  "Commit       : $gitCommit"
  ""
  "--- Toolchain ---"
  "Bun          : $bunVersion"
  "Rust         : $rustVersion"
  ""
  "--- Output ---"
  "MSI (zh-CN)  : $msiInstallerPath"
  "Output dir   : $activeOutputDir"
  ""
  "--- Prerequisites ---"
  "1. Visual Studio 2022 Build Tools (C++ workload)"
  "2. Rust (rustup) and Bun"
  "3. Run: .\scripts\build-windows-x64.ps1"
  ""
  "--- System Requirements ---"
  "OS           : Windows 10 1809+ / Windows 11"
  "Arch         : x86_64"
  "WebView2     : Built-in on Win11, download required on Win10"
  ""
  "--- Installation ---"
  "Double-click the MSI file to install."
  "Launch Claude Code Haha from the Start Menu after installation."
  ""
  "--- Signing ---"
  $(
    if ($env:TAURI_SIGNING_PRIVATE_KEY) {
      "Signed (TAURI_SIGNING_PRIVATE_KEY configured)"
    } else {
      "Not signed (local/dev build)"
    }
  )
  ""
  "========================================"
)
Set-Content -Path $buildNotesPath -Value $buildNotes -Encoding UTF8
Write-Step "Build notes written: $buildNotesPath"

Write-Host ''
Write-Step 'Build finished.'
Write-Step "Artifacts output: $activeOutputDir"
if ($msiInstaller) {
  Write-Step "MSI installer source: $($msiInstaller.FullName)"
} else {
  Write-Step 'No MSI installer found under bundle directories.'
}


# Generate Chinese repair notes (fix+version.txt)
$repairNotesPath = Join-Path $activeOutputDir "fix+$appVersion.txt"
$repairNotes = @(
    "================================"
    "  Claude Code Haha - 构建修复说明"
    "================================"
    ""
    "版本号        : $appVersion"
    "构建时间      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    "目标平台      : $targetTriple"
    ""
    "--- Git ---"
    "分支          : $gitBranch"
    "提交          : $gitCommit"
    ""
    "--- 构建工具 ---"
    "Bun           : $bunVersion"
    "Rust          : $rustVersion"
    ""
    "--- 输出 ---"
    "MSI 安装包    : $msiInstallerPath"
    "输出目录      : $activeOutputDir"
    ""
    "--- 系统要求 ---"
    "操作系统      : Windows 10 1809+ / Windows 11"
    "架构          : x86_64"
    ""
    "--- 安装说明 ---"
    "双击 MSI 文件即可安装。安装完成后从开始菜单启动 Claude Code Haha。"
    ""
    "================================"
    "--- 修复说明 ---"
    ($fixNotesLines | ForEach-Object { "$_" })
    "================================"
)
Set-Content -Path $repairNotesPath -Value $repairNotes -Encoding UTF8
Write-Step "修复说明已生成: $repairNotesPath"
Write-Step "Canonical output: $canonicalOutputDir"
Write-Step "Opening build output folder..."
try { Invoke-Item $canonicalOutputDir } catch { Write-Step "Could not open output folder" }

# Display elapsed time
$elapsed = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 0)
$elapsedStr = if ($elapsed -ge 60) { "{0}m {1}s" -f [math]::Floor($elapsed/60), ($elapsed % 60) } else { "${elapsed}s" }

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE!" -ForegroundColor Green
Write-Host "  Version : $appVersion" -ForegroundColor Green
Write-Host "  Elapsed : $elapsedStr" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Play system notification sound
try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }

# Show Windows 10/11 toast notification
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = "Build Complete"
    $notify.BalloonTipText = "Claude Code Haha v$appVersion built in $elapsedStr"
    $notify.Visible = $true
    $notify.ShowBalloonTip(5000)
    Start-Sleep -Seconds 5
    $notify.Dispose()
    Write-Step "Toast notification sent"
} catch {
    Write-Step "Toast notification unavailable (non-interactive session)"
}


