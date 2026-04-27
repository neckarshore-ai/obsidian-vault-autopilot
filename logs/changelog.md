# Changelog

Shared changelog for the obsidian-vault plugin. All skills and references log their changes here.

| Date | Component | Change |
|------|-----------|--------|
| 2026-04-01 | inbox-sort | Initial Claude Code version — vault-agnostic, dynamic subfolder discovery |
| 2026-04-01 | references/web-capture-detection | Created shared detection rules (extracted from previous inbox-sort + note-rename) |
| 2026-04-01 | logs | Created shared changelog and run history |
| 2026-04-01 | note-rename | Initial Claude Code version — content-based renaming, backlink updates |
| 2026-04-01 | note-quality-check | Initial Claude Code version — scoring, deletion recommendations |
| 2026-04-01 | property-describe | Initial — AI-generated description summaries (max 250 chars) |
| 2026-04-01 | property-classify | Initial — status (lifecycle) + type (category) in one pass |
| 2026-04-01 | property-enrich | Initial — fill missing metadata (title, dates, aliases, parent, source, priority) |
| 2026-04-01 | tag-manage | Initial — audit + suggest tags (consolidated from 3 previous skills) |
| 2026-04-01 | references/tag-convention | Created shared tag convention reference |
| 2026-04-01 | **Phase 2 complete** | 7/10 skills done. Phase 3 (social-post, social-scrape, research-report) deferred |
| 2026-04-27 | **v0.1.1** | Pre-launch hardening release (Windows safety + plugin updatability) |
| 2026-04-27 | references/windows-preflight | Non-skippable wording — explicit "run on EVERY invocation, no caching across turns" directive at the top, plus parallel wording in each launch-scope SKILL.md Pre-flight section. Closes Resume-Session-Skip risk identified in 2026-04-27 b live-validation. |
| 2026-04-27 | references/windows-preflight | Recovery command shortened from PowerShell `New-ItemProperty` (~130 chars) to `reg add` from elevated cmd.exe (~95 chars) — reduces paste-truncation risk on Windows clipboards. Verify command also switched to `reg query` for consistency. |
| 2026-04-27 | docs/windows-considerations | Added "Session Discipline & First-Run Gotchas" section — 5 platform behaviors first-time Windows users should know: Resume-Session-Skip, PowerShell first-use authorization, project-vs-user plugin enablement, OAuth right-click paste, why marketplace updates may not update. |
| 2026-04-27 | plugin.json + marketplace.json | Version bump 0.1.0 → 0.1.1. Marketplace caches by version field; existing 0.1.0 installs need this bump to receive updates. |
