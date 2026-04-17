# Cloning Guide

**Cloning is not optional.** Running destructive automation directly on your production vault is how people lose data. Clone first, test on the clone, then decide whether to run on production.

## Why Clone

1. **Safety.** If a skill misbehaves, your production vault is untouched.
2. **Cooldown verification.** Skills protect files newer than 3 days (configurable). On a clone, you can run `--preview` to see whether the cooldown is triggering correctly before you touch production.
3. **Confidence.** You get to see exactly what the skill will do to your files, in your structure, with your content — not in a synthetic test vault.

## Obsidian Sync Must Be Off

> **Read this twice.** Obsidian Sync on a cloned vault is the single most dangerous mistake a user can make with this plugin.

If Obsidian Sync is active on your original vault and you clone it into a folder Sync can see (a subfolder of your iCloud Drive, for example), the following can happen:

1. Sync sees the clone as "new device state".
2. You run `inbox-sort` on the clone.
3. Sync propagates the file moves back to your production vault.
4. You just ran a destructive skill on production without meaning to.

**Before you clone, disable Sync on the source vault:**

1. Open your vault in Obsidian.
2. Settings → Sync → Disable current vault from Sync, or pause Sync entirely.
3. Verify `.obsidian/sync.json` reflects the disabled state.
4. **Then** clone.

After cloning, open the clone in Obsidian once (if you plan to) and verify Sync is also off on the clone.

## Clone Methods — Choose the Right One for Your OS

Not all copy methods are equal. The critical difference is **filesystem birthtime**: some methods preserve it, others reset it to "now". This matters because the plugin uses birthtime as a fallback when YAML `created` is missing (see [Metadata Requirements](metadata-requirements.md)).

### macOS

| # | Method | Preserves birthtime? | Recommended? | Notes |
|---|--------|---------------------|--------------|-------|
| 1 | **`ditto -V` (Terminal)** | **Yes** | **Yes — best option** | Preserves birthtimes, xattrs, and resource forks |
| 2 | **Finder copy** (Cmd+D, Right-click → Duplicate, drag+Option) | **Yes** — preserves on APFS (macOS 10.13+) | **Yes — safe** | Birthtimes preserved; most users will use this |
| 3 | **`cp -R`** (Terminal) | **No** — resets to now | Acceptable if YAML `created` coverage is high | Common for scripted copies; does not preserve birthtime |
| 4 | **APFS `cp -c`** (clonefile) | N/A (shared inodes) | **Not recommended** | Copy-on-Write clones share inodes with the original — unsafe for destructive automation |

**If you use `cp -R`:** your clone will have fresh birthtimes on every file. The plugin's cooldown logic may treat all notes as "new" and skip them. This is the [silent clone-killer](incident-birthday-bug.md). The workaround: run `property-enrich` as your first skill on the clone to fill YAML `created` fields. After that, filesystem birthtime becomes irrelevant.

**If you use `ditto -V` or Finder:** birthtimes are preserved and cooldown works correctly out of the box.

### Windows

| # | Method | Preserves creation date? | Recommended? | Notes |
|---|--------|-------------------------|--------------|-------|
| 1 | **File Explorer copy** (Ctrl+C → Ctrl+V) | **No** — resets to now | Acceptable with workaround | Run `property-enrich` first on the clone |
| 2 | **`robocopy /COPY:DAT`** | **Partial** — copies timestamps but behavior varies | Acceptable | Check results with `dir /TC` after copy |
| 3 | **`xcopy /K`** | **No** | Acceptable with workaround | Same as Explorer copy |

On Windows, all common copy methods reset the creation date. **Always run `property-enrich` as your first skill** on a Windows clone.

### Linux

| # | Method | Preserves birthtime? | Recommended? | Notes |
|---|--------|---------------------|--------------|-------|
| 1 | **`rsync -aAX`** | No (Linux ext4/btrfs do not track birthtime) | **Yes — best option** | Preserves permissions, xattrs, timestamps (mtime/atime) |
| 2 | **`cp -a`** | No | Acceptable | Same birthtime limitation as rsync |

Linux filesystems (ext4, btrfs, XFS) generally do not track file birthtime at all. This means cooldown always falls back to YAML `created`. **Run `property-enrich` first on any Linux clone.**

## Recommended Clone Procedure (macOS)

```bash
# 1. Close Obsidian on the source vault.
# 2. Disable Sync in Obsidian Settings on the source vault (see above).

# 3. Clone with ditto (preserves birthtimes on macOS):
ditto -V "$HOME/Vaults/MyVault" "$HOME/Vaults/MyVault-Clone-$(date +%Y%m%d)"

# 4. Verify the clone has the expected file count:
SOURCE_COUNT=$(find "$HOME/Vaults/MyVault" -name "*.md" | wc -l)
CLONE_COUNT=$(find "$HOME/Vaults/MyVault-Clone-$(date +%Y%m%d)" -name "*.md" | wc -l)
echo "Source: $SOURCE_COUNT / Clone: $CLONE_COUNT"
# Counts must match.
```

**If you used `cp -R` instead of `ditto` or Finder:** birthtimes are reset. Run `property-enrich` as your first skill to fill YAML `created` fields before testing any other skill.

## Post-Clone Checklist

Before you run any skill on the clone, verify:

1. **Sync is off on the clone.** Confirmed visually in Obsidian Settings → Sync or via:
   ```bash
   cat "$HOME/Vaults/MyVault-Clone-*/  .obsidian/sync.json" 2>/dev/null || echo "No sync.json — good."
   ```
2. **File count matches source.** `find <clone> -name "*.md" | wc -l` equals the same command on the source.
3. **YAML `created` coverage.** See the [Pre-Run Metadata Check](metadata-requirements.md#pre-run-metadata-check) script.
   - If coverage is 95% or higher: good, skills will use YAML for cooldown.
   - If coverage is below 95%: **stop.** Run `property-enrich` first (see [Getting Started](getting-started.md)).
4. **Preview run.** Point `OBSIDIAN_VAULT_PATH` at the clone and run `inbox-sort --preview`. The skill should print a preview without changing files. Confirm the preview matches your expectations.
5. **Cooldown sanity check.** If the preview shows all files skipped by cooldown, the silent clone-killer may be active — YAML `created` coverage is insufficient. Run `property-enrich` first.

## Recovery If Something Goes Wrong on the Clone

- **Skill moved files to wrong folders:** check `logs/run-history.md` for the exact moves. Revert manually or re-clone.
- **Skill soft-deleted files:** check `_trash/` — every trashed file has `trash_source` and `trash_origin` in frontmatter.
- **YAML is corrupt:** re-clone from source. The clone is disposable — that is the point.
- **Whole clone state looks wrong:** delete the clone and start over. Your production vault is untouched.

For production vault recovery, see [Backup and Recovery](backup-and-recovery.md).
