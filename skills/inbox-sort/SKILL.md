---
name: inbox-sort
status: stable
description: Use when an Obsidian vault inbox is cluttered and notes need sorting into subfolders. Trigger phrases - "sort inbox", "clean up inbox", "triage inbox", "organize inbox", "inbox is cluttered", "too many notes in inbox". Also trigger when the user mentions reducing inbox size or doing a first pass on unprocessed notes.
---

# Inbox Sort

Move notes from inbox root into four buckets: `_Work`, `_Personal`, `_Edge Cases`, `WebCaptures & Social`. Fast, reliable, no over-analysis.

## Principle: Core + Nahbereich + Report

- **Core:** Categorize and move notes into four buckets
- **Nahbereich:** Delete confirmed empty files (0 bytes). Whitespace-only files: soft-delete to `_trash/` (see `references/trash-concept.md`). Flag notes with sensitive content (see Secret Scan below). Fill missing YAML `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown. See `docs/metadata-requirements.md`.
- **Report:** Summary of moves, findings (including sensitive data warnings), improvement suggestions

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |
| `clone_cluster_skip` | true | When `true` (default), Step 5b SKIPs `created` enrichment for files whose only available date source is filesystem birthtime AND whose birthtime falls in a detected clone-cluster window. See `references/clone-cluster-detection.md`. The inbox routing (Step 8-11) still runs; only the Nahbereich `created` enrichment is gated. Set to `false` to disable. |

> **Scope is intentionally not parameterized.** inbox-sort operates on the inbox folder root only — that is the skill's purpose, not a configurable surface. Running it on `vault` or `inbox-tree` would mean moving arbitrary files into `_Work` / `_Personal` / `_Edge Cases` / `WebCaptures & Social` buckets, which is destructive and outside the contract. If you want to triage a folder that is not the inbox, point `${OBSIDIAN_VAULT_PATH}` at a vault whose top-level "inbox-like" folder is the one you mean — Step 2 (Find inbox) does case-insensitive matching. This is a deliberate deviation from the v0.1.3 § 8.5 spec patch (which proposed unifying `scope` across all 4 launch-scope skills); the other 3 skills (`property-enrich`, `property-describe`, `note-rename`) carry the unified `scope` parameter.

## Five Buckets

Every note goes into exactly one bucket inside the inbox folder. Non-markdown files go to `_Attachments/`.

| Bucket | What goes here |
|--------|---------------|
| `_Work` | Business, products, dev, tools, clients, content creation |
| `_Personal` | Health, family, household, personal finance, career history |
| `_Edge Cases` | Genuinely ambiguous — could be Work or Personal, needs human decision |
| `WebCaptures & Social` | Web clippings, social media saves, external captures |
| `_Attachments` | Images, PDFs, and other non-markdown files |

The `_` prefix on Work, Personal, Edge Cases, and Attachments keeps sort buckets visually grouped. When in doubt between Work and Personal, use `_Edge Cases` — never guess.

## Pre-flight

Before **every** invocation of this skill — including resumed sessions and re-triggers within the same conversation: if running on Windows, follow [`references/windows-preflight.md`](../../references/windows-preflight.md) end-to-end (registry check, trailing-dot folder detection, the Windows-aware file-enumeration pattern, and the clone-cluster preflight WARN at Step 7). The enumeration pattern in Step 6 of the preflight applies to every subsequent file-listing call this skill makes — `List inbox root files` (step 4 below) and any inbox-tree descent included. Run the checks freshly each time. Do not assume a previous turn's pass result still holds — registry state and folder topology can change between invocations and previous results are not authoritative. On macOS or Linux, skip — the preflight is a no-op there.

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask the user.
2. **Find inbox** — scan top-level folders for one containing "inbox" (case-insensitive). If ambiguous, ask.
3. **Ensure buckets exist** — create `_Work`, `_Personal`, `_Edge Cases`, `WebCaptures & Social`, and `_Attachments` inside the inbox if they do not exist.
4. **List inbox root files** — all files directly in the inbox root, not in subfolders. Separate into markdown (`.md`) and non-markdown files.
5. **Apply cooldown** — skip notes created less than `cooldown_days` ago (grace period for active work). The date source is YAML `created`, but corruption-tolerant in this exact order:
   - **5a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md`. Verdict-routing per `references/yaml-sanity.md` § "Per-skill policy":
     - `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon, typical Apple Notes / Drafts import artifact): normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns (broadened from v0.1.2 hardcoded `"created:"`/`"modified:"`). After normalization, resolve duplicate-key collisions per recipe (f) Step 3 (identical → silent dedup; divergent → ABORT, see next bullet). Re-call sanity-check (idempotent fixpoint).
     - `DUPLICATE_KEYS_IDENTICAL_VALUES` (v0.1.4 W4): repair via recipe (f) silent dedup, then re-run sanity-check.
     - `DUPLICATE_KEYS_DIVERGENT_VALUES` (v0.1.4 W4 — F7 family): **skip the file** + log Class-A finding "duplicate-key-divergent-values" (route to user / note-rename).
     - `MULTIPLE_FRONTMATTER_BLOCKS` or `UNCLOSED_FRONTMATTER`: skip the file and log Class-A finding (route to note-rename for handling).
     - `OK_QUOTED`: proceed normally.
     - `OK` / `OK_NO_FRONTMATTER`: proceed normally.

     YAML edits MUST follow `references/yaml-edits.md` (recipes b + f). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 5c silently skips legitimate candidates. Mirrors note-rename Step 4a — historical bugs: repo issues #4 and #6 (2026-04-27) for `created`/`modified`; F26 cross-skill cluster (2026-04-28) generalized the inside-colon pattern; F7 (GR-3 Cell 1, 2026-05-01) generalized duplicate-key resolution (v0.1.4 W4).
   - **5b. After 5a, if YAML `created` is still missing:** auto-enrich via Source Hierarchy Prio 1-3 first (filename date > Git first-commit). If Prio 1-3 yields a value, write it into YAML (Nahbereich). If Prio 1-3 yields no value, apply the **clone-cluster gate** per `references/clone-cluster-detection.md`: detect the inbox-scope cluster window once per invocation, then for this note invoke recipes (a)+(b). If recipe (a) returns 0 (in cluster) AND recipe (b) returns 1 (no alt source), SKIP `created` enrichment, log Class-C "clone-cluster birthtime, no alt source" in the findings file, and proceed to Step 5c using filesystem birthtime read via `stat` for cooldown-only purposes (the `created` field stays absent). Otherwise (no cluster, or not in cluster), fall through to Prio 4 (filesystem birthtime) and write the value into YAML. Behavior gated by config `clone_cluster_skip` (default `true`); when `false`, Prio 4 fires unconditionally.
   - **5c. Apply cooldown** using the now-trustworthy `created` value. If all sources failed in 5b, read filesystem birthtime via `stat -f %B` for cooldown only. Cooldown-skipped notes are reported in the Skipped section of the preview/report (not silently dropped). Why YAML over filesystem: Claude Code's Edit/Write tools create a new inode on APFS, resetting filesystem birthtime to "now". YAML `created` survives writes and is the only reliable source.
6. **Nahbereich pass** — permanently delete files that are 0 bytes. Soft-delete whitespace-only files to `_trash/` with trash metadata (see `references/trash-concept.md`). Log each action. YAML edits (e.g. trash metadata fields) MUST follow `references/yaml-edits.md`.
7. **Secret scan** — check each remaining note for sensitive patterns: recovery phrases (12/24 word sequences), IBAN/BIC, API keys, passwords/tokens. If detected: do NOT move to `_secret` automatically. Continue with normal categorization but flag the note in the report under Findings with the specific pattern type. The user decides what to do.
8. **Pre-sort routing** — before categorizing, auto-route by pattern:
   - Non-markdown files → `_Attachments/` (images, PDFs, etc.)
   - `YYYY-MM-DD.md` or `YYYY-MM-DD *.md` → subfolder containing "daily" (case-insensitive), not into buckets
   - Web captures and social posts (see `references/web-capture-detection.md`) → `WebCaptures & Social`
9. **Categorize remaining notes** — read title, tags, and first ~30 lines. Assign to one bucket:
   - Business/product/dev/tool content → `_Work`
   - Personal/family/health/household content → `_Personal`
   - Genuinely ambiguous → `_Edge Cases`
10. **Preview** — show routing plan grouped by bucket (see `references/report-format-inbox-sort.md`). Include secret-flagged notes with a warning marker. Wait for user confirmation. User can override individual assignments.
11. **Move files** — use Bash `mv` with proper quoting for special characters. Preserve original filenames.
12. **Skill Log** — for each moved file: add `VaultAutopilot` tag and append skill log callout row (see `references/skill-log.md`). YAML tag-list edits and skill-log callout edits MUST follow `references/yaml-edits.md` (recipes d + e).
13. **Birthtime preservation** — after writing tag/callout, restore filesystem birthtime from the YAML `created` value saved in step 5. Use `touch -t` (see `references/skill-log.md` § Birthtime Preservation). After auto-enrich in step 5, YAML `created` is almost always available. Restore from it. If auto-enrich found no source, restore from the pre-write birthtime captured in step 5.
14. **Write findings file** — for any non-trivial Findings (Class A/B/C/D as defined in `references/findings-file.md`), append a section to `<VAULT>/_vault-autopilot/findings/<YYYY-MM-DD>-inbox-sort.md`. Create the folder chain if missing. Never edit prior findings — append-only ledger.
15. **Write report** — see format below.

## Protected Files

Never move, rename, or process these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Boundaries

- No renaming files
- No deep analysis, no creating subfolders, no editing content
- No processing files already in subfolders

## Report Format

See `references/report-format-inbox-sort.md` for the full preview table format, report template, and findings catalog.

## Logging

After every run, append one row to `logs/run-history.md` and update `logs/changelog.md` if the skill itself changed.

## Quality Check

Before reporting done:
- [ ] Every moved file still exists at its new path
- [ ] No files were renamed or modified
- [ ] Cooldown was respected (no recently modified files moved)
- [ ] Nahbereich actions were logged individually (0-byte deletes and whitespace-only trashes)
- [ ] Non-markdown files moved to `_Attachments/`
- [ ] Report covers all processed and skipped notes
- [ ] Sanity-check called Step 5a per `references/yaml-sanity.md` (broadened from hardcoded `"created:"`/`"modified:"` to all quoted-keys)
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f); standard quoted-keys (shape α) pass through as `OK_QUOTED`
- [ ] Duplicate-key divergent-value collisions (F7 family) skip + Class-A finding; file is NOT moved — user resolves first (v0.1.4 W4)
