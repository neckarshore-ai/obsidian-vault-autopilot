# Skill Log

Every skill that modifies a note must leave a trace: a tag in frontmatter and a row in the skill log callout.

## Tag

Add `VaultAutopilot` to the `tags` list in YAML frontmatter if not already present. This marks the note as "touched by automation" and makes it searchable.

```yaml
tags:
  - ExistingTag
  - VaultAutopilot
```

### Tag Format Rules

YAML allows two formats for lists. Both are valid, but skills must handle both and always write block format:

```yaml
# Inline format (from imports, e.g. Apple Notes) — read this
tags: [AppleNoteImport, Obsidian]

# Block format (Obsidian standard) — always write this
tags:
  - AppleNoteImport
  - Obsidian
```

- **Read:** Accept both inline `[X, Y]` and block `- X` formats.
- **Write:** Always write block format. If a note has inline tags, convert to block when adding `VaultAutopilot`.
- **Never crash** on unexpected tag formats. If the format is unrecognizable, report it as a finding instead of failing.

## Skill Log Callout

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
   - note-rename: `Renamed from [old name]` or `Reviewed — name already descriptive`
   - note-quality-check: `[Action] — [reason]` (e.g., `Archived to 099_Archive/`)
   - property-classify: `Set status: [value], type: [value]`
   - property-describe: `Generated description ([char count] chars)`
   - property-enrich: `Added [field list]`
5. **Existing callout:** Detect by looking for `> [!info] Vault Autopilot` at the end of the file. If found, append a new `> | date | skill | action |` row. If not found, create the full block.
6. **Separator:** Add one blank line before the callout if there is none.

### Idempotency Rules

Every skill must follow these rules to prevent duplicates and ensure safe re-runs:

1. **Tag:** Check if `VaultAutopilot` exists in `tags` before adding. Never duplicate. If no `tags` field exists, create one.
2. **Callout:** Check if `> [!info] Vault Autopilot` exists at end of file before creating. If it exists, append a row — never create a second callout block.
3. **Rows:** Do not duplicate identical rows (same date + same skill + same action). A re-run on the same day with the same outcome should not add a second identical row.
4. **Re-processing:** If a skill runs again and performs a different action (e.g., re-rename), add a new row. The callout is a history — multiple entries from the same skill are valid when the actions differ.

## Detection

To check if a note has been processed by any skill:

- **Tag search:** Filter by `VaultAutopilot` tag in Obsidian
- **Callout search:** Search for `[!info] Vault Autopilot` across vault
- **Specific skill:** Search callout table for skill name

## Why Both Tag and Callout

- **Tag:** Fast filtering in Obsidian (sidebar, Dataview, search). Answers: "has automation touched this?"
- **Callout:** Full history. Answers: "what happened, when, by which skill?"
