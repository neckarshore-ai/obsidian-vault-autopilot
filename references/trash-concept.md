# Trash Concept — Shared Convention

## Purpose

This plugin never permanently deletes notes with content. All destructive actions use soft-delete: moving the file to a `_trash/` folder inside the vault. The user decides when to empty the trash.

This convention applies to all skills that remove files.

## Trash Folder

```
${OBSIDIAN_VAULT_PATH}/_trash/
```

The underscore prefix marks it as plugin-managed, consistent with `_vault-autopilot.md`. Skills must never process files inside `_trash/`.

## When to Trash vs. Permanently Delete

| Condition | Action |
|-----------|--------|
| File is 0 bytes (literally empty) | Permanent delete allowed |
| File has any content (even whitespace) | Soft-delete to `_trash/` |
| User explicitly says "delete" or "trash" | Soft-delete to `_trash/` |

The 0-byte rule exists because empty files are filesystem artifacts, not notes. Everything else gets the safety net.

## Trash Metadata

Before moving a file to `_trash/`, add or update these YAML frontmatter properties:

```yaml
trashed: 2026-04-05
trash_source: note-quality-check
trash_origin: "XX Invest some time in cleanup into OPS/Old Note.md"
```

| Property | Required | Description |
|----------|----------|-------------|
| `trashed` | Yes | Date of soft-delete (YYYY-MM-DD) |
| `trash_source` | Yes | Skill name that performed the trash action |
| `trash_origin` | Yes | Original path relative to vault root (for restore) |

## Name Collisions

If a file with the same name already exists in `_trash/`, append a timestamp suffix:

```
_trash/My Note.md          <- first
_trash/My Note_2026-04-05T1423.md  <- collision
```

## Restore

Restoring is manual. The user moves the file back from `_trash/` to any folder. The `trash_origin` property tells them where it came from. Skills do not auto-restore.

## Purging

No auto-purge. The user empties `_trash/` when they choose. A future `trash-manage` skill may offer guided purging, but that is not part of v0.1.0.

## Rules for Skills

1. Never process files inside `_trash/` (skip during scans)
2. Never recommend trashing a note the skill does not fully understand — ask the user
3. Always add trash metadata before moving
4. Log every trash action in the skill report
5. The `_trash/` folder is created on first use (not at plugin install)
