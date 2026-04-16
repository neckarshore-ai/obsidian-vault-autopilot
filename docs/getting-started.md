# Getting Started

This guide walks you through your first safe run of Vault Autopilot — from installation to your first skill execution on a cloned vault. Follow these steps in order.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- An Obsidian vault (any structure, any size)

## Step 1 — Back Up Your Vault

Before anything else, make sure you have a restorable backup of your vault. See [Backup and Recovery](backup-and-recovery.md) for methods that work.

**Quick version for macOS (Time Machine users):** verify your latest backup includes your vault folder. `tmutil latestbackup` shows the timestamp.

**Quick version for Git users:** `git add . && git commit -m "pre-vault-autopilot snapshot"` in your vault directory.

## Step 2 — Clone Your Vault

Create a working copy to test on. **Never run skills on your production vault first.**

**macOS (recommended — preserves birthtimes):**

```bash
ditto -V "$HOME/Vaults/MyVault" "$HOME/Vaults/MyVault-Clone"
```

**macOS (Finder):** Right-click your vault folder → Duplicate. This works, but birthtimes reset to "now". You will need to run `property-enrich` first (Step 4).

**Windows:** Copy your vault folder in File Explorer (Ctrl+C → Ctrl+V in a new location). Birthtimes reset — `property-enrich` first is mandatory.

**Linux:**

```bash
rsync -aAX "$HOME/Vaults/MyVault/" "$HOME/Vaults/MyVault-Clone/"
```

For details on why the clone method matters, see [Cloning Guide](cloning-guide.md).

> **If you use Obsidian Sync:** disable it on both the source and the clone before proceeding. See [Cloning Guide — Obsidian Sync Must Be Off](cloning-guide.md#obsidian-sync-must-be-off).

## Step 3 — Install the Plugin

```bash
git clone https://github.com/neckarshore-ai/obsidian-vault-autopilot.git \
  ~/.claude/plugins/obsidian-vault-autopilot
```

Set your vault path to point at the **clone** (not your production vault):

```bash
export OBSIDIAN_VAULT_PATH="$HOME/Vaults/MyVault-Clone"
```

## Step 4 — Run `property-enrich` First

This is the most important step. `property-enrich` fills missing YAML `created` fields in your notes. Without these fields, the cooldown logic falls back to filesystem birthtime, which is unreliable on clones. See [Metadata Requirements](metadata-requirements.md) for the full explanation.

**Check your coverage first:**

```bash
cd "$OBSIDIAN_VAULT_PATH"
TOTAL=$(find . -name "*.md" -not -path "./.obsidian/*" -not -path "./_trash/*" | wc -l)
WITH_CREATED=$(grep -rl "^created:" --include="*.md" . 2>/dev/null | grep -v ".obsidian" | grep -v "_trash" | wc -l)
echo "Coverage: $((WITH_CREATED * 100 / TOTAL))% ($WITH_CREATED / $TOTAL)"
```

- **95% or higher:** you can skip to Step 5.
- **Below 95%:** run `property-enrich` now. It fills `created` from filename date patterns, filesystem metadata, or Git history. It does not move, rename, or delete any file.

After `property-enrich`, re-run the coverage check. It should be near 100%.

## Step 5 — Preview Before Running

Every skill supports `--preview` mode. Use it before any real execution:

```
inbox-sort --preview
```

The preview shows what would happen without changing any files. Check:

- Are the proposed moves sensible for your vault structure?
- Is the file count reasonable (not "0 files" — that may indicate a cooldown problem)?
- Are any files being moved that you want to stay put?

## Step 6 — Run Your First Skill

Once the preview looks right, run the skill for real. Start with a small scope if possible — a single folder rather than the entire vault.

**Recommended first-run order:**

| # | Skill | Why this order |
|---|-------|---------------|
| 1 | `property-enrich` | Fills metadata that other skills depend on |
| 2 | `note-rename` | Renames poorly-named files. Depends on metadata from Step 1 |
| 3 | `inbox-sort` | Sorts inbox files into folders. Works best after notes are properly named |

After each skill run, review the changes:

- Check `logs/run-history.md` for a record of what happened.
- Open a few affected notes in Obsidian to verify the changes look right.
- If anything looks wrong, the clone is disposable — delete it and start over.

## Step 7 — Decide About Production

Once you are satisfied with the results on the clone:

1. **Back up your production vault again** (a fresh backup, not the one from Step 1).
2. Point `OBSIDIAN_VAULT_PATH` at your production vault.
3. Run `--preview` first to see what would happen on production.
4. If the preview looks right, run the skill.

**There is no rush.** The clone is yours to experiment with. Run multiple skills, try different configurations, break things and re-clone. That is what clones are for.

## Troubleshooting

| # | Symptom | Likely cause | Fix |
|---|---------|-------------|-----|
| 1 | "0 files processed" on a vault with hundreds of notes | Cooldown is protecting everything — low YAML `created` coverage + fresh clone birthtimes | Run `property-enrich` first (Step 4) |
| 2 | Skill skips files you expected it to process | Files are newer than 3 days (cooldown) or match a protected pattern | Check `created` dates; adjust cooldown if needed |
| 3 | Files moved to `_secret/` unexpectedly | Secret detection found sensitive content (API keys, passwords, financial data) | Review the files — this is a safety feature |
| 4 | "Invalid frontmatter" errors in Obsidian after a run | Corrupted YAML — rare but possible | Restore from backup and file an [issue](https://github.com/neckarshore-ai/obsidian-vault-autopilot/issues) |

## Next Steps

- Read the [Safety section](../README.md#safety) for the full safety feature list.
- Read about the [Birthday Bug](incident-birthday-bug.md) to understand why metadata matters.
- Explore individual skill documentation in `skills/*/SKILL.md` for configuration options.
