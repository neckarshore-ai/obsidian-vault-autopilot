# CLAUDE.md — Obsidian Vault Autopilot

## What This Repo Is

`mmp-obsidian-vault-autopilot` is an open-source Claude Code plugin that automates Obsidian vault management. It sorts inboxes, renames notes, checks quality, standardizes properties, and manages tags — so humans can focus on thinking, not organizing.

**Organization:** Neckarshore AI
**License:** MIT
**Status:** Pre-launch (v0.1.0)

## Plugin Structure

```
.claude-plugin/
  plugin.json              <- Manifest
skills/
  skill-name/
    SKILL.md               <- Main skill file
references/                <- Shared reference docs
docs/
  philosophy.md            <- Product philosophy + design rules
logs/
  changelog.md             <- Release notes
  run-history.md           <- Skill execution log
```

## Skills (6 stable/beta + 1 deferred)

| # | Skill | Core Task | Status |
|---|-------|-----------|--------|
| 1 | inbox-sort | Move files from inbox to correct folders | stable |
| 2 | note-rename | Rename poorly named files | stable |
| 3 | note-quality-check | Score notes, suggest deletions | beta |
| 4 | property-classify | Classify note status and type | beta |
| 5 | property-describe | Generate note descriptions | beta |
| 6 | property-enrich | Fill missing metadata fields | stable |
| 7 | tag-manage | Assign, clean up, and standardize tags | deferred (v0.2.0) |

## Quality Checklist per Skill

Before committing any skill, verify:

1. SKILL.md has valid YAML frontmatter (`name`, `description`)
2. Description starts with "Use when..." and includes 3+ trigger phrases
3. No hardcoded paths (use `${OBSIDIAN_VAULT_PATH}`)
4. Output format is specified (Core + Nahbereich + Report)
5. Quality checks are included in the skill
6. Skill is concise and focused (under 500 words for most skills)
7. All content is in English
8. No emoji in skill files

## SKILL.md Frontmatter

```yaml
---
name: skill-name-with-hyphens
description: Use when [specific triggering conditions]. Trigger phrases - "phrase 1", "phrase 2", "phrase 3".
---
```

## Naming Conventions

- **Skill names:** `[domain]-[action]` — noun first, then verb (kebab-case)
- **Directories and files:** kebab-case always
- **All content:** English

## Vault Path

```bash
export OBSIDIAN_VAULT_PATH="/path/to/your/vault"
```

No hardcoded paths in skills. No assumptions about vault location.

**Dev/Test vault (Nexus):** `~/vaults/nexus` — used for all live testing and integration tests.

## Design Philosophy

Read `docs/philosophy.md` for the full product philosophy. Key principles:

1. **Core + Nahbereich + Report** — every skill does its job, fixes adjacent issues, reports everything else
2. **Quality over tokens** — thorough over cheap
3. **No vendor lock-in** — works on Markdown + YAML, not Obsidian APIs
4. **Opinionated defaults, configurable everything**

## What NOT to Do

- Do not hardcode project names or vault paths
- Do not use emoji in skill files
- Do not skip the quality checklist
- Do not create flat skill files — always use subdirectories (`skills/name/SKILL.md`)
- Do not duplicate Obsidian syntax reference (that's kepano/obsidian-skills)

## Token Efficiency

- Do not re-read files already read in the current session
- Make multiple tool calls in parallel when independent
- Chain git commands: `git add ... && git commit ... && git push`
