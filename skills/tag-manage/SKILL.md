---
name: tag-manage
status: deferred
description: Use when an Obsidian vault needs tag auditing, cleanup, or content-based tag suggestions. Trigger phrases - "analyze tags", "audit tags", "fix tags", "suggest tags", "tag cleanup", "find duplicate tags", "unused tags", "tag consistency", "auto-tag notes". Also trigger when the user mentions orphan tags, tag hierarchy issues, convention violations, or untagged notes needing tags.
---

# Tag Manage

Audit vault tags for issues and suggest new tags from content. Two modes: **audit** (find problems) and **suggest** (fill gaps). Authority: `references/tag-convention.md`.

## Principle: Core + Nahbereich + Report

- **Core:** Detect tag issues + suggest tags for untagged notes
- **Nahbereich:** Auto-fix obvious convention violations (lowercase → PascalCase)
- **Report:** Tag health, changes, suggestions for manual review

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. `inbox` = inbox only. `vault` = entire vault. User confirms before execution. |
| `mode` | full | `audit` (find problems), `suggest` (fill gaps), or `full` (both). |

## Protected Files

Never process or modify these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Modes

| Trigger | Mode |
|---------|------|
| "audit tags", "tag report", "check consistency" | `audit` |
| "suggest tags", "auto-tag", "untagged notes" | `suggest` |
| "fix tags", "tag cleanup" | `full` (both) — default |

## Audit Checks

| # | Check | Finds |
|---|-------|-------|
| 1 | Duplicates | Case variants, singular/plural, abbreviation vs. full |
| 2 | Convention violations | Non-PascalCase, `#`-prefixed, lowercase concepts |
| 3 | Hierarchy conflicts | Same leaf under different parents |
| 4 | Orphans | Single-use tags, parent with single child |
| 5 | Numeric artifacts | Numbers parsed as tags from Markdown tables |

Each issue: affected notes, recommended canonical form, severity (high/medium/low).

## Suggest Logic

For untagged notes — read title, frontmatter, first ~800 chars:

1. Match against existing vault tag vocabulary (prefer known tags)
2. Extract topics, entities, content type, domain
3. Score: High (known, freq 5+), Medium (known or clear topic), Low (inferred)
4. Max 5 per note, PascalCase per convention

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Confirm scope.
2. **Build vocabulary** — all tags with frequencies across vault.
3. **Audit** — run checks, compile issues with severity.
4. **Suggest** — find untagged notes, generate proposals.
5. **Preview and confirm** — tables for issues + suggestions. Options: approve all, by confidence, individually.
6. **Execute** — fix violations, merge duplicates, write tags. YAML frontmatter only.
7. **Report and log** — append to `logs/run-history.md`.

## Boundaries

- YAML frontmatter tags only (no inline `#hashtags`)
- No deleting notes, no modifying content, no non-tag properties
- Merges require confirmation
- `references/tag-convention.md` is the authority

## Report Format

```
## Tag Manage Report — [Date]

### Audit
- Duplicates: X groups | Violations: X | Conflicts: X | Orphans: X

### Suggest
- Untagged: X | Suggested: X | Written: X

### Nahbereich
- Auto-fixes: X

### Findings
- [Observations, convention update suggestions]
```

## Quality Check

- [ ] All tags follow `references/tag-convention.md`
- [ ] Duplicate merges updated all affected notes
- [ ] Preview confirmed before writing
