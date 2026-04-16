# Vault Autopilot

This vault is managed by [Obsidian Vault Autopilot](https://github.com/neckarshore-ai/obsidian-vault-autopilot) — an AI-powered plugin that sorts, renames, tags, and enriches your notes automatically.

## Available Skills

| # | Skill | What it does | Last run |
|---|-------|-------------|----------|
| 1 | inbox-sort | Moves notes from inbox root into subfolders | — |
| 2 | note-rename | Renames poorly named files with clear, descriptive names | — |
| 3 | note-quality-check | Scores notes, flags stale content, suggests deletions | — |
| 4 | property-classify | Classifies note status and type via YAML frontmatter | — |
| 5 | property-describe | Generates missing note descriptions | — |
| 6 | property-enrich | Fills missing metadata fields (dates, tags, status) | — |
| 7 | tag-manage | Assigns, cleans up, and standardizes tags | — |

## How It Works

Each skill follows the **Core + Nahbereich + Report** principle:
- **Core:** Execute the job (sort, rename, tag, etc.)
- **Nahbereich:** Fix adjacent issues when evidence is clear
- **Report:** Document what was done, what was found, what needs attention

## Reports

Skill reports are saved to the `logs/` directory after each run.

## Configuration

Skills use sensible defaults but respect your vault structure. No hardcoded folder names — skills discover your vault layout at runtime.

---

> **Note:** This file is protected. No skill will move, rename, or modify it.
