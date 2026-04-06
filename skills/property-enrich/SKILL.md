---
name: property-enrich
status: stable
description: Use when Obsidian vault notes have incomplete or missing YAML frontmatter and need structural metadata filled in. Trigger phrases - "add properties", "enrich metadata", "fill frontmatter", "add aliases", "set parent links", "missing metadata", "incomplete frontmatter", "standardize properties". Also trigger when notes lack title, created/modified dates, aliases, parent links, source URLs, or priority fields.
---

# Property Enrich

Fill missing structural metadata: `title`, `created`, `modified`, `aliases`, `parent`, `source`, `priority`. Additive only — never overwrites (except `modified`).

## Principle: Core + Nahbereich + Report

- **Core:** Fill missing metadata from content, path, filesystem
- **Nahbereich:** Create frontmatter if none exists
- **Report:** Fields added per type, enriched vs. complete

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. User confirms before execution. |

## Protected Files

Never process or modify these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Properties and Rules

### Scaffold (always ensured)

| Property | Source | Overwrite? |
|----------|--------|-----------|
| `title` | First H1 heading, fallback: filename without `.md` | Never |
| `created` | Frontmatter `created`/`date`, fallback: filesystem birth time | Never |
| `modified` | Filesystem mtime | **Always** (refreshed on every write) |

### Relational (only if missing)

| Property | Source | Format |
|----------|--------|--------|
| `aliases` | Bold terms + wiki links from first 2 paragraphs, shortened title for names > 50 chars | YAML list, append to existing |
| `parent` | Parent folder's index file (search: `Folder MOC.md`, `Folder.md`, `_index.md`) | `"[[Folder MOC]]"` (wiki link) |
| `source` | First URL in note body, or first referenced PDF | Quoted string |
| `priority` | Default `3`, override to `1` if path contains "Active" or note has `#urgent` tag | Integer |

**Aliases are cumulative:** Even when `aliases` exists, scan for new candidates and **append**. Never remove or reorder existing entries.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Ask for scope. Confirm if 50+ notes.
2. **Scan** — read frontmatter, path, filesystem timestamps, first 2 paragraphs per note.
3. **Compute** — determine which fields are missing, compute values. Skip properties that already have valid content.
4. **Preview** — summary + 3-5 sample changes. Wait for confirmation.
5. **Write** — add fields in YAML frontmatter. Preserve all existing values.
6. **Report and log** — append to `logs/run-history.md`.

## Boundaries

- Additive only (except `modified`)
- Does not write `description` (property-describe), `status` or `type` (property-classify)
- Does not modify note body, delete, move, or rename files
- Bulk import detection: many files with identical `created` → flag in report, don't modify

## Report Format

```
## Property Enrich Report — [Date]

### Done
- Notes enriched: X | Already complete: X
- title added: X | created added: X | aliases appended: X
- parent added: X | source added: X | priority added: X

### Findings
- Bulk import suspected: X notes (identical created timestamp)
- [Observations for other skills]
```

## Quality Check

- [ ] No existing property values were overwritten (except `modified`)
- [ ] `parent` values use `[[wiki link]]` format
- [ ] `priority` values are integers (1-5)
- [ ] Preview shown and confirmed before writing
