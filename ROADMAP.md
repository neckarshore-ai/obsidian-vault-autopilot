# Roadmap

## v0.1.2 — YAML-edit hardening (current)

> v0.1.2 closes two mid-run regex bugs surfaced during the 2026-04-27 launch shake-out: F8 (inbox-sort callout-append regex did not handle `> ` blockquote prefix on the table separator line) and F15 (property-enrich `tags:` regex was greedy across newlines under `(?s)`). Root cause was identical: each LLM run wrote its own ad-hoc multi-line regex. v0.1.2 codifies line-by-line YAML/Markdown editing as the only allowed approach (`references/yaml-edits.md`) and introduces a vault-side findings ledger (`references/findings-file.md`) so Obi can resume across sessions. See `logs/changelog.md`.

Launch-scope feature set unchanged from v0.1.1.

## v0.1.1 — Launch

> Launch-scope feature set is identical to v0.1.0. v0.1.1 hardens the Windows preflight gate (non-skippable wording, shorter recovery command) and bumps the version so the marketplace cache can deliver updates to existing installs. See `logs/changelog.md`.


Six skills that automate Obsidian vault management:

| # | Skill | What it does | Status |
|---|-------|-------------|--------|
| 1 | inbox-sort | Moves notes from inbox to correct subfolders based on content | beta |
| 2 | note-rename | Renames poorly named files, updates all backlinks | stable |
| 3 | note-quality-check | Scores notes by quality, recommends what to keep or delete | beta |
| 4 | property-describe | Generates concise description frontmatter from note content | beta |
| 5 | property-classify | Sets lifecycle status and type properties automatically | beta |
| 6 | property-enrich | Fills missing metadata: title, dates, aliases, source, priority | stable |

**Launch-scope (4 skills, v0.1.1):** note-rename + inbox-sort + property-enrich (stable) + property-describe (in development). The 4 skills together cover the typical first-pass: rename poorly named files → sort the inbox → fill missing metadata → describe what each note is about. All 4 ship with the Windows pre-flight gate.

Skills marked **beta** work but may change behavior based on community feedback.

## v0.1.x — Stability

Bug fixes, community feedback, cross-platform validation.

| # | Item | Description |
|---|------|-------------|
| 1 | Cross-platform testing | Validate on macOS, Linux, Windows (WSL) |
| 2 | Community feedback loop | Triage issues, adjust defaults based on real vault diversity |
| 3 | Skill file refactoring | Extract detailed rule sets into reference documents for maintainability |
| 4 | Getting started guide | Step-by-step onboarding for new users |

## v0.2.0 — Configurability

The **Settings Layer** — making skills adapt to your vault instead of the other way around.

Today, skills ship with opinionated defaults that work out of the box. v0.2.0 adds a configuration layer so every default becomes overridable.

We have identified **40 configurable attributes** across all skills, prioritized by user impact. See the full specification in [references/config-spec.md](references/config-spec.md).

### What Comes First (Tier 1)

These 11 attributes cause the most friction when they do not match your vault. They ship first:

| # | Attribute | Default | What it controls |
|---|-----------|---------|-----------------|
| 1 | `folders.inbox` | Auto-detect | Which folder skills scan by default |
| 2 | `folders.trash` | `_trash` | Where soft-deleted notes go |
| 3 | `folders.secret` | `_secret` | Where sensitive notes are moved |
| 4 | `folders.daily_notes` | Auto-detect | Your Daily Notes folder location |
| 5 | `cooldown_days` | `3` | Grace period before automation touches new notes |
| 6 | `scope` | `inbox` | Default scan scope (inbox, vault-wide, or specific folder) |
| 7 | `folders.excluded_prefixes` | `["_", "."]` | Folder prefixes to skip during scans |
| 8 | `skill_log.tag` | `true` | Toggle the VaultAutopilot tracking tag |
| 9 | `skill_log.callout` | `true` | Toggle the history callout at the end of notes |
| 10 | `uninformative_patterns` | 7 patterns (EN+DE) | Filename patterns that trigger rename — extensible for any language |
| 11 | `confirm` | `true` | Require confirmation before execution (disable for automation) |

7 of these 11 attributes are **global** — they affect all skills, not just note-rename. The configuration infrastructure benefits the entire plugin.

### Folder Names

Different vaults use different naming conventions. The inbox might be `Inbox`, `_Inbox`, `00-Inbox`, or `Eingang`. Same for trash, secret, and daily notes folders.

v0.2.0 introduces configurable folder mappings:

```yaml
folders:
  inbox: "00-Inbox"
  trash: "_trash"
  secret: "_secret"
  daily_notes: "Daily Notes"
```

Skills resolve these names from config instead of assuming defaults.

### Feature Toggles

Not every user wants every output. The skill-log (VaultAutopilot tag + callout history at the end of each note) is useful for tracking what happened — but some users prefer clean notes without automation traces.

```yaml
skill_log:
  tag: true          # Add VaultAutopilot tag to frontmatter
  callout: true      # Append history callout to note body
```

Both default to `true`. Set to `false` to disable.

### Output Shape

Control what skills write into your notes:

```yaml
output:
  date_format: "YYYY-MM-DD"    # Date format in skill-log entries
  add_tag: true                 # Whether to add the VaultAutopilot tag
  add_callout: true             # Whether to append the history callout
```

This is a **Settings Layer**, not a rule engine. It controls the shape of skill output — what gets written, where, and in what format. It does not change skill logic or classification rules.

### Vault Onboarding

A new skill that analyzes your vault structure and proposes a configuration:

- Detects existing folder conventions
- Identifies inbox, archive, and daily notes locations
- Suggests property schemas based on what your notes already use
- Generates a starter config file

Run it once when you install the plugin. Re-run it when your vault evolves.

## v0.3.0 — Tag Management and Orchestration

### tag-manage Skill

Audits tag quality, suggests tags from content, cleans duplicates, enforces naming conventions.

| # | Feature | Description |
|---|---------|-------------|
| 1 | Tag audit | Find unused, duplicate, and inconsistent tags |
| 2 | Auto-tagging | Suggest tags based on note content |
| 3 | Tag cleanup | Merge duplicates, fix casing, remove orphans |
| 4 | Naming conventions | Enforce kebab-case, singular nouns, or your own rules |

### Multi-Skill Orchestration

Run skills in sequence with a single command. Example workflow:

```
inbox-sort → note-rename → property-enrich → property-describe
```

The orchestrator handles ordering, passes findings between skills, and produces a combined report.

## Future Ideas

These are not committed — they depend on community interest and feedback.

| # | Idea | Description |
|---|------|-------------|
| 1 | Attachment detect | Scan folders for non-Markdown files (images, PDFs, media, scripts), classify as companion/orphan/sensitive, report inventory. [Plan](docs/plans/non-markdown-detection-skill.md) |
| 2 | Social scraper | Import content from external platforms into vault notes |
| 3 | Research report | Generate research summaries from a list of URLs |
| 4 | Social post | Draft social media posts from vault notes |
| 5 | Bring Your Own Context | Let skills reference external knowledge bases or project-specific conventions |
| 6 | Scheduled runs | Automated skill execution on a schedule (daily inbox sort, weekly quality check) |
| 7 | Test data generator | Generate test fixtures for any skill to validate before running on your real vault |
| 8 | Confidence tags in reports | Tag every AI recommendation as `high` / `medium` / `low` confidence so users know what was found vs guessed. Aligns with the "AI recommends, human decides" principle. Inspired by graphify's EXTRACTED/INFERRED/AMBIGUOUS pattern. |
| 9 | `.vaultautopilotignore` file | Gitignore-syntax exclude file at vault root. Skills skip listed paths (templates, archive, generated folders) during scans. Inspired by graphify's `.graphifyignore`. |
| 10 | Incremental run cache | SHA256 content cache so re-runs only process changed notes. Critical for vaults > 1k notes where full scans become slow. Inspired by graphify's per-file cache. |

---

Have an idea? [Open an issue](https://github.com/neckarshore-ai/obsidian-vault-autopilot/issues) or check [CONTRIBUTING.md](CONTRIBUTING.md).
