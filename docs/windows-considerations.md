# Windows Considerations

> **86% of Obsidian users are on Windows.** This document captures Windows-specific filesystem behavior that affects Vault Autopilot, based on empirical testing on Windows 11 (NTFS, German locale) on 2026-04-26.

## TL;DR for Windows Users

1. **Use `robocopy` to clone your vault, not File Explorer.** File Explorer (PowerShell `Copy-Item` underneath) silently drops files at long paths and resets file creation dates. `robocopy` preserves both.
2. **Enable Long Path support before running any skill.** Windows defaults to a 260-character path limit. Vaults with deep folder hierarchies and long descriptive folder names exceed this routinely. Without long path support enabled, Vault Autopilot skills cannot see those files and will silently skip them.
3. **Always run `property-enrich` first on a Windows clone.** Filesystem creation date is unreliable on Windows after copying. YAML `created` is the source of truth.

## Long Path Limit (MAX_PATH 260)

### What it is

Windows traditionally limited file paths to 260 characters total (drive + folders + filename + extension). Modern Windows 10/11 supports longer paths, but it must be **explicitly enabled** in the registry or per-application via manifest.

### Why it matters for Obsidian vaults

A typical OMNIXIS-style PARA vault routinely produces paths like:

```
C:\Users\<username>\Documents\Vaults\<vault-name>\010_Outcomes - WHAT I WANT - Everything with a concrete goal, decision, or expected result\10_Projects\10 - <Project Name> - <Description>\Components\<Component Name>\<Note Title>.md
```

That is 250+ characters before you reach the filename. One descriptive note title and you cross 260.

### What we measured

On a 1856-note vault (Mac-origin, transferred to Windows):

- **PowerShell `Get-ChildItem` could not enumerate ~14 subfolders** with paths exceeding 260 characters. Errors thrown silently per folder; the recursion continued but missed those files.
- **PowerShell `Copy-Item` (= File Explorer drag-drop) dropped 140 files** in cloning operations to the same destination. Same root cause: the API hits MAX_PATH and skips the file without raising a fatal error.
- **`robocopy /E` copied all 1856 files successfully.** Robocopy uses a different code path that bypasses MAX_PATH.

### Implications

| # | Risk | Affects |
|---|------|---------|
| 1 | Vault Autopilot skills cannot see files at long paths if MAX_PATH is not raised | All skills, all Windows users with deep vault structures |
| 2 | File Explorer-cloned vaults are missing files vs. source | Anyone who clones via Ctrl+C → Ctrl+V or drag-drop |
| 3 | Skills that scan `inbox/` may report "0 files" when actually some are at long paths | inbox-sort, note-quality-check |

### How to enable Long Path support on Windows

```powershell
# As administrator, run once:
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
# Then restart your shell (close and reopen the terminal).
```

This raises the limit to ~32,767 characters (UNC \\?\\ prefix mode). It is required for Vault Autopilot to operate correctly on vaults with deep folder structures.

After enabling, verify in PowerShell:

```powershell
(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").LongPathsEnabled
# Should return 1
```

## Clone Method Behavior — Measured 2026-04-26

We cloned the same 1856-note source vault three times using three methods, then measured file count and timestamp preservation.

| # | Method | Files copied | CreationTime preserved | LastWriteTime preserved |
|---|--------|--------------|------------------------|-------------------------|
| 1 | **`scp` from macOS** (reference) | 1856 / 1856 | No — set to transfer time | Yes |
| 2 | **PowerShell `Copy-Item`** (= File Explorer copy-paste) | 1716 / 1856 — **140 files dropped** | No — set to copy time | Yes |
| 3 | **`robocopy /E`** | 1856 / 1856 | **Yes — preserved from source** | Yes |

### What this means for Vault Autopilot's `created` field

The plugin's auto-enrich logic uses a fallback chain to determine the `created` YAML field when missing: filename date > git history > filesystem CreationTime.

On Windows, filesystem CreationTime is the **least reliable** source because it depends on how the file got there:

- If you cloned with **File Explorer** or **PowerShell Copy-Item**: CreationTime reflects when you copied the vault, not when the note was actually written. Auto-enrich will write that wrong date into your YAML.
- If you cloned with **`robocopy`**: CreationTime is preserved from the source, but the source itself may also have been a copy (chained copies all preserve the original).
- If your vault came from **macOS via SCP/AirDrop**: CreationTime is the transfer time, not the original write time.

### Recommendation

Always run `property-enrich` as the first skill on a Windows clone. It populates YAML `created` from filename patterns and git history when those are available, leaving filesystem CreationTime as the lowest-priority fallback. Once YAML `created` is filled, subsequent skills no longer depend on CreationTime.

## Recommended Windows Setup

Step-by-step before running any Vault Autopilot skill on Windows:

```powershell
# 1. Enable Long Path support (one-time, administrator)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force

# 2. Restart your shell, then verify
(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").LongPathsEnabled

# 3. Clone your vault with robocopy (NOT File Explorer)
robocopy "C:\Users\<you>\Documents\Vaults\MyVault" `
         "C:\Users\<you>\Documents\Vaults\MyVault-Clone" /E /COPY:DAT

# 4. Verify clone has the same file count as source
(Get-ChildItem "C:\Users\<you>\Documents\Vaults\MyVault" -Recurse -Filter *.md).Count
(Get-ChildItem "C:\Users\<you>\Documents\Vaults\MyVault-Clone" -Recurse -Filter *.md).Count
# Both numbers must match.

# 5. Set the vault path (use the clone, not the source, for first runs)
$env:OBSIDIAN_VAULT_PATH = "C:\Users\<you>\Documents\Vaults\MyVault-Clone"

# 6. Run property-enrich first (populates YAML `created` for everything)
# Then run other skills — by then, YAML is the source of truth and CreationTime is moot.
```

## Test Methodology

Source vault: 1856 Markdown files, mixed depth, OMNIXIS-style PARA structure with descriptive folder names. Original on macOS APFS. Transferred to Windows 11 NTFS via three methods on 2026-04-16, measured 2026-04-26.

Hardware: ThinkCentre M-class, Windows 11 22H2, German locale, NTFS. Path: `C:\Users\<user>\Documents\Vaults\`. SSH access via OpenSSH server.

Tools used: PowerShell 5.1, cmd.exe, `Get-ChildItem`, `Get-Item`, `robocopy`, `scp` (from macOS side).

Sample file used for timestamp comparison: `OPS - Phase 1.1 - Semantic Backbone (Concrete Execution).md` at vault root, identical content across all three clones.

## See Also

- [Cloning Guide](cloning-guide.md) — full clone procedure for macOS, Windows, Linux
- [Metadata Requirements](metadata-requirements.md) — why YAML `created` matters
- [Backup and Recovery](backup-and-recovery.md) — what to do if a skill misbehaves
