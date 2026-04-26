# Obsidian Vault Autopilot

AI-powered vault automation for Obsidian × Claude Code. Sorts your inbox,
renames your notes, enriches your frontmatter — so you can focus on finding,
collecting, and thinking instead of filing.

Build your Second Brain rapidly. Let the Autopilot handle the tedious stuff.

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
| 7 | **tag-manage** | Audits tag quality, suggests tags from content, cleans duplicates | 📅 v0.2.0 |

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

## How We Compare

| | **Vault Autopilot** | [kepano-obsidian](https://github.com/kepano/kepano-obsidian) | [axton-obsidian-visual-skills](https://github.com/axtonliu/axton-obsidian-visual-skills) |
|---|---|---|---|
| **Focus** | 🤖 Vault automation | 📖 Format reference | 🎨 Visualization |
| **Skills type** | Active (manages files) | Passive (documentation) | Generative (creates visuals) |
| **Acts on your vault** | ✅ Yes | ❌ No | ❌ No |
| **AI-powered metadata** | ✅ Yes | ❌ No | ❌ No |
| **Quality gates** | ✅ Yes | ❌ No | ❌ No |
| **Skills count** | 7 (3 stable, 4 in dev) | ~20 | ~10 |

## Safety

> **This plugin performs destructive file operations on your Obsidian vault.** It moves files, renames files, changes frontmatter, and soft-deletes files to `_trash/`. There is no undo button at the plugin level. Read this section before your first run.

### No Backup, No Mercy

Before you run any skill, you need a backup you can restore from. Not "I have Obsidian Sync" (Sync is not a backup). Not "I have iCloud" (iCloud is not a backup for this purpose). A real, restorable backup: Time Machine, rsync snapshot, Git commit, or a vault copy on another disk. See [Backup and Recovery](docs/backup-and-recovery.md).

### Before Your First Run

1. **[Back up your vault](docs/backup-and-recovery.md)** — a real, restorable backup, not a sync service.
2. **[Clone your vault](docs/cloning-guide.md)** and run skills on the clone first. The clone method matters — `cp -R` resets birthtimes; Finder and `ditto -V` preserve them on APFS. **On Windows**, File Explorer copy silently drops files at long paths — use `robocopy` instead. See the [Cloning Guide](docs/cloning-guide.md) and [Windows Considerations](docs/windows-considerations.md) for details.
3. **[Check your metadata](docs/metadata-requirements.md)** — skills depend on YAML `created` fields. Low coverage? Run `property-enrich` first.
4. **[Read the Birthday Bug](docs/incident-birthday-bug.md)** — we damaged our own vault early in development. If the plugin ever damages yours, we want you to see how we learned.
5. **Start small** — pick a single folder, not your whole vault. Run `--preview` before any real execution.

New to this plugin? Follow the **[Getting Started](docs/getting-started.md)** guide for a step-by-step first run.

### How Your Data Stays Safe

| # | Feature | What it does |
|---|---------|-------------|
| 1 | **Soft-delete** | Removed files go to `_trash/` with recovery metadata (`trash_source`, `trash_origin`). Nothing is permanently deleted by a skill. |
| 2 | **Preview + Confirm** | Every destructive action shows what will change and waits for your approval. `--preview` is also available as a standalone mode. |
| 3 | **Cooldown** | Files newer than 3 days (configurable) are protected from automation. Gives you time to notice new notes before automation touches them. |
| 4 | **Skill Log** | Every action is logged with timestamp, skill name, and what changed — in the note frontmatter and in `logs/run-history.md`. |
| 5 | **Secret Detection** | Files containing API keys, recovery phrases, or financial data are flagged and moved to `_secret/`, never touched by sorting logic. |

### Known Limitations

- **Fresh clones confuse cooldown.** A vault cloned with `cp -R`, Windows Explorer, `git clone`, or a GitHub ZIP download has fresh birthtimes on every file. Without YAML `created` coverage, cooldown will protect everything and skills will no-op. Run `property-enrich` first. Finder and `ditto -V` on macOS preserve birthtimes. See [Cloning Guide](docs/cloning-guide.md).
- **Obsidian Sync + clone-in-neighbor-folder is dangerous.** If Sync is active and you clone into a folder Sync can see, operations on the clone may propagate back. Always disable Sync on the clone first.
- **Windows long path limit (MAX_PATH 260) silently hides files.** On Windows without long path support enabled, files at paths exceeding 260 characters are invisible to PowerShell enumeration and to Vault Autopilot skills. Deep PARA folder structures cross 260 characters routinely. Enable long path support in the registry before running any skill. File Explorer / `Copy-Item` cloning also drops these files silently — use `robocopy` instead. Full procedure in [Windows Considerations](docs/windows-considerations.md).

### Disclaimer

This software performs destructive file operations on your Obsidian vault. There is no warranty, express or implied.

By running any skill, you confirm that:

1. You are responsible for maintaining backups of your vault.
2. You have read the [Cloning Guide](docs/cloning-guide.md) and will test on a clone first.
3. You accept that destructive automation on your own files is your decision and your responsibility.

See the [MIT License](LICENSE) for full warranty and liability terms.

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

## Design Philosophy

Every skill ships with **opinionated defaults** that work out of the box.
New user? Install, set your vault path, go. Your inbox gets sorted, files get renamed,
properties get standardized.

Every default is **configurable**. Different vaults have different conventions.
See each skill's Parameters section for available options.

Skills work on **Markdown and YAML frontmatter** — not on Obsidian APIs.
Move your vault to another Markdown tool tomorrow. These skills still work.

## Contributing

Found a bug? Have a skill idea? **[Open an issue](https://github.com/neckarshore-ai/obsidian-vault-autopilot/issues)** — that's how we track and prioritize all work. New skill proposals start as issues, not pull requests.

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.

---

Built by [Neckarshore AI](https://neckarshore.ai)
