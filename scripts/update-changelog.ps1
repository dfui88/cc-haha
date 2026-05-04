param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "",

    [Parameter(Mandatory=$false)]
    [string]$Title = "",

    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot = ""
)

# 使用脚本所在目录的上级作为项目根目录
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}

$ChangelogPath = Join-Path $ProjectRoot "CHANGELOG.md"

# 获取最后一个版本标签
$lastTag = git -C $ProjectRoot tag --list "v*" --sort=-version:refname | Select-Object -First 1
$headHash = git -C $ProjectRoot rev-parse HEAD

if (-not $Version) {
    # 自动生成版本号：从最后标签 patch +1
    if ($lastTag -match 'v(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3] + 1
        $Version = "v$major.$minor.$patch"
    } else {
        $Version = "v0.1.0"
    }
}

if (-not $Title) {
    $Title = "版本 $Version"
}

# 获取上一个标签之后的提交（排除合并提交）
$tagRange = if ($lastTag) { "$lastTag..HEAD" } else { "HEAD" }
$commits = git -C $ProjectRoot log $tagRange --oneline --no-merges --format="%s"

if (-not $commits) {
    Write-Host "[错误] 从上次标签 ($lastTag) 到 HEAD 没有新提交，或者已经记录过了。"
    exit 0
}

# 按类型分类提交
$sections = @{
    "feat" = @()
    "fix" = @()
    "refactor" = @()
    "docs" = @()
    "test" = @()
    "perf" = @()
    "chore" = @()
    "other" = @()
}

foreach ($commit in $commits) {
    if ($commit -match '^(feat|fix|refactor|docs|test|perf|chore)[\(\w+\)]*:\s*(.*)') {
        $type = $Matches[1]
        $msg = $Matches[2]
        $sections[$type] += $msg
    } else {
        $sections["other"] += $commit
    }
}

# 构建新版本条目
$entryLines = @()

$entryLines += "## [$Version] — $Title"
$entryLines += ""

$typeMap = @{
    "feat" = "新增"
    "fix" = "修复"
    "refactor" = "重构"
    "docs" = "文档"
    "test" = "测试"
    "perf" = "性能"
    "chore" = "其他"
    "other" = "其他"
}

foreach ($type in @("feat", "fix", "refactor", "perf", "docs", "test", "chore", "other")) {
    $items = $sections[$type]
    if ($items.Count -eq 0) { continue }
    $entryLines += "### $($typeMap[$type])"
    $entryLines += ""
    foreach ($item in $items) {
        $entryLines += "- $item"
    }
    $entryLines += ""
}

# 读取现有 CHANGELOG，找到插入位置（在 --- 分隔线之后）
$existing = Get-Content $ChangelogPath -Raw
$separatorIndex = $existing.IndexOf("---", $existing.IndexOf("---") + 3)

if ($separatorIndex -ge 0) {
    # 在第一个 --- 之后插入
    $before = $existing.Substring(0, $separatorIndex + 4)  # 包括 ---
    $after = $existing.Substring($separatorIndex + 4)

    # 更新最后修改日期
    $date = Get-Date -Format "yyyy-MM-dd"
    $entryLines[0] += " ($date)"

    $newSection = "`n`n" + ($entryLines -join "`n")
    $newContent = $before + $newSection + $after
} else {
    # 没有分隔线，追加到末尾
    $date = Get-Date -Format "yyyy-MM-dd"
    $entryLines[0] += " ($date)"
    $newSection = "`n`n---`n`n" + ($entryLines -join "`n")
    $newContent = $existing.TrimEnd() + $newSection + "`n"
}

# 写入文件
$newContent | Set-Content $ChangelogPath -NoNewline

Write-Host "============================================"
Write-Host "CHANGELOG.md 已更新!"
Write-Host "版本: $Version"
Write-Host "提交数: $($commits.Count)"
Write-Host "============================================"
Write-Host ""
Write-Host "请检查变更，然后提交:"
Write-Host "  git add CHANGELOG.md"
Write-Host "  git commit -m 'docs: update changelog for $Version'"
Write-Host ""
