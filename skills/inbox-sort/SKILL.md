---
name: inbox-sort
status: stable
description: Use when an Obsidian vault inbox is cluttered and notes need sorting into subfolders. Trigger phrases - "sort inbox", "clean up inbox", "triage inbox", "organize inbox", "inbox is cluttered", "too many notes in inbox". Also trigger when the user mentions reducing inbox size or doing a first pass on unprocessed notes.
---

# Inbox Sort

Move notes from inbox root into four buckets: `_Work`, `_Personal`, `_Edge Cases`, `WebCaptures & Social`. Fast, reliable, no over-analysis.

## Principle: Core + Nahbereich + Report

- **Core:** Categorize and move notes into four buckets
- **Nahbereich:** Delete confirmed empty files (0 bytes). Whitespace-only files: soft-delete to `_trash/` (see `references/trash-concept.md`). Flag notes with sensitive content (see Secret Scan below). Fill missing YAML `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown. See `docs/metadata-requirements.md`.
- **Report:** Summary of moves, findings (including sensitive data warnings), improvement suggestions

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |

## Five Buckets

Every note goes into exactly one bucket inside the inbox folder. Non-markdown files go to `_Attachments/`.

| Bucket | What goes here |
|--------|---------------|
| `_Work` | Business, products, dev, tools, clients, content creation |
| `_Personal` | Health, family, household, personal finance, career history |
| `_Edge Cases` | Genuinely ambiguous — could be Work or Personal, needs human decision |
| `WebCaptures & Social` | Web clippings, social media saves, external captures |
| `_Attachments` | Images, PDFs, and other non-markdown files |

The `_` prefix on Work, Personal, Edge Cases, and Attachments keeps sort buckets visually grouped. When in doubt between Work and Personal, use `_Edge Cases` — never guess.

## Pre-flight

Before **every** invocation of this skill — including resumed sessions and re-triggers within the same conversation: if running on Windows, follow [`references/windows-preflight.md`](../../references/windows-preflight.md). Run the registry check freshly each time. Do not assume a previous turn's pass result still holds — registry state can change between invocations and previous results are not authoritative. On macOS or Linux, skip — the preflight is a no-op there.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask the user.
2. **Find inbox** — scan top-level folders for one containing "inbox" (case-insensitive). If ambiguous, ask.
3. **Ensure buckets exist** — create `_Work`, `_Personal`, `_Edge Cases`, `WebCaptures & Social`, and `_Attachments` inside the inbox if they do not exist.
4. **List inbox root files** — all files directly in the inbox root, not in subfolders. Separate into markdown (`.md`) and non-markdown files.
5. **Apply cooldown** — skip notes created less than `cooldown_days` ago (grace period for active work). The date source is YAML `created`, but corruption-tolerant in this exact order:
   - **5a. Repair corrupted date-key variants first.** If the YAML contains `"created:"` or `"modified:"` (quoted with embedded colon — typical Apple Notes / Drafts import artifact), normalize to `created` / `modified` and persist immediately (Nahbereich). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 5c silently skips legitimate candidates. Mirrors note-rename Step 4a — historical bug: repo issues #4 and #6 (2026-04-27).
   - **5b. After 5a, if YAML `created` is still missing:** auto-enrich by deriving from the Source Hierarchy (see `docs/metadata-requirements.md`): filename date > Git first-commit > filesystem birthtime. Write the derived value into YAML (Nahbereich).
   - **5c. Apply cooldown** using the now-trustworthy `created` value. If all sources failed in 5b, read filesystem birthtime via `stat -f %B` for cooldown only. Cooldown-skipped notes are reported in the Skipped section of the preview/report (not silently dropped). Why YAML over filesystem: Claude Code's Edit/Write tools create a new inode on APFS, resetting filesystem birthtime to "now". YAML `created` survives writes and is the only reliable source.
6. **Nahbereich pass** — permanently delete files that are 0 bytes. Soft-delete whitespace-only files to `_trash/` with trash metadata (see `references/trash-concept.md`). Log each action.
7. **Secret scan** — check each remaining note for sensitive patterns: recovery phrases (12/24 word sequences), IBAN/BIC, API keys, passwords/tokens. If detected: do NOT move to `_secret` automatically. Continue with normal categorization but flag the note in the report under Findings with the specific pattern type. The user decides what to do.
8. **Pre-sort routing** — before categorizing, auto-route by pattern:
   - Non-markdown files → `_Attachments/` (images, PDFs, etc.)
   - `YYYY-MM-DD.md` or `YYYY-MM-DD *.md` → subfolder containing "daily" (case-insensitive), not into buckets
   - Web captures and social posts (see `references/web-capture-detection.md`) → `WebCaptures & Social`
9. **Categorize remaining notes** — read title, tags, and first ~30 lines. Assign to one bucket:
   - Business/product/dev/tool content → `_Work`
   - Personal/family/health/household content → `_Personal`
   - Genuinely ambiguous → `_Edge Cases`
10. **Preview** — show routing plan grouped by bucket (see `references/report-format-inbox-sort.md`). Include secret-flagged notes with a warning marker. Wait for user confirmation. User can override individual assignments.
11. **Move files** — use Bash `mv` with proper quoting for special characters. Preserve original filenames.
12. **Skill Log** — for each moved file: add `VaultAutopilot` tag and append skill log callout row (see `references/skill-log.md`).
13. **Birthtime preservation** — after writing tag/callout, restore filesystem birthtime from the YAML `created` value saved in step 5. Use `touch -t` (see `references/skill-log.md` § Birthtime Preservation). After auto-enrich in step 5, YAML `created` is almost always available. Restore from it. If auto-enrich found no source, restore from the pre-write birthtime captured in step 5.
14. **Write report** — see format below.

## Protected Files

Never move, rename, or process these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Boundaries

- No renaming files
- No deep analysis, no creating subfolders, no editing content
- No processing files already in subfolders

## Report Format

See `references/report-format-inbox-sort.md` for the full preview table format, report template, and findings catalog.

## Logging

After every run, append one row to `logs/run-history.md` and update `logs/changelog.md` if the skill itself changed.

## Quality Check

Before reporting done:
- [ ] Every moved file still exists at its new path
- [ ] No files were renamed or modified
- [ ] Cooldown was respected (no recently modified files moved)
- [ ] Nahbereich actions were logged individually (0-byte deletes and whitespace-only trashes)
- [ ] Non-markdown files moved to `_Attachments/`
- [ ] Report covers all processed and skipped notes
