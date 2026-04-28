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
| 2026-04-27 | property-describe + README + ROADMAP | property-describe Pre-flight section added (4-of-4 launch-scope skills now gated). README + ROADMAP launch-scope language reconciled to 4-skill scope (matches Gary 2026-04-23b marketing posts on neckarshore-ai-hq, commit `7f5bc98`). Closes Drift between marketing-source-of-truth (4 skills) and code-source-of-truth (was 3 skills). |
| 2026-04-27 | **v0.1.2** | YAML-edit hardening + findings convention |
| 2026-04-27 | references/yaml-edits | Created — canonical line-by-line spec for YAML/Markdown edits. Forbids multi-line regex (`(?s)`, `(?m)`, `.+`/`.*` over newlines) and `str.replace` for non-atomic edits. Includes recipes for read-frontmatter / replace-field / add-field / append-to-list / append-callout-row, plus DO-NOT examples for F8 (callout `> ` blockquote prefix) and F15 (`tags:` greedy regex). Closes mid-run regex bugs identified in F8/inbox-sort GR-1 (93/105 missing move-row) and F15/property-enrich GR-2 (16 orphan `- VaultAutopilot` lines). |
| 2026-04-27 | references/findings-file | Created — vault-side findings convention. Path `<VAULT>/_vault-autopilot/findings/<YYYY-MM-DD>-<skill>.md`. Append-only ledger, never edit prior findings. Obi reads on session start via `ls _vault-autopilot/findings/*.md`. |
| 2026-04-27 | references/vault-autopilot-note | Added Protected Files rule 7: `_vault-autopilot/` folder is plugin-managed, written only during the findings-write step. |
| 2026-04-27 | inbox-sort + note-rename + property-enrich + property-describe | Added cross-references to `references/yaml-edits.md` in YAML-touching workflow steps; added "Write findings file" step before final report. property-enrich workflow Step 5 wording tightened from "add fields, preserve values" to explicit line-by-line mandate. property-enrich Quality Check extended with line-by-line + findings-file items. |
| 2026-04-27 | plugin.json + marketplace.json | Version bump 0.1.1 → 0.1.2. Marketplace caches by version field; existing 0.1.1 installs need this bump to receive updates. |
