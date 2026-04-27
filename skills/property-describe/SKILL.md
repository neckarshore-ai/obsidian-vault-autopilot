---
name: property-describe
status: beta
description: Use when Obsidian vault notes need AI-generated description properties in their YAML frontmatter. Trigger phrases - "add descriptions", "fill descriptions", "generate summaries", "description property", "empty description", "missing description". Also trigger when notes have placeholder descriptions (TBD, TODO) or when batch-filling descriptions across a folder. This is a token-intensive operation (reads full note content) — run it deliberately, not as part of every property pass.
---

# Property Describe

Generate a concise `description` property for vault notes by reading their content and distilling it to one sentence (max 250 characters). Like a meta description for a web page — scannable, specific, English.

## Principle: Core + Nahbereich + Report

- **Core:** Generate and write `description` values from note content
- **Nahbereich:** Write `description: TBD` for notes too thin to summarize (prevents re-scanning)
- **Report:** Descriptions written, skipped, too-thin notes flagged

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. User confirms before execution. |

## Protected Files

Never process or modify these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Token Cost Warning

This skill reads full note content and generates AI summaries. It is the most expensive property skill. Do not bundle it into routine property passes — trigger it deliberately when descriptions are the goal.

## Which Notes Get a Description

Process only if ALL true:
1. Has real content (2+ sentences beyond frontmatter/headings)
2. `description` is missing, empty, or placeholder (`TBD`, `TODO`, `...`, `PLACEHOLDER`, `FIXME`, any string < 10 chars)
3. Not protected (`status: permanent` or `status: evergreen`)

**Too-thin notes** (< 2 sentences): write `description: TBD` and move on. Skip if already `TBD`.

## How to Write a Good Description

- **Max 250 characters**, one sentence, always English
- Content-first: what the note contains, not what it is
- No fluff ("This note contains...", "Summary of...")
- Include specifics: names, dates, tools, numbers when they fit
- Proper nouns stay in original language ("Steuerbelege 2025")

## Pre-flight

Before **every** invocation of this skill — including resumed sessions and re-triggers within the same conversation: if running on Windows, follow [`references/windows-preflight.md`](../../references/windows-preflight.md). Run the registry check freshly each time. Do not assume a previous turn's pass result still holds — registry state can change between invocations and previous results are not authoritative. On macOS or Linux, skip — the preflight is a no-op there.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Ask for target scope.
2. **Filter** — identify notes needing descriptions (missing/placeholder/too-thin).
3. **Generate** — read content, produce 250-char summary per note. For long notes (5000+ words): read title, first 50 lines, headings, last 10 lines.
4. **Preview** — show table (filename, generated description, char count). Wait for confirmation. User can approve all, review individually, or reject specific entries.
5. **Write** — set `description` in YAML frontmatter. Line-by-line replacement only (never `str.replace`). Preserve all other fields. Single-quote the value, escape apostrophes by doubling (`'`→`''`).
6. **Skill Log** — for each described file: add `VaultAutopilot` tag and append skill log callout row (see `references/skill-log.md`).
7. **Report and log** — append to `logs/run-history.md`.

## Boundaries

- ONLY writes `description` — no other property modified
- Does not touch note body content
- Does not create, delete, move, or rename files

## Report Format

```
## Property Describe Report — [Date]

### Done
- Descriptions written: X | TBD written (too thin): X

### Skipped
- Already has description: X | Protected: X

### Findings
- [Observations for other skills]
```

## Quality Check

- [ ] No description exceeds 250 characters
- [ ] All descriptions are in English
- [ ] Preview was shown and confirmed before writing
- [ ] No properties other than `description` were modified
