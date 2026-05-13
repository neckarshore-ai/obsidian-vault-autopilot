# Metadata Requirements

Skills depend on YAML frontmatter — especially the `created` field. This document explains what the skills expect, what happens when metadata is missing, and how to fix it.

## Primary Requirement: YAML `created`

The most important field is `created:` in YAML frontmatter. Skills use it for **cooldown logic** — files newer than 3 days (configurable) are protected from automation. Without `created`, skills fall back to filesystem birthtime, which is unreliable on cloned vaults (see [Cloning Guide](cloning-guide.md)).

**Example of a note with correct metadata:**

```yaml
---
created: 2024-03-14
modified: 2026-04-10
tags:
  - Project/MyProject
---
```

## The `created` Source Hierarchy

When a skill needs to know when a note was created, it checks these sources in order:

| # | Source | When it's used | Reliability |
|---|--------|---------------|-------------|
| 1 | YAML `created` field | Always checked first | High — survives copy, clone, sync, edit |
| 2 | Filename date pattern (e.g. `2024-03-14 Meeting.md`) | When YAML `created` is missing | High — filename is stable |
| 3 | Git first-commit timestamp | When vault is under Git and `--prefer-git` is set | Medium — only works for Git-tracked vaults |
| 4 | Filesystem birthtime | Last resort fallback | Low — resets on Finder copy, `cp -R`, Windows Explorer copy, and Obsidian edits |

**Why this matters:** On a cloned vault, Source #4 (filesystem birthtime) is the moment you cloned, not when the note was originally created. If your vault has low YAML `created` coverage, the cooldown logic will treat every note as "new" and protect them all. Skills will run, appear to work, and do nothing. This is the [silent clone-killer](incident-birthday-bug.md).

## Accepted Date Formats for `created`

| # | Format | Example | Supported? |
|---|--------|---------|------------|
| 1 | ISO date only | `2024-03-14` | Yes |
| 2 | ISO datetime with `T` | `2024-03-14T10:30:00` | Yes |
| 3 | ISO datetime with `Z` | `2024-03-14T10:30:00Z` | Yes |
| 4 | ISO datetime with offset | `2024-03-14T10:30:00+01:00` | Yes |
| 5 | Obsidian default datetime | `2024-03-14 10:30` | Yes |
| 6 | Date with slash | `2024/03/14` | No — not parsed |
| 7 | US format | `03/14/2024` | No — not parsed |
| 8 | String with quotes | `"2024-03-14"` | Yes — quotes stripped |
| 9 | Empty field `created:` | `created:` | Treated as missing |

If the format is not supported, the skill treats `created` as missing and falls back to the next source in the hierarchy.

## Which Skill Fills Which Field

| # | Field | Filled by | When |
|---|-------|-----------|------|
| 1 | `created` | `property-enrich` (bulk), `note-rename` / `inbox-sort` (per-note, Nahbereich) | Initial backfill or auto-enriched during skill run |
| 2 | `modified` | (Obsidian handles this) | On every edit |
| 3 | `title` | `property-enrich` | When missing or mismatched with filename |
| 4 | `aliases` | `property-enrich` | When aliases can be derived from filename history |
| 5 | `description` | `property-describe` | When missing |
| 6 | `status`, `type` | `property-classify` | During lifecycle classification |
| 7 | `tags` | `tag-manage` (v0.2.0) | During tag standardization |

## Pre-Run Metadata Check

Before running any destructive skill, check your vault's YAML `created` coverage:

```bash
# Run from the vault root
TOTAL=$(find . -name "*.md" -not -path "./.obsidian/*" -not -path "./_trash/*" | wc -l)
WITH_CREATED=$(grep -rl "^created:" --include="*.md" . 2>/dev/null | grep -v ".obsidian" | grep -v "_trash" | wc -l)
echo "Total notes:       $TOTAL"
echo "With YAML created: $WITH_CREATED"
echo "Coverage:          $((WITH_CREATED * 100 / TOTAL))%"
```

- **95% or higher:** safe to run any skill.
- **80-95%:** run `property-enrich` first to fill missing `created` fields, then re-check.
- **Below 80%:** consider running `property-enrich` first for efficient bulk enrichment. Other skills auto-enrich `created` per-note, but a bulk pass is faster for large vaults. See [Getting Started](getting-started.md).

## Edge Cases Skills Tolerate

| # | Case | Behavior |
|---|------|----------|
| 1 | No frontmatter at all | Skill adds frontmatter with `created` from the source hierarchy |
| 2 | Empty `created:` | Treated as missing, fallback to next source |
| 3 | `created` is a string when Obsidian expects a date | Quotes stripped, parsed as date |
| 4 | BOM bytes at start of file | Stripped; skill proceeds |
| 5 | Double frontmatter delimiters | Treated as corrupted; skill logs a warning |
| 6 | `\r\n` line endings | Normalized to `\n` on write |
