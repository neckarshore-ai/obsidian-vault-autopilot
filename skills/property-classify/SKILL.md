---
name: property-classify
status: beta
description: Use when Obsidian vault notes need their `status` and `type` frontmatter properties set or audited. Trigger phrases - "set note types", "check status", "classify notes", "status audit", "type audit", "lifecycle check", "draft notes", "assign types". Also trigger when notes have `type: TBD` or no status field, or when the user wants to know which notes need attention based on completeness.
---

# Property Classify

Assign `status` (lifecycle) and `type` (category) in one pass. Rule-based, no AI, cheap to run.

## Principle: Core + Nahbereich + Report

- **Core:** Set `status` and `type` from content, metadata, and path
- **Nahbereich:** Normalize casing (`Status` → `status`)
- **Report:** Classifications, conflicts, distribution

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. `inbox` = inbox only. `vault` = entire vault. User confirms before execution. |

## Protected Files

Never process or modify these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Status Values (priority order, highest wins)

| Status | Rule |
|--------|------|
| `permanent` / `evergreen` | **Protected** — never changed, skip entirely |
| `archived` | Path contains `/archive/` (case-insensitive) |
| `reviewed` | All checkboxes `[x]`, at least one exists |
| `polished` | Has real `description` (not TBD) + 3+ `aliases` + no placeholder fields |
| `draft` | Default — anything not matching above |

## Type Classification (two layers)

**Layer 1 — Content signals (checked first, more specific):**

| Signal | Type |
|--------|------|
| `ISBN` or `Author:` in frontmatter/body | `book` |
| `Agenda:` heading or field | `meeting` |

**Layer 2 — Path fallback (if no content signal):**

| Path contains | Type |
|---------------|------|
| `inbox` | `inbox` |
| `project` | `project` |
| `people` or `contact` | `person` |
| `meeting` | `meeting` |
| `resource` | `resource` |
| `archive` | `archive` |
| `template` | `template` |

**No match:** `type: TBD`. Content signals override path signals.

## Conflict Handling

Existing `type` (not `TBD`/`inbox`) + different proposed value = **conflict**, do not overwrite. Notes with `TBD`, `inbox`, or no `type` can always be set.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Ask for scope. Confirm if 50+ notes.
2. **Scan** — read frontmatter, path, checkboxes, and first ~500 chars per note.
3. **Classify** — apply status hierarchy + type layers. Detect conflicts.
4. **Preview** — group by action (no change, upgrades, downgrades, conflicts). Wait for confirmation.
5. **Write** — set `status` and `type` in frontmatter. Preserve all other fields.
6. **Provenance** — for each classified file: add `VaultAutopilot` tag and append provenance callout row (see `references/provenance.md`).
7. **Report and log** — append to `logs/run-history.md`.

## Report Format

```
## Property Classify Report — [Date]

### Done
- Classified: X notes | Status set: X | Type set: X
- Conflicts flagged: X (not overwritten)

### Distribution
- Status: draft X | polished X | reviewed X | archived X | protected X
- Type: inbox X | project X | meeting X | book X | TBD X

### Findings
- [Status downgrades, type conflicts, observations for other skills]
```

## Quality Check

- [ ] Protected notes (`permanent`/`evergreen`) were not modified
- [ ] Conflicts were flagged, not overwritten
- [ ] Preview shown and confirmed before writing
