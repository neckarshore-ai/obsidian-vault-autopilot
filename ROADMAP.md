# Roadmap

## v0.1.5 — Cross-platform clone-preflight + recipe (a) runtime correctness (current)

> v0.1.5 finishes the W-track that v0.1.4 opened. v0.1.4 added the clone-cluster gate as a Windows-only preflight WARN and a runtime SKIP. v0.1.5 extends the WARN to every OS and corrects the SKIP on non-UTC macOS hosts where v0.1.4's recipe (a) was silently producing the wrong verdict. Two changes, both anchored to the same GR-3 `nexus-clone-robocopy` 2026-05-01 measurement plus the macOS CEST empirical demonstration captured during 2026-05-07:
>
> - **Cross-platform clone-preflight extraction.** The clone-cluster WARN was previously gated behind `references/windows-preflight.md` Step 7, so macOS and Linux users never saw it even when their vault was a fresh clone. The clone-cluster condition is not Windows-specific — `cp -R` on macOS, `cp -a` on Linux, `git clone`, ZIP downloads, and `robocopy` on Windows all collapse filesystem birthtimes onto the clone moment. v0.1.5 extracts the WARN to `references/clone-preflight.md` and rewires the four launch-scope SKILL.md preflight blocks to a numbered two-step block: Step 1 always runs `clone-preflight.md` (every OS); Step 2 additionally runs `windows-preflight.md` end-to-end on Windows. The Section 10 contract test in `scripts/test-clone-preflight.sh` asserts the unconditional invocation across all four SKILL.md files — without it the file extraction would have been undetectable as a behavior change.
> - **Recipe (a) runtime correctness on non-UTC macOS.** v0.1.4 W2 shipped recipe (a) `is_birthtime_in_clone_cluster_window` with `stat -f '%SB' -t '%Y-%m-%dT%H:%M:%SZ'` on Darwin. That format string formats local time and slaps a literal `Z` suffix; on a non-UTC macOS host the resulting "ISO" string disagreed with the genuinely-UTC window from `scripts/detect-clone-cluster.sh` by the local-UTC offset. Recipe (a) returned wrong SKIP verdicts on every macOS user in a non-UTC timezone, causing date-derivation skills to fall through to filesystem birthtime and write clone-time as `created` for cluster files. The Linux path was already epoch-based and correct. v0.1.5 unifies both platforms on numeric epoch compare via two new detector fields (`CLONE_CLUSTER_WINDOW_START_EPOCH` + `CLONE_CLUSTER_WINDOW_END_EPOCH`); existing ISO string fields are preserved for the WARN message in `clone-preflight.md`. A lock-in assertion in `scripts/test-clone-cluster.sh` (deliberately omitted in v0.1.4 W2 because the broken format-string would have failed it) now passes cleanly and trips immediately on any future regression to local-time-with-`Z` handling.
>
> Affected users: any v0.1.4 install on a non-UTC macOS host that ran `property-enrich` (or another date-derivation skill) on a cloned vault between v0.1.4 ship (2026-05-07) and v0.1.5 upgrade. Remediation requires three steps because `property-enrich` is additive-only and will not re-evaluate a file whose `created` field is already populated (Step 3 of the workflow only walks the Source Hierarchy `for each note missing created`): (1) run `scripts/detect-clone-cluster.sh` against the affected vault to identify the cluster window (ISO timestamps + file count); (2) for each file whose `created` value falls inside the cluster window, blank the `created` field (delete the YAML line) — these are the cluster-suspect files; (3) re-run `property-enrich`. The v0.1.5 SKIP-gate will now correctly fire on the blanked files: those with no alt source surface as Class-C "clone-cluster birthtime, no alt source" findings; those with an alt source (filename `YYYY-MM-DD` pattern, git first-commit) get the correct `created` value derived via Source Hierarchy Prio 1-3. Without the blank step, the additive-only contract leaves the poisoned values silent.
>
> Launch-scope feature set unchanged from v0.1.4. See `logs/changelog.md`.

## v0.1.4 — Public-Flip blockers + mode-shift unification (previous)

> v0.1.4 closes the four Public-Flip blockers surfaced during GR-3 strict-path runs against `nexus-clone-robocopy` (2026-05-01). The vault was a robocopy-cloned Windows vault; strict-path validation found ship-blocking gaps that v0.1.3's defense-in-depth could not reach because they sat below the YAML layer (filesystem enumeration, filesystem birthtime, robocopy clone-time semantics, and a duplicate-key policy that silently picked the wrong winner). All four are now closed:
>
> - **W1 (F-NEW-A-1) — Windows trailing-dot enumeration.** Win32 path normalization independently strips trailing `.` and trailing space from path components, regardless of `LongPathsEnabled`. 670 files / 301 markdown were silently invisible inside `030_Systems - reference material.`. Step 5 of `references/windows-preflight.md` detects, Step 6 prescribes the per-language Windows-aware enumeration pattern (`\\?\` extended-path prefix on Windows, pass-through on macOS / Linux).
> - **W2 — Clone-cluster mode-shift gate.** When robocopy / cp -R / git clone collapses every file's filesystem birthtime onto the clone moment, falling through Source Hierarchy to filesystem birthtime poisons `created` for everything. The new gate (`references/clone-cluster-detection.md`, recipes a + b) detects the cluster, identifies files with no alternate date source, and SKIPs `created` enrichment for those files (logged as Class-C). 4 launch-scope SKILL.md files are wired in.
> - **W3 — Robocopy clone-integrity preflight.** Step 7 of `references/windows-preflight.md` (WARN-flow, not STOP-flow) calls `scripts/detect-clone-cluster.sh` at preflight time and emits a non-blocking warning showing cluster file count + window when found, so the user sees what runtime will SKIP. Three cross-repo retractions (`docs/windows-considerations.md`, `docs/cloning-guide.md`, planning Master Plan §3) replaced the unconditional "robocopy /COPY:DAT preserves CreationTime" claim with empirical reality (post-clone Defender / Search-Indexer / Obsidian-cache writes can reset 36.8 % of files to clone moment).
> - **W4 (F7) — recipe-(f) duplicate-key resolution policy.** When recipe (f) normalizes shape β `"key:":` to plain `key:`, it can collide with an existing plain `key:` line. v0.1.3 silently kept the first value. v0.1.4 distinguishes identical-value collisions (silent dedup, Class-D) from divergent-value collisions (ABORT recipe (f), file unchanged, new Class-A finding "duplicate-key-divergent-values"). Pattern 5 in `references/yaml-sanity.md` makes the detection universal — pre-existing plain duplicates are also caught now, not only post-shape-β-normalize.
>
> Launch-scope feature set unchanged from v0.1.3. See `logs/changelog.md`.

## v0.1.3 — Quoted-key cluster repair + pre-write YAML sanity (previous)

> v0.1.3 closes the F25 / F26 / F19-LIVE cluster surfaced during GR-2 Cell 1 + Cell 4 (2026-04-28). Apple-Notes-vintage imports left YAML frontmatter with two distinct quoted-key shapes — shape α `"description":` (standard, valid YAML) and shape β `"description:":` (inside-colon, invalid-as-author-intended). Both bit launch-scope skills, but the fixes differ. v0.1.3 introduces a pre-write sanity-check (`references/yaml-sanity.md`) that classifies frontmatter and returns a verdict the skill uses to decide proceed / repair / skip. Recipe (f) in `references/yaml-edits.md` performs the shape-β normalize. All 4 launch-scope skills now call sanity-check at step zero (defense-in-depth, idempotent). German DACH date format (`DD.MM.YYYY[, HH:mm:ss]`) is recognized in property-enrich Source Hierarchy Prio 1. See `logs/changelog.md`.

Launch-scope feature set unchanged from v0.1.2.

## v0.1.2 — YAML-edit hardening (previous)

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
