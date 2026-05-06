# tag-suggest Design Spec (v0.2.x)

**Date:** 2026-05-06
**Status:** Design — awaiting user review
**Ship target:** v0.2.x (post-v0.2.0 ship of tag-manage)
**Authors:** Obi (Skill Master), reviewed by advisor()
**Primary spec:** [tag-manage design](./2026-05-06-tag-manage-design.md) — sibling skill v0.2.0, ships first

> **Read this spec alongside the tag-manage spec.** Architecture (§5), convention schema (§6), recipe conventions, findings-file pattern, error-handling philosophy, and build-sequence framework are defined in the primary spec. This spec covers the differential — what is tag-suggest specifically, and how it differs from tag-manage.

---

## 1. Purpose

`tag-suggest` is the v0.2.x sibling skill that finds **untagged** notes in an Obsidian vault and proposes tags based on note content + the vault's existing tag vocabulary. It applies approved suggestions only after explicit user gate.

Where tag-manage answers *"my tags are inconsistent — clean them up,"* tag-suggest answers *"my notes have no tags — fill them in."* Different jobs, different cost profiles, deliberately separate skills.

## 2. Background

A previous version exists in Claude Desktop (~400 lines, Python-driven, uses `_conventions/SKILL.md` cross-references that don't exist in this repo, hardcoded sandbox paths). It is a from-scratch rebuild for the same reasons enumerated in the tag-manage spec §2.

**This spec is a from-scratch rebuild that:**
- Reuses the tag-manage spec's architecture, conventions, and patterns where applicable
- Adds tag-suggest-specific behavior: content-aware analysis, cost-gated batch processing, vocabulary-first suggestion strategy

## 3. Differential vs tag-manage

| Aspect | tag-manage | tag-suggest |
|---|---|---|
| Operates on | YAML frontmatter only | YAML frontmatter + note body content |
| Job | Unify duplicate spellings, enforce convention | Suggest tags for untagged notes |
| Mutation type | rename / remove tags | add tags |
| Cost profile | Cheap, deterministic (regex + AI judgment in 1 prompt) | Expensive — LLM reads each note's body. ~$0.05 to ~$2 depending on scope |
| Default scope | `vault` (cross-folder is the point) | `inbox` (cost discipline) |
| Recipe used | `(g)` tag-rename + `(h)` tag-remove | `(i)` tag-add |
| Cost-estimate gate | Not needed | **Required** before any LLM call |
| Trigger phrases | "audit tags", "fix tags", "tag duplicates" | "suggest tags", "tag untagged notes", "auto-tag" |

## 4. User-facing Triggers

```yaml
description: |
  Use when notes in an Obsidian vault have no tags and need them suggested based on
  content. Analyzes note body, draws from the vault's existing tag vocabulary, proposes
  tags with confidence scoring, and applies only after explicit user approval.
  Trigger phrases: "suggest tags", "tag untagged notes", "auto-tag", "find untagged notes",
  "what tags should this note have", "fill in tags".
```

## 5. Architecture

### 5.1 Plugin Layout (additions to tag-manage's foundation)

```
obsidian-vault-autopilot/
├── skills/
│   └── tag-suggest/
│       └── SKILL.md                     [NEW v0.2.x]
├── references/
│   └── yaml-edits.md                    [EXTEND — add recipe (i) tag-add]
└── tests/
    ├── unit/tag-suggest/                [NEW — bats]
    ├── integration/tag-suggest/         [NEW]
    └── fixtures/curated/tag-suggest/    [NEW]
```

All other foundations (convention schema, vault-config location, findings-file pattern, windows-preflight, etc.) are inherited unchanged from tag-manage's spec.

### 5.2 Vault Layout

Same as tag-manage. Findings written to `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-suggest.md`.

### 5.3 Cross-skill Coupling

**Loose coupling.** Documented best-practice in skill body:
> "If your vault has duplicate-tag chaos, run `tag-manage` first. Otherwise the vocabulary tag-suggest draws from inherits the chaos, and suggestions will reproduce it."

No hard dependency. tag-suggest works on a vault with no `tag-manage` run history. The vocabulary is just messier.

## 6. Convention Schema

**Inherited unchanged from tag-manage spec §6.** Same plugin-default file, same vault-override file, same merge semantics. tag-suggest reads the same effective convention to ensure proposed tags conform.

## 7. Workflow

### 7.1 Parameters

| Parameter | Default | Values |
|---|---|---|
| `scope` | `inbox` | `inbox` / `inbox-tree` / `vault` / `folder:<path>` |
| `cooldown_days` | 3 | int — skip notes created within last N days |
| `batch_size` | 10 | int — notes per suggestion-pass (cost discipline) |
| `max_cost_usd` | 1.00 | float — hard cap; abort if estimate exceeds |
| `dry_run` | `false` | bool — suggest + display, no apply |

**Default `scope: inbox` rationale:** Untagged notes are most common in fresh captures (the inbox). Cost is non-trivial — bumping to vault-wide on first run could surprise the user with a $5+ bill. Inbox default is conservative; user explicitly opts into broader scope.

### 7.2 Step Sequence

**Step 1 — Discover & Configure**
Identical to tag-manage Step 1. Resolve vault, Production-Safety gate, windows-preflight, parse + merge effective convention.

**Step 2 — Scan (two passes)**

*Pass A — Untagged-Notes-List (within scope):*
- Walk scope using windows-preflight enumeration.
- For each `.md` file:
  - Run `references/yaml-sanity.md` first; same routing as tag-manage Step 2 for malformed/quoted-key cases.
  - Extract YAML frontmatter line-by-line.
  - Apply cooldown via Source Hierarchy (same as tag-manage).
  - If `tags:` is missing OR an empty array (`[]`) OR null, mark as untagged.
  - Capture body preview: first 800 chars after frontmatter close.
- Output: list of `(filepath, body_preview, frontmatter_state)` for untagged notes.

*Pass B — Vault-Vocabulary (entire vault, not just scope):*
- Walk full `${OBSIDIAN_VAULT_PATH}` regardless of skill scope.
- Extract `{tag → frequency}` for currently-tagged notes.
- Sort by frequency descending. Top ~150 tags become VOCAB context.

**Why VOCAB scope = vault, not skill-scope:** A user running tag-suggest on `inbox` wants suggestions to align with vocabulary already used in `vault/Work/`. Vocabulary inheritance is value-add — prevents tag-sprawl.

**Step 3 — Cost-Estimate Gate**

Before any LLM call:
```
Found 47 untagged notes in [scope_label].
Vocabulary: 312 unique tags from full vault.
Estimated suggestion-pass cost: ~$0.40 (Haiku, ~800 chars/note + 312-tag VOCAB context).
Continue? (yes / smaller batch / cancel)
```

If estimate > `max_cost_usd`: abort with explanation, recommend smaller scope or batch.

**Production-Safety confirm:** even at $0.05, confirm before LLM-spend.

**Cost calculation:**
- Per-batch input tokens ≈ (avg body chars × batch_size / 4) + (vocab table ≈ 1500 tokens) + (convention ≈ 500 tokens) + (system prompt ≈ 800 tokens)
- Per-batch output tokens ≈ batch_size × 150 (5 tag suggestions with metadata)
- Haiku price (current): $0.25/MTok input, $1.25/MTok output
- Estimate is conservative — actual usually runs 80-90% of estimate

**Step 4 — Suggest (per batch)**

*Model + parameters (pinned per advisor):*
- Model: **claude-haiku-4** (or current Haiku)
- Temperature: **0**
- Prompt-template version: tracked in findings as `prompt_template_version: "1.0"`

*Per batch of `batch_size` notes:*

Prompt skeleton:
```
You are tagging untagged notes in an Obsidian vault.

EFFECTIVE CONVENTION:
[paste merged convention YAML]

VAULT VOCABULARY (existing tags with frequencies — PREFER these over new tags):
[paste sorted top ~150 tags with freq counts]

VAULT PINS (canonical forms — never deviate):
[paste pins from effective convention]

NOTES TO TAG:
[Note 1: filepath, filename, body_preview_800_chars]
[Note 2: ...]
...

For each note: propose 1-5 tags. Maximum 3 with confidence=confident.
- "confident" = tag is in VOCABULARY AND clearly matches body
- "tentative" = new tag (not in VOCAB) OR body is sparse/ambiguous

Constraints:
- Suggested tags MUST conform to the convention. Self-correct non-conformant
  proposals BEFORE outputting (e.g., "devtools" → "DevTools").
- Never suggest "#"-prefixed tags.
- Never suggest case-variants of existing VOCAB entries — use the canonical form
  from VOCAB.
- For brand names: check VOCAB first; if brand not in VOCAB, use the casing from
  pins; if not in pins, use official brand casing.

Output STRICT JSON:
{
  "results": [
    {
      "note_id": int,
      "skipped": bool,
      "skip_reason": str | null,
      "suggestions": [
        {
          "tag": str,
          "confidence": "confident" | "tentative",
          "reason": str,
          "in_vocab": bool,
          "vocab_freq": int | null
        }
      ]
    }
  ]
}
```

*Sparse-content skip:* Notes with body < 50 chars marked `skipped: insufficient_content` BEFORE prompt assembly (don't waste tokens on un-analyzable content).

*Wikilinks-only content:* If body is `[[Foo]] [[Bar]]` repeating, mark suggestions as `tentative` since semantic context is thin. Wikilink targets are valid signals, but require user confirmation.

**Step 5 — Preview (per batch)**

*Chat-display* groups notes by primary folder for readability:

```
─── Batch 1 of 5 ─── 10 notes ───────────────────────

📄 2026-04-12 OGC Marketing Sync.md
   📁 001_Inbox/
   ✓ confident:  Meeting (vocab 33×) — explicit Sync agenda
   ✓ confident:  OGC (vocab 18×) — primary entity discussed
   ~ tentative: Q2-Planning — new tag, body mentions Q2 plans

📄 Trading Strategy Notes.md
   📁 001_Inbox/
   ✓ confident:  Trading (vocab 12×) — main topic
   ✓ confident:  ETF (vocab 24×) — explicit ETF strategy
   ~ tentative: RiskManagement — new tag, body discusses risk

[8 more notes...]
```

*Findings-file append* to `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-suggest.md` per batch — see §9.

**Step 6 — User Gate (per batch)**

```
Batch 1 of 5: 10 notes, 28 suggestions (18 confident, 10 tentative).

- "alle confident"           → apply only confident tags
- "alles"                    → apply all
- "per Note"                 → walk each note individually
- "skip <note-id>"           → drop a specific note's suggestions
- "override <note> <tag>"    → replace a suggestion with user-chosen tag
- "next batch"               → skip this batch, continue to batch 2
- "stop"                     → halt, no more batches
```

After approval, repeat for batches 2..N. After each batch, recalculate remaining cost estimate; if approaching `max_cost_usd * 0.8`, prompt user explicitly.

**Step 7 — Apply**

For each approved suggestion:
- Pre-write read of YAML, compare to scanned state. If user manually added a tag between scan + apply, deduplicate silently.
- Call `references/yaml-edits.md` recipe **(i) tag-add**.
- If note has frontmatter but no `tags:` key → recipe (i) inserts a `tags:` block in canonical position (after `title`, before any custom keys).
- If note has no frontmatter at all → create minimal frontmatter with only `tags:` block. Do NOT invent other fields (`title`, `created` — that's property-enrich's job).
- Pre-write log to findings Changes section: `(file, tag_added, source: vocab|new, confidence)`.
- Post-write: birthtime preservation, skill-log callout tagged `tag-suggest`.

**Step 8 — Report**

Final chat-display:
```
tag-suggest applied tags to 38 of 47 notes.
- 89 tags added (52 from existing vocab, 37 new vocabulary entries)
- 6 notes skipped (sparse content)
- 3 notes skipped per your decision
- Estimated cost: $0.40 / Actual cost: $0.38
- New vocabulary entries (consider pinning in vault-config):
    Q2-Planning, RiskManagement, ContentStrategy, ...
- Findings-file: [VAULT]/_vault-autopilot/findings/2026-05-16-tag-suggest.md
```

The "consider pinning" hint surfaces new tags so the user can decide whether to formalize them in `[VAULT]/_vault-autopilot/config/tag-convention.md`.

## 8. yaml-edits.md Recipe (i) — tag-add

**Input:** filepath, list of tags to add (canonicalized per convention)

**Procedure:**
1. Read file line-by-line. Detect line ending, preserve.
2. Find frontmatter open `---`. If absent → create minimal frontmatter at file start: `---\ntags:\n  - <tag1>\n  - <tag2>\n---\n\n` followed by original content.
3. If frontmatter exists, find close `---` by full-line equality.
4. Search for `tags:` key within frontmatter.
   - If `tags:` exists with list-form (one item per line):
     - Walk subsequent lines while line matches `  - <tag>` / `  - "<tag>"` / `  * <tag>` / `  * "<tag>"`.
     - Track existing-tags set for dedupe.
     - At end of tags-block, insert new tag lines (one per tag in input list, dedupe against existing).
     - Preserve marker style (`-` vs `*`) and quoting style of existing items. If mixed: use `-` unquoted for new entries.
   - If `tags:` exists with empty list (`tags:` on its own or `tags: []`):
     - Replace with proper list form, add new tags.
   - If `tags:` exists with flow-style (`tags: [a, b, c]`):
     - **Skip with warning.** MVP does not handle flow-style. Log finding "flow-style tags-block, skipped".
   - If `tags:` does not exist at all:
     - Insert `tags:` block at canonical position: after `title:` if present, otherwise after schema/identification keys, otherwise at end of frontmatter.
5. Write back with original line ending.

**Idempotent:** running twice with same input list adds tags only once (dedupe).

**Edge cases:**
- Frontmatter exists but is malformed → caller (skill Step 7) should have routed away in Step 2 sanity check. Recipe assumes valid frontmatter.
- Body starts with `---` (e.g., a Markdown horizontal rule on line 1 with no frontmatter): if no `---` is found within first 50 lines that closes a frontmatter, treat as no-frontmatter case. (Unusual edge case, document.)

## 9. Findings File Format

Path: `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-suggest.md`

Per-run section, append-only:

```markdown
## Run 2026-05-16 09:14:22 UTC

**Scope:** inbox
**Cooldown:** 3 days
**Untagged notes found:** 47 (skipped 6 sparse-content)
**Vault vocabulary:** 312 tags
**Prompt template version:** 1.0
**Cost estimate / actual:** $0.40 / $0.38

### Suggestions (Batch 1 of 5)

| Note | Tag | Confidence | In VOCAB | Reason |
| 001_Inbox/Note A.md | Meeting | confident | yes (33×) | explicit Sync agenda |
| 001_Inbox/Note A.md | OGC | confident | yes (18×) | primary entity |
| 001_Inbox/Note A.md | Q2-Planning | tentative | no | body mentions Q2 |
| ... |

### Tags Applied

| Note | Tags Added | Source |
| 001_Inbox/Note A.md | Meeting, OGC, Q2-Planning | vocab×2 + new×1 |
| ... |

### Skipped

| Note | Reason |
| 001_Inbox/Sparse.md | insufficient_content (28 chars body) |
| ... |

### New Vocabulary Entries

| Tag | Notes Tagged With It |
| Q2-Planning | 3 |
| RiskManagement | 2 |
| ... |

### Status: apply-complete

89 tags / 38 files / 0 errors. 6 sparse-content skipped, 3 user-skipped.
```

## 10. Error Handling

Inherits all error-handling from tag-manage spec §10 where applicable. tag-suggest specific:

| Edge Case | Behavior |
|---|---|
| Sparse content (<50 chars body) | Skip, mark `insufficient_content`, report |
| Wikilinks-only content (`[[Foo]] [[Bar]]` only) | Process, but mark all suggestions tentative |
| LLM proposes non-conformant tag | Skill self-corrects via effective convention BEFORE display. Discrepancy logged in findings (helps observe LLM-drift). |
| LLM proposes folder-exclusive tag for wrong folder | MVP: don't enforce (folder-exclusive schema field reserved). v0.2.x+: filter from prompt's allowed-suggestions. |
| LLM proposes hallucinated tag | User Gate catches. Skill does not validate semantic plausibility. |
| Cost estimate proves wrong | Recalc per-batch. Prompt user if approaching cap. |
| LLM returns malformed JSON | Retry once with stricter prompt. If second fails: halt batch, clear error. |
| Network/API failure mid-batch | Halt. Findings shows applied-so-far. Re-run is safe (only-untagged-notes filter). |
| Note has weird frontmatter (tags as nested map) | Skip, Class-A finding "non-standard tags structure" |
| All notes in batch sparse/skipped | Skip batch silently, advance to next |
| User has 0 tags in vault (empty vocabulary) | Warn upfront: "No existing vocabulary — every suggestion is new. Consider running tag-manage or curating manually first." |
| Note has frontmatter, no `tags:` key | Recipe (i) creates one in canonical position |
| Note has no frontmatter at all | Recipe (i) creates minimal frontmatter with only `tags:` block |

## 11. Out-of-Scope (Defer)

| Feature | Defer to | Reason |
|---|---|---|
| Folder-exclusive enforcement | v0.3.0 | Schema reserved, MVP no-op. Same as tag-manage. |
| Wikilink-based tag inference (`[[McFit]]` → `McFit` tag) | v0.3.0 | Old skill mentioned, defer until real signal |
| Cross-batch deduplication of new-vocabulary entries | never | Emerges naturally from VOCAB-priority on next run |
| Tag-Index file generation | v0.3.0+ | Separate skill |
| Multi-language tag detection (translate German → English canonicals) | v0.3.0+ | Convention is per-vault; some users want German tags |
| Auto-apply confident tags without user gate | never | Violates "AI empfiehlt, Mensch entscheidet" |
| Flow-style tags (`tags: [a, b]`) handling | v0.3.0+ | Edge case, document workaround |

## 12. Testing Strategy

Same three-layer framework as tag-manage spec §12.

### 12.1 Unit (bats)

| Surface | Coverage |
|---|---|
| Recipe (i) tag-add | Existing tags-block, no tags-block, no frontmatter, all 4 marker/quote forms |
| VOCAB extraction | Full vault walk, frequency counts, ignores reserved tags, handles malformed YAML (skip + log) |
| Cost estimator | Token calculation per scope; abort when exceeds `max_cost_usd` |
| Sparse-content filter | <50 chars skipped; wikilinks-only marked tentative |
| LLM-output JSON parser | Strict shape validation; retry-once on malformed |
| Convention self-correction | Non-conformant LLM output transformed to canonical before display |

### 12.2 Integration (golden-output)

Curated untagged-vault fixture: ~10 notes, mix of clear-topic / sparse / wikilinks-only / no-frontmatter. Run suggest + apply, diff against golden tarball.

### 12.3 Synthetic vault generator (extended from tag-manage)

`scripts/test-fixtures/generate-synthetic-vault.sh` extended with `--inject-untagged <ratio>` flag. Produces:
- N notes total
- M of them deliberately untagged (specified ratio)
- Each untagged note has body content drawn from a domain-tagged template pool — so ground-truth "expected tags" can be asserted

`_truth.json` extends with: `{file, expected_tags: [...], domain: "Trading|Research|Personal|..."}`.

Assertions:
- Vocabulary inheritance: ≥ 70% of suggestions for clear-domain notes match the domain's expected tags
- Cost estimate accuracy: actual within ±20% of estimate
- Apply idempotency (re-run = 0 new untagged notes since all were just tagged)
- Performance: 100-untagged-note batch completes in < 30s
- Convention self-correction: 0 non-conformant tags reach the apply phase

### 12.4 Cross-Platform

Same 4 GR pattern as tag-manage. Synthetic untagged-vault on each topology. Pass criterion: 0 new Class-A regressions.

### 12.5 USER-PASS Gate

User runs against own production vault (Nexus) untagged subset, reviews suggestions per batch, approves selectively, verifies result. User pronounces PASS.

## 13. Build Sequence

### 13.1 Sequencing Constraint

**v0.2.0 must ship + USER-PASS pronounced before v0.2.x implementation begins.** This spec can be written now (in parallel with tag-manage spec). Implementation waits on tag-manage shipping.

### 13.2 Stages (post-v0.2.0-ship)

**Stage 1 — Recipe (i) (~0.5 day)**

| # | Deliverable | PR |
|---|---|---|
| S1 | Add yaml-edits.md recipe (i) tag-add with bats unit tests | PR-A |

**Stage 2 — Skill Logic (~3-4 days)**

| # | Deliverable | PR |
|---|---|---|
| S2 | tag-suggest SKILL.md skeleton + Discovery + Scope | PR-B |
| S3 | VOCAB extraction logic (vault-wide, frequency-weighted) | PR-B |
| S4 | Cost-estimate gate + batch-loop control flow | PR-B |
| S5 | LLM suggestion prompt + JSON parser + convention self-correction | PR-C |
| S6 | Approval workflow (alle confident / alles / per-note / overrides) | PR-C |
| S7 | Apply integration via recipe (i) + report + new-vocab hint | PR-C |

Exit-gate: full suggest + apply on curated untagged-vault; idempotent re-run = 0 new untagged.

**Stage 3 — Cross-Platform + Cycle (~1 day)**

| # | Deliverable |
|---|---|
| S8 | 4 GRs against synthetic untagged-vault + Nexus production subset |
| S9 | USER-PASS gate |

**Stage 4 — Ship (~0.5 day)**

| # | Deliverable |
|---|---|
| S10 | Version bump 0.2.0 → 0.2.1 (or 0.3.0 if other features bundle) |
| S11 | `logs/changelog.md` entry |
| S12 | `CLAUDE.md` Skills-Tabelle row #8 status `beta` |
| S13 | Tag commit, push, merge to main |

**Total v0.2.x effort:** ~5-6 days post-v0.2.0-ship.

### 13.3 PR Strategy

3 smaller PRs (PR-A through PR-C). Foundation PR (recipe + tests) reviewable before skill PRs.

## 14. Risk Register

Inherits relevant risks from tag-manage spec §14. tag-suggest specific:

| Risk | Likelihood | Mitigation |
|---|---|---|
| Cost surprise (user runs on full vault, gets $5+ bill) | Medium | Default scope `inbox`. `max_cost_usd: 1.00` cap. Pre-run cost estimate gate. Per-batch recalc. |
| LLM hallucinates implausible tags | Medium | User Gate catches. Confidence labels make suspicious suggestions visible. |
| Tag-sprawl (many new vocabulary entries per run) | Medium | Vocabulary-first prompt strategy biases toward existing tags. New-vocab hint at end of run surfaces them for user review. |
| AI proposes non-conformant tags | High initially | Skill self-corrects BEFORE display. Discrepancy logged for observability. |
| Sparse content yields low-value tags | Medium | <50 char skip threshold. Wikilinks-only → tentative-only. |
| User confused about confident vs tentative | Low | Two-bucket scheme (not three) keeps decision simple. |

## 15. Success Criteria

The skill is shipped (v0.2.x released) when:

1. ✅ All bats unit tests green on macOS + Linux + Windows (CI)
2. ✅ Curated untagged-vault integration test golden-output match
3. ✅ Synthetic vault assertions pass (vocabulary inheritance ≥ 70%, cost ±20%, etc.)
4. ✅ 4 Gold Runs — 0 new Class-A regressions
5. ✅ User pronounces PASS on own production vault subset
6. ✅ `references/yaml-edits.md` has recipe (i) with tests
7. ✅ `CLAUDE.md` Skills-Tabelle reflects skill status `beta`
8. ✅ Plugin manifest version bumped, changelog entry, tag pushed

## 16. Open Items After Spec Approval

Same as tag-manage spec — next step is the **writing-plans** skill to produce an implementation plan when the time comes (post-v0.2.0-ship).

---

**End of tag-suggest design spec.**
