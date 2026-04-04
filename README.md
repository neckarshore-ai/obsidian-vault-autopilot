# Obsidian Vault Autopilot

AI-powered vault management for Claude Code. Sorts your inbox, renames your files,
enriches your metadata — so you can focus on thinking instead of filing.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What This Does

Seven skills that manage your vault automatically:

| # | Skill | What it does |
|---|-------|-------------|
| 1 | **inbox-sort** | Moves notes from inbox root into existing subfolders based on content |
| 2 | **note-rename** | Renames poorly named files and updates all backlinks |
| 3 | **note-quality-check** | Scores notes by quality, recommends what to keep or delete |
| 4 | **property-describe** | Generates concise `description` frontmatter from note content |
| 5 | **property-classify** | Sets lifecycle `status` and `type` properties automatically |
| 6 | **property-enrich** | Fills missing metadata: title, dates, aliases, source, priority |
| 7 | **tag-manage** | Audits tag quality, suggests tags from content, cleans duplicates |

Each skill follows the **Core + Nahbereich + Report** principle: do the job,
fix adjacent issues, and report everything else.

## What This Does NOT Do

This is not a syntax reference. It does not teach agents what Obsidian Markdown looks like.
This is not a diagram generator. It does not create Excalidraw or Mermaid visualizations.

It automates your vault. Nobody else does that.

## Works Great With

| # | Repo | What it adds |
|---|------|-------------|
| 1 | [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) | Teaches agents Obsidian syntax — the knowledge layer our skills build on |
| 2 | [axtonliu/axton-obsidian-visual-skills](https://github.com/axtonliu/axton-obsidian-visual-skills) | Generates diagrams and visualizations from your notes |

Three repos, three different jobs. They teach and visualize. We automate.

## Installation

### Claude Code Marketplace (recommended)

Add the marketplace and install:

```bash
/plugin marketplace add neckarshore-ai/mmp-obsidian-vault-autopilot
/plugin install obsidian-vault-autopilot@neckarshore-ai
```

### Manual

Clone and point Claude Code at the plugin:

```bash
git clone https://github.com/neckarshore-ai/mmp-obsidian-vault-autopilot.git
claude --plugin-dir ./mmp-obsidian-vault-autopilot
```

### Prerequisites

- [Claude Code](https://claude.ai/code) with plugin support
- An Obsidian vault (any structure, any size)
- Set your vault path:
  ```bash
  export OBSIDIAN_VAULT_PATH="/path/to/your/vault"
  ```

## How We Compare

| | Kepano | Axton | Vault Autopilot |
|---|--------|-------|----------------|
| **Focus** | Format reference | Visualization | Vault automation |
| **Skills type** | Passive (documentation) | Generative (creates visuals) | Active (manages files) |
| **Acts on your vault** | No | No | Yes |
| **AI-powered metadata** | No | No | Yes |
| **Quality gates** | No | No | Yes |

## Design Philosophy

Every skill ships with **opinionated defaults** that work out of the box.
New user? Install, set your vault path, go. Your inbox gets sorted, files get renamed,
properties get standardized.

Every default is **configurable**. Different vaults have different conventions.
See each skill's Parameters section for available options.

Skills work on **Markdown and YAML frontmatter** — not on Obsidian APIs.
Move your vault to another Markdown tool tomorrow. These skills still work.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.

---

Built by [Neckarshore AI](https://neckarshore.ai)
