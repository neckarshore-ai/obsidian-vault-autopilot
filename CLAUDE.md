# CLAUDE.md — Obsidian Vault Autopilot

## What This Repo Is

`obsidian-vault-autopilot` is an open-source Claude Code plugin that automates Obsidian vault management. It sorts inboxes, renames notes, checks quality, standardizes properties, and manages tags — so humans can focus on thinking, not organizing.

**Organization:** Neckarshore AI
**License:** MIT
**Status:** Pre-launch (v0.1.1)

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
| 1 | inbox-sort | Move files from inbox to correct folders | beta |
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

**Dev/Test vault:** Set up a local test vault for live testing and integration tests.

## Design Philosophy

Read `docs/philosophy.md` for the full product philosophy. Key principles:

1. **Core + Nahbereich + Report** — every skill does its job, fixes adjacent issues, reports everything else
2. **Quality over tokens** — thorough over cheap
3. **No vendor lock-in** — works on Markdown + YAML, not Obsidian APIs
4. **Opinionated defaults, configurable everything**

## Production Vault Safety Rules

> **Incident-backed (2026-04-09).** These rules exist because an agent scanned a production vault without permission. They are non-negotiable.

1. **Gate, not step.** Every transition from test vault to production vault is a **gate** — it requires an explicit user confirmation, regardless of how safe the operation appears. "Continue with production?" is mandatory. Blanket approvals for work blocks do NOT extend to environment switches.
2. **No filesystem discovery.** Never run `find ~`, `ls ~/`, `mdfind`, or any command that scans outside the configured `OBSIDIAN_VAULT_PATH`. You operate on the vault the user pointed you to — nothing else. If you need to know where other vaults are, **ask the user**.
3. **Read-only is not harmless.** Production vault access requires explicit user approval even for read-only operations (scans, counts, audits). Reading production data without permission is a trust violation, not a technical issue.
4. **Confirm before bulk operations.** Before touching more than 10 files in any vault (test or production), state: "I will [action] [N] files in [vault-name]. Confirm?" Wait for approval.
5. **Scope of approval.** A user saying "yes" to a plan approves that plan's scope. It does not approve switching environments, accessing new vaults, or expanding the file set beyond what was described.

## What NOT to Do

- Do not hardcode project names or vault paths
- Do not use emoji in skill files
- Do not skip the quality checklist
- Do not create flat skill files — always use subdirectories (`skills/name/SKILL.md`)
- Do not duplicate Obsidian syntax reference (that's kepano/obsidian-skills)
- **Do not access any vault not explicitly provided by the user** (see Production Vault Safety Rules)

## Token Efficiency

- Do not re-read files already read in the current session
- Make multiple tool calls in parallel when independent
- Chain git commands: `git add ... && git commit ... && git push`
