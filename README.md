# Obsidian Vault Autopilot

AI-powered vault management for Claude Code. Sorts your inbox, renames your files,
enriches your metadata — so you can focus on thinking instead of filing.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What This Does

Seven skills that manage your vault automatically:

| # | Skill | What it does | Status |
|---|-------|-------------|--------|
| 1 | **inbox-sort** | Moves notes from inbox root into existing subfolders based on content | ✅ stable |
| 2 | **note-rename** | Renames poorly named files and updates all backlinks | ✅ stable |
| 3 | **property-enrich** | Fills missing metadata: title, dates, aliases, source, priority | ✅ stable |
| 4 | **note-quality-check** | Scores notes by quality, recommends what to keep or delete | 🚧 in development |
| 5 | **property-describe** | Generates concise `description` frontmatter from note content | 🚧 in development |
| 6 | **property-classify** | Sets lifecycle `status` and `type` properties automatically | 🚧 in development |
| 7 | **tag-manage** | Audits tag quality, suggests tags from content, cleans duplicates | 🚧 in development |

Skills marked **🚧 in development** are not ready for use — behavior will change.

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

## ⚠️ Safety

> **No backup, no mercy.** This tool moves, renames, and deletes files in your vault. Always back up first.

### Before You Start

1. ⚠️ **[Back up your vault](docs/backup-and-recovery.md)** before running any automation skill
2. 🧪 **[Test on a copy first](docs/cloning-guide.md)** — clone your vault and run skills there before touching production
3. 📂 **Start small** — pick a single folder, not your entire vault
4. 📋 **[Check metadata requirements](docs/metadata-requirements.md)** — skills depend on YAML frontmatter, especially `created`

### How Your Data Stays Safe

| # | Feature | What it does |
|---|---------|-------------|
| 1 | 🗑️ **Soft-delete** | Removed files go to `_trash/` with recovery metadata — nothing is permanently deleted |
| 2 | 👀 **Preview + Confirm** | Every destructive action shows what will change and waits for your approval |
| 3 | ⏳ **Cooldown** | New files are protected for 3 days (configurable) before automation touches them |
| 4 | 📝 **Skill Log** | Every action is logged with timestamp, skill name, and what changed |
| 5 | 🔒 **Secret Detection** | Files containing API keys, passwords, or financial data are flagged, not auto-moved |

### Disclaimer

⚠️ This tool modifies your vault files. You are responsible for maintaining backups.
See the [MIT License](LICENSE) for full warranty and liability terms.

By using this software, you acknowledge that you have read and understood the
[MIT License](LICENSE) terms.

For security issues, see [SECURITY.md](SECURITY.md). For contribution guidelines,
see [CONTRIBUTING.md](CONTRIBUTING.md). For community guidelines, see
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Installation

### Claude Code (recommended)

Add the marketplace and install the plugin:

```bash
/plugin marketplace add neckarshore-ai/obsidian-vault-autopilot
/plugin install obsidian-vault-autopilot@neckarshore-ai
```

### Manual

Clone the repo and register it as a local marketplace:

```bash
git clone https://github.com/neckarshore-ai/obsidian-vault-autopilot.git \
  ~/.claude/plugins/obsidian-vault-autopilot
```

Then in Claude Code:

```bash
/plugin marketplace add ~/.claude/plugins/obsidian-vault-autopilot
/plugin install obsidian-vault-autopilot@neckarshore-ai
```

### Prerequisites

- [Claude Code](https://claude.ai/code) with plugin support
- An Obsidian vault (any structure, any size)
- Set your vault path:
  ```bash
  export OBSIDIAN_VAULT_PATH="/path/to/your/vault"
  ```

## How We Compare

| | **Vault Autopilot** | [kepano-obsidian](https://github.com/kepano/kepano-obsidian) | [axton-obsidian-visual-skills](https://github.com/axtonliu/axton-obsidian-visual-skills) |
|---|---|---|---|
| **Focus** | 🤖 Vault automation | 📖 Format reference | 🎨 Visualization |
| **Skills type** | Active (manages files) | Passive (documentation) | Generative (creates visuals) |
| **Acts on your vault** | ✅ Yes | ❌ No | ❌ No |
| **AI-powered metadata** | ✅ Yes | ❌ No | ❌ No |
| **Quality gates** | ✅ Yes | ❌ No | ❌ No |
| **Skills count** | 7 (3 stable, 4 in dev) | ~20 | ~10 |

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
