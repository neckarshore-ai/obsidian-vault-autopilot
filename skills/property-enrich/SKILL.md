---
name: property-enrich
status: stable
description: Use when Obsidian vault notes have incomplete or missing YAML frontmatter and need structural metadata filled in. Best for bulk enrichment of an entire vault. Trigger phrases - "add properties", "enrich metadata", "fill frontmatter", "prepare my vault", "backfill created", "enrich before sort", "missing metadata", "incomplete frontmatter".
---

# Property Enrich

Fill missing structural metadata: `title`, `created`, `modified`. Additive only — never overwrites (except `modified`).

## When to Run This

**Recommended for bulk enrichment.** property-enrich fills `created`, `title`, and `modified` across your entire vault in one pass — efficient for initial setup or after a clone. Note-rename and inbox-sort auto-enrich `created` per-note during their runs (Nahbereich), so property-enrich is no longer a strict prerequisite. It remains the best choice for bulk metadata coverage and for filling `title` and `modified`, which other skills do not auto-enrich.

## Principle: Core + Nahbereich + Report

- **Core:** Fill missing metadata from content, path, filesystem
- **Nahbereich:** Create frontmatter if none exists
- **Report:** Fields added per type, source per note

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. User confirms before execution. |

## Protected Files

Never process or modify these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Properties (v0.1.0)

| Property | Source | Overwrite? |
|----------|--------|-----------|
| `title` | First H1 heading, fallback: filename without `.md` | Never |
| `created` | Source Hierarchy (see below) | Never |
| `modified` | Filesystem mtime | **Always** (refreshed on every write) |

### `created` Source Hierarchy

When `created` is missing from YAML, derive it from the highest-priority available source:

| Prio | Source | How | When reliable |
|------|--------|-----|---------------|
| 1 | YAML `created` exists | Skip (additive-only, unchanged) | Always |
| 2 | Filename date pattern | Parse `YYYY-MM-DD` from filename, e.g. `2024-03-14 Meeting Notes.md` | When user names files with dates |
| 3 | Git first-commit timestamp | `git log --follow --diff-filter=A --format=%aI -- <file>` | When vault is under Git |
| 4 | Filesystem birthtime (last resort) | `stat -f %SB` (macOS) / `stat -c %W` (Linux) | Only on native (non-cloned) vaults |

**Rules:**
- Try 1 through 4 in order, use the first valid date
- Log which source was used per note in the Report (Source column)
- If no source yields a valid date, skip the note and report it as a Finding

### Clone Detection Warning

When Source 4 (filesystem birthtime) is used AND all birthtimes in the batch cluster within a 1-hour window: log a warning in the Report.

> **Warning:** All created dates derived from filesystem birthtime within a narrow window. This vault may be a clone. Consider verifying dates manually.

The warning does NOT block execution — it informs only.

### Relational Properties (v0.2.0)

> **Deferred to v0.2.0.** Properties like `aliases`, `parent`, `source`, and `priority` are not filled in the current release. The full design is preserved in `SKILL.v0.2.0-draft.md` in this directory.

## Pre-flight

Before **every** invocation of this skill — including resumed sessions and re-triggers within the same conversation: if running on Windows, follow [`references/windows-preflight.md`](../../references/windows-preflight.md). Run the registry check freshly each time. Do not assume a previous turn's pass result still holds — registry state can change between invocations and previous results are not authoritative. On macOS or Linux, skip — the preflight is a no-op there.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Ask for scope. Confirm if 50+ notes.
2. **Scan** — read frontmatter, path, filesystem timestamps per note.
3. **Compute** — for each note missing `created`: walk the Source Hierarchy (Prio 1 through 4). Compute `title` from H1 or filename. Read `modified` from filesystem.
4. **Preview** — summary table with sample changes including Source column. Wait for confirmation.
5. **Write** — add fields in YAML frontmatter. Preserve all existing values.
6. **Skill Log** — for each enriched file: add `VaultAutopilot` tag and append skill log callout row (see `references/skill-log.md`). Action format: `Added [field list] (created source: [source])`.
7. **Report and log** — append to `logs/run-history.md`.

## Boundaries

- Additive only (except `modified`)
- Does not write `description` (property-describe), `status` or `type` (property-classify)
- Does not modify note body, delete, move, or rename files
- Does not fill `aliases`, `parent`, `source`, `priority` in v0.1.0

## Report Format

```
## Property Enrich Report — [Date]

### Done

| # | Note | title | created | Source | modified | Findings |
|---|------|-------|---------|--------|----------|----------|
| 1 | Budget Review.md | Budget Review | 2024-06-15 | filename | 2026-04-13 | — |
| 2 | Architecture.md | Architecture | 2025-11-20 | git | 2026-04-13 | — |

- Notes enriched: X | Already complete: X | Skipped (no valid date): X

### Clone Detection

[If triggered:] Warning — all birthtime-derived dates cluster within 1 hour. This vault may be a clone.
[If not triggered:] No clone indicators detected.

### Findings

- [Observations for other skills]
```

## Quality Check

- [ ] No existing property values were overwritten (except `modified`)
- [ ] `created` Source Hierarchy was followed (filename > git > birthtime)
- [ ] Source column in report shows derivation per note
- [ ] Preview shown and confirmed before writing
- [ ] No `aliases`, `parent`, `source`, or `priority` fields were written
