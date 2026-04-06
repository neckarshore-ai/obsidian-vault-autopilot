# Provenance Tracking

Every skill that modifies a note must leave a trace: a tag in frontmatter and a row in the provenance callout.

## Tag

Add `VaultAutopilot` to the `tags` list in YAML frontmatter if not already present. This marks the note as "touched by automation" and makes it searchable.

```yaml
tags:
  - ExistingTag
  - VaultAutopilot
```

## Provenance Callout

Append an Obsidian callout block at the **end** of the note. If the callout already exists, append a new row to the table. Never duplicate existing rows.

### Format

```markdown
> [!info] Vault Autopilot
>
> | Date | Skill | Action |
> |------|-------|--------|
> | 2026-04-06 | inbox-sort | Moved from Inbox root to _Work |
```

### Rules

1. **Position:** Always the last block in the note. No content after it.
2. **Date:** `YYYY-MM-DD` format, use current date.
3. **Skill:** Skill name as listed in plugin.json (e.g., `inbox-sort`, `note-rename`, `property-enrich`).
4. **Action:** One-line summary of what happened. Be specific:
   - inbox-sort: `Moved from [source] to [target bucket]`
   - note-rename: `Renamed from [old name]`
   - note-quality-check: `[Action] — [reason]` (e.g., `Archived to 099_Archive/`)
   - property-classify: `Set status: [value], type: [value]`
   - property-describe: `Generated description ([char count] chars)`
   - property-enrich: `Added [field list]`
5. **Existing callout:** Detect by looking for `> [!info] Vault Autopilot` at the end of the file. If found, append a new `> | date | skill | action |` row. If not found, create the full block.
6. **Separator:** Add one blank line before the callout if there is none.

## Detection

To check if a note has been processed by any skill:

- **Tag search:** Filter by `VaultAutopilot` tag in Obsidian
- **Callout search:** Search for `[!info] Vault Autopilot` across vault
- **Specific skill:** Search callout table for skill name

## Why Both Tag and Callout

- **Tag:** Fast filtering in Obsidian (sidebar, Dataview, search). Answers: "has automation touched this?"
- **Callout:** Full history. Answers: "what happened, when, by which skill?"
