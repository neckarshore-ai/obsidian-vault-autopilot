# tag-manage Design Spec (v0.2.0)

**Date:** 2026-05-06
**Status:** Design — awaiting user review
**Ship target:** v0.2.0 (post-public-flip, after v0.1.4 ships)
**Authors:** Obi (Skill Master), reviewed by advisor()
**Related spec:** [tag-suggest design](./2026-05-06-tag-suggest-design.md) — sibling skill v0.2.x

---

## 1. Purpose

`tag-manage` is the v0.2.0 skill that finds tags written in multiple inconsistent ways across an Obsidian vault and unifies them on a canonical form, guided by a naming convention. The user-stated soul: *"aus dem Tag-Dschungel die Essenz rauszuziehen."*

This spec covers the v0.2.0 MVP. Out-of-scope features are listed in §11.

## 2. Background

A previous version of this skill exists in Claude Desktop (~600 lines, 60+ brand overrides, 80+ compound overrides, hardcoded paths to a single Nexus vault). It is incompatible with this repo's conventions:
- Hardcoded `/sessions/...` Claude-Desktop sandbox paths
- `request_cowork_directory` MCP tool (Claude Desktop only)
- `sed -i` mutations that violate the repo's no-multi-line-regex rule (per `references/yaml-edits.md` — F8/F15 lessons)
- Override lists ~95% Nexus-specific
- Nexus-specific report destination

**This spec is a from-scratch rebuild that respects:**
- `references/yaml-edits.md` line-by-line discipline
- `references/windows-preflight.md` cross-platform pattern
- `references/skill-log.md` callout + birthtime preservation
- `references/findings-file.md` ledger
- Production Vault Safety Rules (CLAUDE.md)
- `docs/philosophy.md` Core + Nahbereich + Report

## 3. Scope (MVP — Mode A)

| In scope | Out of scope (deferred) |
|---|---|
| Tier 1 case-variant detection | Tier 4 plural/singular dedupe (v0.3.0) |
| Tier 2 whitespace/hyphen normalization | Tier 5 abbreviation dedupe (v0.3.0) |
| Tier 3 convention violation detection | Tier 6 semantic-near-dupe (v0.3.0) |
| AI canonical resolution + vault pin override | Hierarchy-analysis (`Software/DevTools` vs `DevTools`) |
| Apply (rename + remove) with user gate | Folder-exclusive tag enforcement (schema reserved, MVP no-op) |
| Findings-file ledger | Tag-Index file generation (separate skill v0.3.0+) |
| Cross-platform (mac, linux, windows) | Vault-wide master summary report |
| Convention-schema parser + plugin/vault merge | `tag-manage --reverse <findings>` mode |

**Non-goal:** suggesting tags for untagged notes — that is `tag-suggest` (v0.2.x).

## 4. User-facing Triggers

```yaml
description: |
  Use when an Obsidian vault has accumulated inconsistent tag spellings — same concept
  written multiple ways — and needs unified to a canonical form. Audits the vault, proposes
  fixes per a naming convention, and applies approved changes.
  Trigger phrases: "audit tags", "fix tags", "tag duplicates", "tag cleanup",
  "find duplicate tags", "tag consistency", "convention violations", "rename tags",
  "tag report", "untangle tags", "tag-Dschungel".
```

## 5. Architecture

### 5.1 Plugin Layout

```
obsidian-vault-autopilot/
├── skills/
│   └── tag-manage/
│       └── SKILL.md                     [NEW v0.2.0]
├── references/
│   ├── tag-convention.md                [EXTEND — YAML schema added]
│   ├── yaml-edits.md                    [EXTEND — recipes (g) + (h)]
│   ├── vault-config.md                  [NEW — schema spec doc]
│   └── (existing references unchanged)
├── scripts/
│   └── test-fixtures/
│       └── generate-synthetic-vault.sh  [NEW — test data generator]
├── tests/
│   ├── unit/tag-manage/                 [NEW — bats]
│   ├── integration/tag-manage/          [NEW — golden-output]
│   └── fixtures/
│       ├── curated/tag-manage/          [NEW — handcrafted small vaults]
│       └── synthetic/                   [generated, not committed]
└── docs/superpowers/specs/
    └── 2026-05-06-tag-manage-design.md  [THIS FILE]
```

### 5.2 Vault Layout

```
[VAULT]/
├── _vault-autopilot/
│   ├── config/
│   │   └── tag-convention.md            [optional vault-override]
│   └── findings/
│       └── 2026-MM-DD-tag-manage.md     [audit + apply ledger per run]
└── (user notes)
```

**Note:** Vault-config lives at `[VAULT]/_vault-autopilot/config/`, **not** `[VAULT]/.claude/`. The `.claude/` namespace is reserved for Claude Code's own project config and would collide if a user invokes `claude` from inside the vault directory.

### 5.3 Skill Beziehung zu tag-suggest

Both skills read the same effective convention (plugin default + vault override merged at runtime). They are **loosely coupled**:
- tag-suggest documents "run tag-manage first if vault is messy" as a best-practice recommendation, not a hard dependency.
- Each skill writes its own findings file (`<date>-tag-manage.md`, `<date>-tag-suggest.md`).
- VOCAB extraction is independent in each skill — no shared cache.

## 6. Convention Schema

The convention is defined in YAML frontmatter of `references/tag-convention.md` (plugin default) and optionally `[VAULT]/_vault-autopilot/config/tag-convention.md` (vault override). Same schema, both files.

### 6.1 Schema (v1)

```yaml
---
schema: 1

# Casing rule for concept tags
casing: PascalCase                # PascalCase | kebab-case | lowercase | snake_case

# Hierarchy structure
hierarchy_separator: "/"          # "/" | "-" | none

# Forbidden patterns (regex, applied during Tier-3 detection)
forbidden_patterns:
  - "^#"                          # hash prefix
  - "^[0-9]+$"                    # numeric-only artifact
  - "^(created|modified|last_updated|updated|aliases|type):"  # YAML-leak artifact

# Canonical-mapping pins — explicit "this lowercase form maps to this canonical form."
# Plugin ships universally-applicable pins. Vault override extends with vault-specific pins.
# Brand handling: a brand is just a pin where `from == to.lower()` and `to` preserves the
# brand's official casing (e.g., {from: github, to: GitHub}). No separate `brands` field.
pins:
  - {from: github,    to: GitHub}
  - {from: chatgpt,   to: ChatGPT}
  - {from: linkedin,  to: LinkedIn}
  - {from: youtube,   to: YouTube}
  - {from: opensource, to: OpenSource}
  - {from: lowcode,    to: LowCode}
  # ... ~20 universal pins total

# Hierarchy prefixes used in vault (informational + Tier-3 detection hints)
hierarchy_prefixes:
  - {prefix: "Software/", purpose: "Commercial SaaS and software"}
  - {prefix: "OpenSource/", purpose: "Open-source projects"}
  - {prefix: "Protocol/", purpose: "Standards and protocols"}
  - {prefix: "Meta/",     purpose: "Vault management"}

# Folder-exclusive tag rules — RESERVED for v0.2.x. MVP does not enforce.
folder_exclusive: []
---
```

### 6.2 Merge Semantics

| Field | Type | Merge Rule |
|---|---|---|
| `schema` | int | Must match plugin (else error). Forward-compat is a future schema-version concern. |
| `casing` | scalar | Vault wins if defined |
| `hierarchy_separator` | scalar | Vault wins if defined |
| `forbidden_patterns` | list | Concat plugin + vault |
| `pins` | list | Concat. Vault wins on `from` collision. |
| `hierarchy_prefixes` | list | Concat. Vault wins on `prefix` collision. |
| `folder_exclusive` | list | Vault-only (plugin always empty). |

Merged result lives in memory only — never written back to disk.

### 6.3 Schema Validation

On skill startup:
1. Parse plugin default. If invalid → ship-blocker, fail loud.
2. If `[VAULT]/_vault-autopilot/config/tag-convention.md` exists, parse. If invalid → halt loud with file path + line number. Do **not** silently fall back to plugin-only.
3. After merge: validate effective convention. Casing valid? All `pins.to` conform to casing? Warn on inconsistencies (don't halt — user may intentionally pin against convention).

### 6.4 Bootstrap UX

If user runs `tag-manage` without `[VAULT]/_vault-autopilot/config/tag-convention.md`:
- Plugin defaults apply (PascalCase + universal brand pins).
- After audit completes, suggest scaffolding a vault-override:
  > "Found N tags that look vault-specific (Smartbroker, Tibber, ...). Consider creating `[VAULT]/_vault-autopilot/config/tag-convention.md` to pin these as canonical. Say 'generate vault-config' to scaffold a starter file."
- On user approval: skill writes a starter file based on detected vault-specific tags. User reviews + commits.

## 7. Workflow

### 7.1 Parameters

| Parameter | Default | Values |
|---|---|---|
| `scope` | `vault` | `inbox` / `inbox-tree` / `vault` / `folder:<path>` |
| `cooldown_days` | 3 | int — skip notes "created within last N days" per Source Hierarchy |
| `dry_run` | `false` | bool — audit + display, no apply |

**Default `scope: vault` rationale:** Tag inconsistencies cluster cross-folder. The skill's value is finding `Research` in `010_Outcomes/` colliding with `research` in `001_Inbox/`. Defaulting to `inbox` would miss the duplicate entirely. Cooldown_days, Production-Safety gate, and Bulk-Operation confirm provide the safety envelope.

### 7.2 Step Sequence

**Step 1 — Discover & Configure**
- Resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask user.
- Production-Safety gate if path differs from configured test vault (per CLAUDE.md).
- Pre-flight plugin state check (`grep -c obsidian-vault ~/.claude/plugins/installed_plugins.json`).
- Run `references/windows-preflight.md` (no-op on mac/linux).
- Read `references/tag-convention.md` (plugin default).
- If vault-override exists, parse + merge per §6.2.
- Confirm scope with user before scan.

**Step 2 — Scan**
- Walk scope using windows-preflight enumeration pattern.
- For each `.md` file:
  - Run `references/yaml-sanity.md` first. Verdicts:
    - `OK` / `OK_QUOTED` / `OK_NO_FRONTMATTER` → proceed
    - `BROKEN_KEYS_INSIDE_COLON` → skip, log finding, route to property-enrich (recipe f handles it)
    - `MULTIPLE_FRONTMATTER_BLOCKS` / `UNCLOSED_FRONTMATTER` → skip, log Class-A finding, route to note-rename
  - Extract YAML frontmatter line-by-line (per `yaml-edits.md` rules — no multi-line regex).
  - Apply cooldown: read `created` from YAML, fall back through Source Hierarchy (filename date → git first-commit → filesystem birthtime) per `docs/metadata-requirements.md`. If created < `cooldown_days` ago, skip.
- Build derived structures:
  - `tag → [(file, line)]` mapping
  - `tag → frequency` counts
  - `unique_tags` set
  - Summary: `total_notes`, `tagged_notes`, `untagged_notes`, `total_assignments`

**Step 3 — Detect (Tier 1+2+3, deterministic preprocessing)**

*Tier 1 — Case-Variants:*
```
groups_by_lower = group_by(unique_tags, key=lambda t: t.lower())
duplicate_groups_T1 = [g for g in groups_by_lower.values() if len(g) > 1]
```

*Tier 2 — Whitespace/Hyphen-Variants:*
```
def normalize(t): return t.lower().replace("-", "").replace(" ", "").replace("_", "")
groups_by_norm = group_by(unique_tags, key=normalize)
duplicate_groups_T2 = [g for g in groups_by_norm.values() if len(g) > 1 and not subset_of_T1]
```

*Tier 3 — Convention-Violations (no duplicate partner needed):*
- Run each `forbidden_patterns` regex against tag list
- Detect lowercase-concept (starts with `[a-z]` AND tag.lower() not in pins.from)
- Detect snake_case (contains `_` AND not pinned)
- Detect Upper-Kebab (matches `^[A-Z][a-z]+(-[A-Z][a-z]+)+$` AND not exempt: not `AI-`/`KI-` prefix, not in pinned brands like `Mercedes-Benz`, not `VfB-Stuttgart`-style)
- Detect trailing-comma / trailing-colon / trailing-quote artifacts (clipper-bug residues)

Output: `issue_list` = `duplicate_groups_T1` + `duplicate_groups_T2` + `violations_T3`, each entry tagged with severity and tier.

**Step 4 — Resolve (single AI prompt for canonical decisions)**

*Why one prompt, not per-group:* Cost (1 prompt vs N), consistency (AI sees all groups + full vault-vocab in one context), and reproducibility.

*Model + parameters (pinned for determinism per advisor):*
- Model: **claude-haiku-4** (or current Haiku revision)
- Temperature: **0**
- Prompt-template version: tracked in findings file as `prompt_template_version: "1.0"`

*Prompt skeleton:*
```
You are reconciling a vault's tag chaos to a clean canonical form.

EFFECTIVE CONVENTION (merged plugin-default + vault-override):
[paste effective convention YAML]

VAULT VOCABULARY (full unique tag list with frequencies):
[paste tag-frequency table]

DUPLICATE GROUPS (Tier 1 + 2):
[paste groups]

CONVENTION VIOLATIONS (Tier 3):
[paste list]

VAULT PINS (FIXED — do not propose alternatives, use these directly):
[paste pins.from → pins.to from effective convention]

For each group/violation, decide the canonical form and severity.
Output STRICT JSON:
{
  "recommendations": [
    {
      "id": int,
      "type": "rename" | "remove" | "merge",
      "current_tags": [str, ...],
      "canonical": str | null,    // null for remove
      "severity": "high" | "medium" | "low",
      "reason": str,
      "files_affected_count": int
    }
  ]
}
```

*Severity rules:*
- `high` — hash-prefix, YAML-leak artifact, numeric-only, trailing-quote/comma/colon
- `medium` — case dupe, lowercase-concept, snake_case, upper-kebab
- `low` — whitespace-variant only

*Pin handling:* Recommendations involving a tag whose lowercase form is in `pins.from` use `pins.to` directly — AI does not deviate from pinned canonical.

**Step 5 — Preview (chat + findings file)**

*Chat-display:* Numbered table grouped by severity, with `(pinned)` annotation for pinned canonicals.

```
HIGH (3 issues, 7 notes affected)
─────────────────────────────────
 # | Action  | Current        | Canonical | Notes |
 1 | remove  | "1"            | <REMOVE>  |    5  |
 2 | rename  | "#Websites"    | Websites  |    2  |
 3 | remove  | "created: ..."  | <REMOVE>  |    4  |

MEDIUM (5 issues, 41 notes affected)
─────────────────────────────────
 4 | merge   | devtools, Devtools, DevTools | DevTools (pinned) | 16 |
 5 | rename  | research                     | Research          |  8 |
 ...
```

*Findings-file write:* Append to `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-manage.md`:
- Audit timestamp, scope, counts
- `prompt_template_version`
- Full numbered recommendations
- Status: `audit-complete, awaiting-user-decision`

**Step 6 — User Gate**

```
Audit complete. 8 recommendations across 48 notes.
- "apply all"
- "apply 1-5" / "apply 1, 4, 7"
- "skip 6"
- "override 4 to MyOwnVersion"
- "apply nothing" (keep findings file, exit)
```

**Production-Safety confirm before write:**
> "I will rename N tags across M files in `[vault-name]`. Confirm?"

**Step 7 — Apply**

For each approved recommendation:
- `type: rename` → `references/yaml-edits.md` recipe **(g) tag-rename**
- `type: remove` → recipe **(h) tag-remove**
- Per file:
  - Pre-write read of YAML, compare to scanned state. If changed since scan → skip + log "concurrent modification" finding.
  - Pre-write log to findings file Changes section: `(file, line, before, after)`.
  - Execute recipe (line-by-line).
  - Birthtime preservation per `references/skill-log.md`.
  - Skill-log callout entry tagged `tag-manage`.

If apply fails mid-batch: halt. Findings file shows what was applied vs not. Re-run is safe (idempotent re-detection).

**Step 8 — Report**

Final chat-display:
```
tag-manage applied 6 of 8 recommendations.
- 47 file mutations across 38 notes
- 0 errors, 0 birthtime-restoration failures
- 2 recommendations skipped per your decision
- Findings-file: [VAULT]/_vault-autopilot/findings/2026-05-15-tag-manage.md
```

Findings-file final status: `apply-complete` with full Changes ledger.

## 8. yaml-edits.md Recipes (extensions)

### 8.1 Recipe (g) — tag-rename

**Input:** filepath, old_tag_text, new_tag_text
**Procedure:**
1. Read file line-by-line. Detect line ending (CRLF vs LF), preserve.
2. Find frontmatter open `---` and close `---` by full-line equality after `rstrip('\r\n')`.
3. Within frontmatter, find `tags:` key by full-line match (`^tags:\s*$` or `^tags:\s*\[\]\s*$` etc.).
4. Walk subsequent lines while line matches one of 4 forms:
   - `  - <tag>`
   - `  - "<tag>"`
   - `  * <tag>`
   - `  * "<tag>"`
5. For each matching line where the bare tag value equals `old_tag_text`: replace just the tag value, preserve indentation, marker (`-`/`*`), and quoting style.
6. Write back with original line ending.

**Idempotent:** running twice produces same result.

**Edge cases:**
- Trailing comma on tag value (`  - business,`): tolerate, treat as part of value, fix only if value-after-comma-stripping == old_tag_text. Strip comma during rename.
- Trailing colon (`  - publictags:`): per Step 3 it's flagged as artifact and resolved to canonical (often a remove).
- Trailing quote on hashtag (`  - #smartbroker"`): flagged as artifact, removed or renamed to canonical.
- Tags-block uses `tags: [a, b, c]` flow-style: skip with warning. MVP does not handle flow-style; document in skill body.

### 8.2 Recipe (h) — tag-remove

**Input:** filepath, tag_text
**Procedure:** same as (g), Steps 1-4. For matching line: delete it from line list.

**Empty-block handling:** If after deletion the tags-block has zero list-items, leave `tags:` key with empty list (`tags: []`) for compatibility. Do NOT remove the `tags:` key entirely (other tools may rely on its presence).

### 8.3 Recipe (i) — tag-add

Defined in [tag-suggest spec](./2026-05-06-tag-suggest-design.md). Not used by tag-manage.

## 9. Findings File Format

Path: `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-manage.md`

Append-only ledger per `references/findings-file.md`. Each run appends a section:

```markdown
## Run 2026-05-15 14:32:07 UTC

**Scope:** vault
**Cooldown:** 3 days
**Notes scanned:** 1247 (skipped 12 cooldown, 3 malformed)
**Tags found:** 312 unique, 4891 assignments
**Prompt template version:** 1.0
**Effective convention:** plugin-default + vault-override (sha: a3f...)

### Audit Recommendations

| # | Severity | Type   | Current        | Canonical | Notes affected | Reason |
| 1 | high     | remove | "1"            | —         | 5              | numeric-only artifact |
| 2 | high     | rename | "#Websites"    | Websites  | 2              | hash-prefix |
| ... |

### Changes Applied

| # | File | Line | Before | After |
| 1 | 001_Inbox/Note A.md | 7  | "1"         | <removed> |
| 1 | 001_Inbox/Note B.md | 9  | "1"         | <removed> |
| ... |

### Status: apply-complete

47 mutations / 38 files / 0 errors. 2 recommendations skipped per user decision.
```

## 10. Error Handling

| Edge Case | Behavior |
|---|---|
| YAML malformed (`MULTIPLE_FRONTMATTER_BLOCKS`, `UNCLOSED_FRONTMATTER`) | Skip file, Class-A finding, route to note-rename |
| YAML quoted-key cluster (`BROKEN_KEYS_INSIDE_COLON`) | Skip file, route to property-enrich |
| File unreadable | Skip, Class-B finding, continue |
| Tag in 4 different YAML formats in same file | Recipe (g)/(h) handles all 4 |
| Tag in body (inline `#tag`) | Out of scope. Document in skill body. |
| Birthtime-restoration fails | Non-blocking warning in findings |
| Vault-config YAML invalid | Halt loud with path + line. No silent fallback. |
| Pin conflicts with effective casing rule | Pin wins. Warning during validation. |
| File modified between scan and apply | Pre-write re-check. If changed: skip + log "concurrent modification". |
| Apply fails mid-batch | Halt. Findings shows applied vs not. |
| Recommendation references already-resolved tag | Pre-apply re-check. Skip with note. |
| `tags: []` empty list | Not an error. tag-manage ignores. |
| `tags: null` or `tags:` no value | Treat as empty list. |

**Reserved tags (skill always ignores):**
```
- VaultAutopilot
- VaultAutopilot/*
```

## 11. Out-of-Scope (Defer)

| Feature | Defer to | Reason |
|---|---|---|
| Tier 4 plural/singular dedupe | v0.3.0 | False-positive risk (intentional plural) |
| Tier 5 abbreviation dedupe | v0.3.0 | False-positive risk (`JS` may be intentional) |
| Tier 6 semantic-near-dupe | v0.3.0 | High AI variance, hard to validate |
| Hierarchy-analysis (`Software/DevTools` vs flat) | v0.2.x | Requires hierarchy decisions per vault |
| Folder-exclusive enforcement | v0.2.x | Schema field reserved, MVP no-op |
| Tag-Index file generation | v0.3.0+ | Separate skill `tag-index` |
| Master vault-wide summary report | v0.3.0+ | Cross-skill concern, not MVP |
| `tag-manage --reverse <findings>` mode | v0.2.x | Defer until real user need |
| Inline `#tag` in note body | never (scope decision) | Body content is out of skill domain |
| Flow-style tags (`tags: [a, b, c]`) | v0.2.x | Edge case, document workaround |

## 12. Testing Strategy

Three layers — see [Section F](#) of brainstorming notes for full detail.

### 12.1 Unit (bats)

| Surface | Coverage |
|---|---|
| Recipe (g) tag-rename | All 4 YAML formats, indentation preservation, idempotency |
| Recipe (h) tag-remove | All 4 formats, empty-block handling |
| Convention parser | Valid + invalid schemas; line-precise error messages |
| Convention merge | Plugin-only, vault-only-overrides, conflict resolution |
| Tier 1 detection | Group case-variants, do not group disjoint |
| Tier 2 detection | Normalize-then-group, do not over-merge |
| Tier 3 forbidden_patterns | Each regex hits + does not false-positive |
| Severity assignment | Maps per spec |
| Reserved tags | `VaultAutopilot` never proposed |

### 12.2 Integration (golden-output)

Curated chaos-vault fixture: ~10 files covering every Tier 1+2+3 case. Run audit + apply, diff against expected golden tarball.

### 12.3 Synthetic vault generator

`scripts/test-fixtures/generate-synthetic-vault.sh` — deterministic via seed. Produces:
- 100-2000 notes with realistic Zipfian tag-frequency distribution
- Controlled chaos injection (case-dupes, hyphen variants, hash-prefix, YAML-leak, numeric, lowercase, snake, upper-kebab)
- `_truth.json` sidecar listing every chaos seed: `{file, original_tag, expected_canonical, severity, tier}`
- Realistic Obsidian folder structure

Assertions:
- Detection completeness ≥ 95% vs `_truth.json`
- Detection precision: false-positive rate < 2%
- AI canonical match ≥ 90% vs truth (10% tolerance for AI judgment variance)
- Apply idempotency (re-run = 0 new recommendations)
- Performance: 2000-note vault scan < 10s, full audit-prompt < 30s
- Memory: no OOM on 2000-note vault

### 12.4 Cross-Platform (Cycle 4 GR pattern)

| GR | Topology | OS |
|---|---|---|
| GR-1 | nexus-original-from-M2 | macOS native |
| GR-2 | nexus-clone-powershell | Windows |
| GR-3 | nexus-clone-robocopy | Windows |
| GR-4 | M2 platinum-baseline | macOS native |

Pass criterion: **0 new Class-A skill-regressions** per Decision D19.

### 12.5 USER-PASS Gate

User runs against own production vault (Nexus), reviews recommendations, approves apply, verifies result. User pronounces PASS per "AI empfiehlt, Mensch entscheidet" (CLAUDE.md). Test cycles are NOT marked PASS by skill — only by user.

## 13. Build Sequence

### 13.1 Sequencing Constraint

**v0.1.4 must ship + public-flip must be done before v0.2.0 implementation begins.** Specs (this file + sibling) can be written now. Implementation waits.

### 13.2 Stages (post-public-flip)

**Stage 1 — Foundations (~2-3 days)**

| # | Deliverable | PR |
|---|---|---|
| T1 | Extend `references/tag-convention.md` with YAML schema | PR-1 |
| T2 | Create `references/vault-config.md` | PR-1 |
| T3 | Add yaml-edits.md recipes (g) + (h) with bats unit tests | PR-2 |
| T4 | Synthetic vault generator + curated fixtures | PR-3 |
| T4.5 | tag-manage SKILL.md *skeleton* (workflow shape only, no logic) | PR-3 — advisor's "cheap insurance" — validate recipe shapes against actual call sites before Stage 2 |

Exit-gate: bats green; synthetic generator deterministic; recipes idempotent.

**Stage 2 — Skill Logic (~3-4 days)**

| # | Deliverable | PR |
|---|---|---|
| T5 | Tier 1+2+3 detection logic | PR-4 |
| T6 | AI-resolution prompt + JSON parser (model: Haiku, temp: 0) | PR-5 |
| T7 | Apply integration: skill → recipes → birthtime → skill-log | PR-5 |
| T8 | Report format (chat + findings file) | PR-6 |
| T9 | Bootstrap UX (vault-config scaffolding) | PR-6 |

Exit-gate: full audit + apply on chaos-vault; idempotent re-run = 0 new recommendations.

**Stage 3 — Cross-Platform + Cycle (~1-2 days)**

| # | Deliverable |
|---|---|
| T10 | macOS run on chaos-vault + synthetic-small (100 notes) |
| T11 | Windows preflight integration on synthetic-stress (2000 notes) |
| T12 | Cycle-style 4 GRs |
| T13 | USER-PASS gate on Nexus |

**Stage 4 — Ship (~0.5 day)**

| # | Deliverable |
|---|---|
| T14 | Version bump 0.1.4 → 0.2.0 in `.claude-plugin/plugin.json` |
| T15 | `logs/changelog.md` entry |
| T16 | `CLAUDE.md` Skills-Tabelle: row #7 status `beta`; add row #8 `tag-suggest` deferred |
| T17 | Tag commit, push, merge to main |

**Total v0.2.0 effort:** ~7-9 days post-public-flip.

### 13.3 PR Strategy

6 smaller PRs (PR-1 through PR-6), each self-contained with tests. Foundations PRs reviewable before skill PRs.

## 14. Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| AI canonical resolution unstable across runs | Medium | Haiku + temp=0 + prompt-template-version. Vault pins absorb 5% drift. Tests assert ≥ 90% match to truth. |
| Synthetic generator complexity exceeds value | Low | Start with curated fixtures only (Layer 1). Defer generator if Stage 1 budget tight. |
| Recipe (g)/(h) edge cases missed | Medium | bats covers all 4 YAML formats explicitly + golden-output integration. |
| Windows enumeration regression on tag-write | Medium | Reuse `references/windows-preflight.md` battle-tested in v0.1.4 W1. |
| Production-vault accident | Critical | Explicit gates per §10. Test vault hardcoded for dev. Production-Safety confirm before bulk apply. |
| User confusion: plugin-default vs vault-override | Medium | Bootstrap UX scaffolds vault-config. Clear errors on config load fail. |
| Vault-config location conflicts with Claude Code's `.claude/` | Resolved | Located at `[VAULT]/_vault-autopilot/config/` — no collision. |

## 15. Success Criteria

The skill is shipped (v0.2.0 released) when all of the following are true:

1. ✅ All bats unit tests green on macOS + Linux + Windows (CI)
2. ✅ Curated chaos-vault integration test golden-output match
3. ✅ Synthetic-stress (2000 notes) passes performance + completeness assertions
4. ✅ 4 Gold Runs (mac native, win-powershell, win-robocopy, m2-platinum) — 0 new Class-A regressions
5. ✅ User pronounces PASS on own production vault (Nexus)
6. ✅ `references/tag-convention.md` extended; `references/vault-config.md` exists; `references/yaml-edits.md` has recipes (g) + (h) with tests
7. ✅ `CLAUDE.md` Skills-Tabelle reflects skill status `beta`
8. ✅ Plugin manifest version bumped, changelog entry, tag pushed

## 16. Open Items After Spec Approval

After this spec is approved, the next step is the **writing-plans** skill to produce an implementation plan. Plans break stages T1-T17 into atomic, TDD-driven tasks suitable for execution.

---

**End of tag-manage design spec.**
