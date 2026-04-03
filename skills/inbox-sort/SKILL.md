---
name: inbox-sort
description: Use when an Obsidian vault inbox is cluttered and notes need sorting into subfolders. Trigger phrases - "sort inbox", "clean up inbox", "triage inbox", "organize inbox", "inbox is cluttered", "too many notes in inbox". Also trigger when the user mentions reducing inbox size or doing a first pass on unprocessed notes.
---

# Inbox Sort

Move notes from inbox root into existing subfolders. Fast, reliable, no over-analysis.

## Principle: Core + Nahbereich + Report

- **Core:** Categorize and move notes into subfolders
- **Nahbereich:** Delete confirmed empty files (0 bytes or whitespace only)
- **Report:** Summary of moves, findings, improvement suggestions

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. Use file creation date (birthtime), not modification date. |

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask the user.
2. **Find inbox** — scan top-level folders for one containing "inbox" (case-insensitive). If ambiguous, ask.
3. **Read subfolders** — list all immediate subdirectories of the inbox. These are the available categories. If none exist, stop and tell the user to create subfolders first.
4. **List inbox root notes** — only `.md` files directly in the inbox root, not in subfolders.
5. **Apply cooldown** — skip notes created less than `cooldown_days` ago (grace period for active work). Use file creation date, not modification date.
6. **Nahbereich pass** — delete files that are empty (0 bytes or whitespace only). Log each deletion.
7. **Pre-sort routing** — before categorizing, auto-route by pattern:
   - `YYYY-MM-DD.md` or `YYYY-MM-DD *.md` → subfolder containing "daily" (case-insensitive)
   - Web captures and social posts (see `references/web-capture-detection.md`) → matching subfolder
   - Skip if no matching subfolder exists
8. **Categorize remaining notes** — read title, tags, and first ~30 lines. Assign to one subfolder:
   - Match note content against subfolder names semantically
   - When truly ambiguous, prefer the subfolder whose name suggests "TBD", "unsorted", or similar
   - When no TBD folder exists, skip the note and list it in the report
9. **Move files** — use Bash `mv` with proper quoting for special characters. Preserve original filenames.
10. **Write report** — see format below.

## Protected Files

Never move, rename, or process these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Boundaries

- No renaming files
- No deep analysis, no creating subfolders, no editing content
- No processing notes already in subfolders or non-markdown files

## Report Format

```
## Inbox Sort Report — [Date]

### Done
- [Subfolder]: X notes moved
- Empty files deleted: X (Nahbereich)

### Skipped
- Cooldown (< [cooldown_days] days): X notes
- Ambiguous (no clear category): X notes
- Non-markdown files: X

### Findings
- [Observations for other skills — e.g., broken frontmatter, suspicious duplicates]

### Suggestions
- [Improvements for this skill — e.g., new subfolder needed, criteria unclear for X topic]
```

## Logging

After every run, append one row to `logs/run-history.md` and update `logs/changelog.md` if the skill itself changed.

## Quality Check

Before reporting done:
- [ ] Every moved file still exists at its new path
- [ ] No files were renamed or modified
- [ ] Cooldown was respected (no recently modified files moved)
- [ ] Empty file deletions were logged individually
- [ ] Report covers all processed and skipped notes
