# Roadmap

## v0.1.0 — Launch (current)

Six skills that automate Obsidian vault management:

| # | Skill | What it does | Status |
|---|-------|-------------|--------|
| 1 | inbox-sort | Moves notes from inbox to correct subfolders based on content | stable |
| 2 | note-rename | Renames poorly named files, updates all backlinks | stable |
| 3 | note-quality-check | Scores notes by quality, recommends what to keep or delete | beta |
| 4 | property-describe | Generates concise description frontmatter from note content | beta |
| 5 | property-classify | Sets lifecycle status and type properties automatically | beta |
| 6 | property-enrich | Fills missing metadata: title, dates, aliases, source, priority | stable |

**Launch-featured:** note-rename and inbox-sort — the two skills most users need first.

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
inbox-sort → note-rename → property-enrich → property-classify
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

---

Have an idea? [Open an issue](https://github.com/neckarshore-ai/mmp-obsidian-vault-autopilot/issues) or check [CONTRIBUTING.md](CONTRIBUTING.md).
