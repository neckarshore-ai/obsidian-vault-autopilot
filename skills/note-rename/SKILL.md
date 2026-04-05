---
name: note-rename
description: Use when Obsidian vault notes have poor, generic, or uninformative filenames and need clear, descriptive names. Trigger phrases - "rename notes", "fix note names", "clean up filenames", "give notes better names". Also trigger for single notes - "rename this note", "give this a better name". Trigger when the user mentions "Untitled notes", "unnamed notes", or notes that are hard to find by name.
---

# Note Rename

Give poorly named vault notes clear, descriptive filenames. Rename and fix backlinks. No sorting, no restructuring.

## Principle: Core + Nahbereich + Report

- **Core:** Rename uninformative filenames, update backlinks across vault
- **Nahbereich:** Trash accidental notes via soft-delete (see rule below and `references/trash-concept.md`)
- **Report:** Renames, backlink updates, findings for other skills

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. Use file creation date (birthtime), not modification date. |
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only. `vault` = entire vault. User confirms before execution. |

## Protected Files

Never rename or process these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Rename Candidates

Rename notes with **uninformative** filenames: `Untitled`, `Unbenannt`, `New Note`, `Draft`, `Blank note`, `Note from iPhone`, `Quick Note`, URL-only names, hash-only names, obvious typos (95%+ clear intent).

**Never rename:** Daily Notes (`YYYY-MM-DD.md`) or already descriptive names.

**Web captures:** Apply prefix per `references/web-capture-detection.md`. Skip existing categorical prefixes.

**Unclear cases:** `TBD - [Original Name]`. Report for manual review.

## Accidental Note Detection (Nahbereich)

Soft-delete to `_trash/` if ALL true: (1) generic filename, (2) no content beyond template boilerplate, (3) frontmatter has only generic tags and no real title. Add trash metadata per `references/trash-concept.md`. When in doubt → TBD prefix instead.

## Naming Rules

1. Capture **core topic** — scannable at a glance
2. **Dash separator:** `Topic - Detail` for two-level names
3. No filler words ("Note about", "Draft of")
4. Match content language
5. Max ~70 characters

**Clusters:** If 3+ notes share a topic, suggest a common prefix before renaming.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Default scope: inbox root. Confirm with user.
2. **Scan** — list `.md` files. Skip Daily Notes.
3. **Nahbereich** — detect and trash accidental notes (soft-delete to `_trash/`). Log each.
4. **Classify** — read title, tags, first ~30 lines (skip template boilerplate). Mark as: rename, keep, or TBD.
5. **Detect clusters** — 3+ candidates on same topic → prepare prefix suggestion.
6. **Check backlinks** — find all `[[Old Name]]` references across vault.
7. **Preview and confirm** — show table (old name, new name, backlink count). **Wait for user confirmation.**
8. **Execute** — rename files, update all `[[Old Name]]` and `[[Old Name|` references.
9. **Report and log** — write summary, append to `logs/run-history.md`.

## Report Format

```
## Note Rename Report — [Date]

### Done
- Renamed: X notes | Backlinks updated: X refs in Y notes
- Accidental notes trashed: X (Nahbereich, soft-delete to `_trash/`)

### Skipped
- Already descriptive: X | Daily Notes: X | TBD: X

### Findings
- [Observations for other skills]
```

## Quality Check

- [ ] Renamed files exist at new paths
- [ ] All backlinks updated (no broken `[[]]`)
- [ ] No Daily Notes renamed
- [ ] User confirmed before execution
