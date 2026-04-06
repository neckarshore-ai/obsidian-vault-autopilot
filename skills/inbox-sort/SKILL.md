---
name: inbox-sort
status: stable
description: Use when an Obsidian vault inbox is cluttered and notes need sorting into subfolders. Trigger phrases - "sort inbox", "clean up inbox", "triage inbox", "organize inbox", "inbox is cluttered", "too many notes in inbox". Also trigger when the user mentions reducing inbox size or doing a first pass on unprocessed notes.
---

# Inbox Sort

Move notes from inbox root into three buckets: `_Work`, `_Personal`, `_Edge Cases`. Fast, reliable, no over-analysis.

## Principle: Core + Nahbereich + Report

- **Core:** Categorize and move notes into three buckets
- **Nahbereich:** Delete confirmed empty files (0 bytes). Whitespace-only files: soft-delete to `_trash/` (see `references/trash-concept.md`)
- **Report:** Summary of moves, findings, improvement suggestions

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. Use file creation date (birthtime), not modification date. |

## Three Buckets

Every note goes into exactly one bucket inside the inbox folder:

| Bucket | Prefix | What goes here |
|--------|--------|---------------|
| `_Work` | `_` | Business, products, dev, tools, clients, content creation |
| `_Personal` | `_` | Health, family, household, personal finance, career history |
| `_Edge Cases` | `_` | Genuinely ambiguous — could be Work or Personal, needs human decision |

The `_` prefix keeps sort buckets visually grouped and distinguishes them from content subfolders. When in doubt between Work and Personal, use `_Edge Cases` — never guess.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask the user.
2. **Find inbox** — scan top-level folders for one containing "inbox" (case-insensitive). If ambiguous, ask.
3. **Ensure buckets exist** — create `_Work`, `_Personal`, and `_Edge Cases` inside the inbox if they do not exist.
4. **List inbox root notes** — only `.md` files directly in the inbox root, not in subfolders.
5. **Apply cooldown** — skip notes created less than `cooldown_days` ago (grace period for active work). Use file creation date, not modification date.
6. **Nahbereich pass** — permanently delete files that are 0 bytes. Soft-delete whitespace-only files to `_trash/` with trash metadata (see `references/trash-concept.md`). Log each action.
7. **Pre-sort routing** — before categorizing, auto-route by pattern:
   - `YYYY-MM-DD.md` or `YYYY-MM-DD *.md` → subfolder containing "daily" (case-insensitive), not into buckets
   - Web captures and social posts (see `references/web-capture-detection.md`) → `_Work`
8. **Categorize remaining notes** — read title, tags, and first ~30 lines. Assign to one bucket:
   - Business/product/dev/tool content → `_Work`
   - Personal/family/health/household content → `_Personal`
   - Genuinely ambiguous → `_Edge Cases`
9. **Preview** — show routing plan grouped by bucket with note counts. Wait for user confirmation. User can override individual assignments.
10. **Move files** — use Bash `mv` with proper quoting for special characters. Preserve original filenames.
11. **Write report** — see format below.

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
- _Work: X notes moved
- _Personal: X notes moved
- _Edge Cases: X notes moved
- Nahbereich: X files removed (0-byte deleted: X, whitespace-only trashed: X)

### Skipped
- Cooldown (< [cooldown_days] days): X notes
- Non-markdown files: X

### Findings
- [Observations for other skills — e.g., broken frontmatter, suspicious duplicates]

### Suggestions
- [Improvements for this skill — e.g., criteria unclear for X topic]
```

## Logging

After every run, append one row to `logs/run-history.md` and update `logs/changelog.md` if the skill itself changed.

## Quality Check

Before reporting done:
- [ ] Every moved file still exists at its new path
- [ ] No files were renamed or modified
- [ ] Cooldown was respected (no recently modified files moved)
- [ ] Nahbereich actions were logged individually (0-byte deletes and whitespace-only trashes)
- [ ] Report covers all processed and skipped notes
