use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use tauri::Manager;

/// Deploy bundled Claude resources (skills, agents, hooks, config) from the
/// Tauri resource directory to `~/.claude/`.
///
/// This runs once at app startup. Existing files are **never** overwritten —
/// only missing ones are copied. This means a fresh install gets the bundled
/// config automatically, while an existing user's customisations are preserved.
///
/// Failures are logged via `eprintln!` but do **not** block app startup.
///
/// Returns the total number of files/directories copied (useful for diagnostics / tests).
pub fn deploy_claude_resources(app: &tauri::AppHandle) -> u64 {
    let resource_dir = match app.path().resource_dir() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("[deploy] cannot resolve resource dir: {e}");
            return 0;
        }
    };

    let home = match home_dir() {
        Some(d) => d,
        None => {
            eprintln!("[deploy] cannot determine home directory");
            return 0;
        }
    };

    // Directory pairs: (source_relative, destination_relative_to_home)
    let dir_pairs: [(&str, &str); 3] = [
        ("bundled/claude/skills", ".claude/skills"),
        ("bundled/claude/agents", ".claude/agents"),
        ("bundled/claude/hooks", ".claude/hooks"),
    ];

    // File pairs: (source_relative, destination_relative_to_home)
    let file_pairs: [(&str, &str); 2] = [
        (
            "bundled/claude/scheduled_tasks.json",
            ".claude/scheduled_tasks.json",
        ),
        ("bundled/claude/settings.json", ".claude/settings.json"),
    ];

    let mut total = 0u64;

    // Deploy directories
    for (src_rel, dst_rel) in &dir_pairs {
        let src = resource_dir.join(src_rel);
        let dst = home.join(dst_rel);

        if !src.exists() {
            // Resources weren't bundled (e.g. dev mode / cargo run); skip silently.
            continue;
        }

        match copy_dir_all(&src, &dst, false) {
            Ok(n) => {
                if n > 0 {
                    println!("[deploy] deployed {n} files to {}", dst.display());
                }
                total += n;
            }
            Err(e) => {
                eprintln!("[deploy] failed to copy {}: {e}", dst.display());
            }
        }
    }

    // Deploy individual files (skip if target already exists)
    for (src_rel, dst_rel) in &file_pairs {
        let src = resource_dir.join(src_rel);
        let dst = home.join(dst_rel);

        if !src.exists() {
            continue;
        }

        if dst.exists() {
            continue;
        }

        if let Some(parent) = dst.parent() {
            if let Err(e) = fs::create_dir_all(parent) {
                eprintln!(
                    "[deploy] failed to create directory {}: {e}",
                    parent.display()
                );
                continue;
            }
        }

        match fs::copy(&src, &dst) {
            Ok(n) => {
                println!("[deploy] deployed {} ({} bytes)", dst.display(), n);
                total += 1;
            }
            Err(e) => {
                eprintln!("[deploy] failed to copy {}: {e}", dst.display());
            }
        }
    }

    total
}

/// Recursively copy `src` into `dst`.
///
/// When `overwrite` is `false`, existing files are **skipped** (the original is
/// kept).  When `true`, the source always replaces the destination.
///
/// Returns the number of files (not directories) copied.
fn copy_dir_all(src: &Path, dst: &Path, overwrite: bool) -> io::Result<u64> {
    fs::create_dir_all(dst)?;

    let mut count = 0u64;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let file_type = entry.file_type()?;
        let src_path = entry.path();
        let file_name = entry.file_name();
        let dst_path = dst.join(&file_name);

        if file_type.is_dir() {
            count += copy_dir_all(&src_path, &dst_path, overwrite)?;
        } else if file_type.is_file() || file_type.is_symlink() {
            if !overwrite && dst_path.exists() {
                continue;
            }
            fs::copy(&src_path, &dst_path)?;
            count += 1;
        }
    }
    Ok(count)
}

fn home_dir() -> Option<PathBuf> {
    std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .map(PathBuf::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn copy_dir_all_creates_nested_structure() {
        let tmp = tempfile::tempdir().unwrap();
        let src = tmp.path().join("src");
        let dst = tmp.path().join("dst");

        fs::create_dir_all(src.join("a").join("b")).unwrap();
        fs::write(src.join("a").join("b").join("c.txt"), "hello").unwrap();
        fs::write(src.join("root.txt"), "root").unwrap();

        let count = copy_dir_all(&src, &dst, false).unwrap();
        assert_eq!(count, 2);
        assert!(dst.join("a").join("b").join("c.txt").exists());
        assert!(dst.join("root.txt").exists());
        assert_eq!(fs::read_to_string(dst.join("root.txt")).unwrap(), "root");
    }

    #[test]
    fn copy_dir_all_skips_existing_when_not_overwrite() {
        let tmp = tempfile::tempdir().unwrap();
        let src = tmp.path().join("src");
        let dst = tmp.path().join("dst");

        fs::create_dir_all(&src).unwrap();
        fs::write(src.join("file.txt"), "new").unwrap();

        fs::create_dir_all(&dst).unwrap();
        fs::write(dst.join("file.txt"), "old").unwrap();

        let count = copy_dir_all(&src, &dst, false).unwrap();
        assert_eq!(count, 0);
        assert_eq!(fs::read_to_string(dst.join("file.txt")).unwrap(), "old");
    }

    #[test]
    fn copy_dir_all_overwrites_when_flag_set() {
        let tmp = tempfile::tempdir().unwrap();
        let src = tmp.path().join("src");
        let dst = tmp.path().join("dst");

        fs::create_dir_all(&src).unwrap();
        fs::write(src.join("file.txt"), "new").unwrap();

        fs::create_dir_all(&dst).unwrap();
        fs::write(dst.join("file.txt"), "old").unwrap();

        let count = copy_dir_all(&src, &dst, true).unwrap();
        assert_eq!(count, 1);
        assert_eq!(fs::read_to_string(dst.join("file.txt")).unwrap(), "new");
    }

    #[test]
    fn copy_dir_all_empty_src_creates_dst_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let src = tmp.path().join("empty");
        let dst = tmp.path().join("out");

        fs::create_dir_all(&src).unwrap();
        let count = copy_dir_all(&src, &dst, false).unwrap();
        assert_eq!(count, 0);
        assert!(dst.exists());
    }
}
