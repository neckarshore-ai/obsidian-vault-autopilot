# v0.1.4 W4 — recipe-(f) Duplicate-Key Resolution Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace recipe-(f)'s silent "first wins" duplicate-key dedup with a divergent-value-aware policy: when duplicate keys hold identical values, dedup silently (current behavior, Class-D); when they hold divergent values, ABORT the repair, leave the file unchanged, log a Class-A finding, and surface a new sanity-check verdict `DUPLICATE_KEYS_DIVERGENT_VALUES`. Closes F7 (`status: ready-for-designer` overwritten by `status: draft` on `neckarshore.ai brand style guide brief.md`, GR-3 Cell 1, 2026-05-01).

**Architecture:** Three contract surfaces touched in one PR-Welle. (1) `references/yaml-edits.md` recipe-(f) Step 3 branches on value-comparison; pre-write computation only writes when no divergent collisions exist. (2) `references/yaml-sanity.md` adds a new pattern + verdict (`DUPLICATE_KEYS_DIVERGENT_VALUES`) so sanity-check can detect both inside-colon-collision-divergent AND pre-existing plain-duplicate-divergent cases; updates verdict-priority ladder + per-skill routing matrix; amends idempotency-contract to acknowledge the abort path. (3) Four launch-scope SKILL.md files (`property-enrich`, `note-rename`, `inbox-sort`, `property-describe`) get a new routing branch handling the new verdict (skip + Class-A finding). Test fixture is 5-cell decision matrix; assertion harness mirrors W2's `test-clone-cluster.sh` pattern (6 sections, grep-uniqueness enforced).

**Tech Stack:** Markdown spec-docs (yaml-edits.md, yaml-sanity.md, 4× SKILL.md), bash assertion harness, JSON truth-table fixture, gitignored fixture notes (committed directly — no filesystem-time dependency unlike W2).

**Empirical anchor:** F7 case from GR-3 Cell 1 (2026-05-01, report `2026-05-04-obi-skills.md`): file `neckarshore.ai brand style guide brief.md` had two `status:` keys (one inside-colon-quoted `"status:": draft` and one plain `status: ready-for-designer`). Recipe-f normalized the inside-colon to plain, then dedup-step kept the first (`draft`), discarded the second (`ready-for-designer`). User intent was the LATER value (manual lifecycle update); silent loss reclassified by Obi from skill's Class-D → Class-B-Candidate (semantic-shift). MASCHIN-recommendation in `omnopsis-planning/docs/plans/vault-autopilot-v0.1.4-ship.md` § 3 W4: option (c) "always log + ask user when values differ."

**Cross-references:**
- Ship-plan: `omnopsis-planning/docs/plans/vault-autopilot-v0.1.4-ship.md` § 3 W4
- Backlog item: `omnopsis-planning/docs/reports/2026-05-04-obi-skills.md` `backlog_items` "F7 recipe-f duplicate-key resolution policy spec-clarification"
- Predecessor pattern: W2 plan `docs/superpowers/plans/2026-05-07-w2-clone-cluster-unification.md` (5-cell-fixture, grep-uniqueness, plan-as-implementer-prompt)
- Recipe-f current state: `references/yaml-edits.md` § "Recipe (f) — Normalize inside-colon quoted-keys (F26 repair)" lines 234-311
- Sanity-check current state: `references/yaml-sanity.md` § "Verdicts" + § "Per-skill policy" + § "Idempotency"

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `references/yaml-edits.md` | Modify | Recipe-(f) Step 3 branching logic + replace existing divergent worked example + add new identical worked example |
| `references/yaml-sanity.md` | Modify | New verdict `DUPLICATE_KEYS_DIVERGENT_VALUES` + Pattern 5 detection + verdict-priority update + per-skill routing matrix new column + idempotency contract amendment |
| `skills/property-enrich/SKILL.md` | Modify | Step 2a routing: new verdict → skip + Class-A finding |
| `skills/note-rename/SKILL.md` | Modify | Step 4a routing: new verdict → skip + Class-A finding |
| `skills/inbox-sort/SKILL.md` | Modify | Step 5a routing: new verdict → skip + Class-A finding |
| `skills/property-describe/SKILL.md` | Modify | Step 2a routing: new verdict → skip + Class-A finding |
| `tests/fixtures/recipe-f-duplicate-keys/notes/` | Create | 5 markdown fixture files (committed directly, NOT gitignored — content is the test) |
| `tests/fixtures/recipe-f-duplicate-keys/_truth.json` | Create | Per-file expected verdicts + expected actions + finding-class assertions |
| `tests/fixtures/recipe-f-duplicate-keys/README.md` | Create | Population table + design rationale |
| `scripts/test-recipe-f-duplicate-keys.sh` | Create | 6-section assertion harness (fixture structure + decision matrix + spec-doc anchors + sanity-doc anchors + 4 SKILL.md cross-refs + grep-uniqueness) |
| `logs/changelog.md` | Modify | Add v0.1.4 W4 component row |

**File-decomposition rationale:** Spec-changes live in `references/` (matches W2's `references/clone-cluster-detection.md` pattern). Fixture is 5 small markdown files committed directly (no `touch -t` filesystem-time dependency unlike W2). Assertion harness is a single bash script, sectioned for incremental green-up across T7–T10. SKILL.md edits are mechanical Edit-tool replacements with verbatim old_string + new_string drafted in the plan (plan-as-implementer-prompt — proven in W2 to scale at ~3-4 min per task).

---

## Architecture Notes

### Verdict design — "new verdict" vs "exception clause"

Two viable approaches:

| Option | Shape | Pro | Contra |
|---|---|---|---|
| (1) New verdict `DUPLICATE_KEYS_DIVERGENT_VALUES` | Add row to verdicts table; new pattern walk; new column in per-skill policy matrix | Symmetric with `MULTIPLE_FRONTMATTER_BLOCKS` (also a "skill skips, route to user" verdict); fits existing tabular contract; fixpoint contract restated cleanly | More surface (new pattern + new verdict + 4 SKILL.md routing entries) |
| (2) Exception clause inside `BROKEN_KEYS_INSIDE_COLON` flow | Recipe-f returns "DIVERGENT" out-of-band signal; sanity-check still returns `BROKEN_KEYS_INSIDE_COLON`; idempotency contract gets a "unless divergent values" exception | Smaller surface — no new verdict | Drift surface — exception clause buried in idempotency prose; future readers will miss it; per-skill matrix doesn't show the case |

**Decision: Option (1) — new verdict.** Rationale:
- The verdicts table is the canonical contract; adding a row fits the established mental model.
- Per-skill routing matrix becomes complete (every operationally-distinct case has a column).
- "Pick one and propagate" — the advisor flagged exception-clauses as drift-surface; matches W2's experience where verbatim spec text is load-bearing.
- The grep-uniqueness assertion in T11 enforces single-source-of-truth for the new verdict name.

### Severity classification — Class-A operationally

The new finding follows the same operational pattern as `MULTIPLE_FRONTMATTER_BLOCKS`:
- File is NOT modified (skill skips).
- User must manually decide (ambiguous metadata cannot be auto-resolved without semantic loss).
- Routes through the same fan-out (skill report → user / note-rename, depending on caller).

Therefore: **Class-A** ("Data loss or corruption detected. The user must act."), with the following nuance documented in `references/findings-file.md` (left unmodified — Class-A definition already covers "ambiguous metadata that the skill refused to resolve to prevent silent value-loss" by interpretation): the finding category is `duplicate-key-divergent-values` to distinguish from corruption-class Class-A.

### Recipe-(f) execution semantics — compute first, conditionally write

Current Step 3 is destructive: walks frontmatter, deletes duplicates, writes back. New Step 3 must be:

1. Compute post-normalize line list (in-memory, no write yet).
2. Walk computed list for collisions.
3. Branch:
   - **No collisions:** write back normalized form (current happy path).
   - **All collisions identical-value:** dedup silently, write back, log Class-D per collision.
   - **Any collision divergent-value:** ABORT — do not write back, leave file unchanged on disk, return new "DIVERGENT" signal to caller, log Class-A per divergent collision.

This preserves YAML validity in all paths: silent dedup writes valid YAML; abort leaves the original file unchanged (which was either valid YAML with quoted-key + plain-key, OR was already broken — either way, recipe-f did NOT make it worse).

---

## Tasks

### Task 1: Create fixture structure + 5-cell markdown files + truth-table

**Files:**
- Create: `tests/fixtures/recipe-f-duplicate-keys/notes/cell-A-divergent-inside-colon.md`
- Create: `tests/fixtures/recipe-f-duplicate-keys/notes/cell-B-identical-inside-colon.md`
- Create: `tests/fixtures/recipe-f-duplicate-keys/notes/cell-C-divergent-plain.md`
- Create: `tests/fixtures/recipe-f-duplicate-keys/notes/cell-D-identical-plain.md`
- Create: `tests/fixtures/recipe-f-duplicate-keys/notes/cell-E-control-no-duplicates.md`
- Create: `tests/fixtures/recipe-f-duplicate-keys/_truth.json`
- Create: `tests/fixtures/recipe-f-duplicate-keys/README.md`

- [ ] **Step 1: Create fixture directory and 5 markdown files**

```bash
mkdir -p tests/fixtures/recipe-f-duplicate-keys/notes
```

`tests/fixtures/recipe-f-duplicate-keys/notes/cell-A-divergent-inside-colon.md`:

```markdown
---
"status:": draft
status: ready-for-designer
title: F7 case — divergent values across inside-colon and plain forms
---

# Cell A — Divergent values, inside-colon collision (F7 case)

This file mirrors the empirical F7 finding from GR-3 Cell 1 (2026-05-01).
Two `status:` keys: one inside-colon-quoted (shape β, normalizable to plain),
one already plain. Their values differ (`draft` vs `ready-for-designer`).

Expected behavior under v0.1.4 W4 policy:
- Sanity-check returns `DUPLICATE_KEYS_DIVERGENT_VALUES` (new verdict).
- Recipe-f, if invoked, ABORTS: file is left unchanged on disk.
- Skill caller skips file with Class-A finding.
```

`tests/fixtures/recipe-f-duplicate-keys/notes/cell-B-identical-inside-colon.md`:

```markdown
---
"created:": 2024-03-14
created: 2024-03-14
title: Identical values across inside-colon and plain forms
---

# Cell B — Identical values, inside-colon collision

Two `created:` keys: one inside-colon-quoted (shape β), one plain.
Values are identical (`2024-03-14`). Safe to dedup silently.

Expected behavior under v0.1.4 W4 policy:
- Sanity-check returns `BROKEN_KEYS_INSIDE_COLON` (existing verdict — inside-colon shape present).
- Recipe-f normalizes shape β → plain, finds identical-value collision, dedups (keep first), logs Class-D.
- Re-sanity-check returns `OK`. Skill proceeds.
```

`tests/fixtures/recipe-f-duplicate-keys/notes/cell-C-divergent-plain.md`:

```markdown
---
status: draft
status: ready-for-designer
title: Divergent values across two plain keys (no inside-colon)
---

# Cell C — Divergent values, pre-existing plain duplicates

Two plain `status:` keys, no inside-colon shape anywhere. Values differ.
This case was NOT covered by recipe-f pre-W4 (only triggered on shape β).
v0.1.4 W4 extends sanity-check to detect plain-key duplicates universally.

Expected behavior under v0.1.4 W4 policy:
- Sanity-check returns `DUPLICATE_KEYS_DIVERGENT_VALUES` (new verdict — divergent plain duplicates).
- Recipe-f, if invoked, ABORTS: file unchanged.
- Skill caller skips file with Class-A finding.
```

`tests/fixtures/recipe-f-duplicate-keys/notes/cell-D-identical-plain.md`:

```markdown
---
modified: 2024-06-15
modified: 2024-06-15
title: Identical values across two plain keys (no inside-colon)
---

# Cell D — Identical values, pre-existing plain duplicates

Two plain `modified:` keys, no inside-colon. Identical values.
Pre-W4: sanity-check returned OK (didn't look at duplicates), file stayed
broken (technically invalid YAML) but skills processed it as if first-wins.
W4: sanity-check detects + recipe-f silently dedups + Class-D log.

Expected behavior under v0.1.4 W4 policy:
- Sanity-check returns `DUPLICATE_KEYS_IDENTICAL_VALUES` (extended pattern, identical sub-case).
- Recipe-f dedups silently (keep first), logs Class-D.
- Re-sanity-check returns `OK`. Skill proceeds.
```

`tests/fixtures/recipe-f-duplicate-keys/notes/cell-E-control-no-duplicates.md`:

```markdown
---
created: 2024-08-01
modified: 2024-09-15
status: published
title: Control file — well-formed, no duplicates
---

# Cell E — Control (no duplicates, no inside-colon)

Standard well-formed frontmatter. No anomalies.

Expected behavior under v0.1.4 W4 policy:
- Sanity-check returns `OK`.
- Recipe-f not invoked.
- Skill proceeds normally.
```

- [ ] **Step 2: Create `_truth.json` with expected verdicts**

```json
{
  "$schema": "v0.1.4-w4-recipe-f-duplicate-keys-fixture-truth-v1",
  "fixture_purpose": "5-cell decision matrix for recipe-(f) duplicate-key resolution policy. Maps each fixture file to its expected sanity-check verdict, recipe-f action, finding class, and post-condition.",
  "policy_anchor": "v0.1.4 W4 — Option (c) per omnopsis-planning ship-plan §3 W4: always log + ask user when values differ.",
  "cells": [
    {
      "file": "cell-A-divergent-inside-colon.md",
      "scenario": "Inside-colon shape β with divergent value vs pre-existing plain key (F7 empirical case)",
      "sanity_verdict_pre": "DUPLICATE_KEYS_DIVERGENT_VALUES",
      "recipe_f_action": "ABORT_NO_WRITE",
      "finding_class": "A",
      "finding_category": "duplicate-key-divergent-values",
      "post_file_state": "unchanged",
      "sanity_verdict_post": "DUPLICATE_KEYS_DIVERGENT_VALUES",
      "skill_action": "skip + route to user / note-rename"
    },
    {
      "file": "cell-B-identical-inside-colon.md",
      "scenario": "Inside-colon shape β with identical value vs pre-existing plain key",
      "sanity_verdict_pre": "BROKEN_KEYS_INSIDE_COLON",
      "recipe_f_action": "NORMALIZE_AND_DEDUP_SILENT",
      "finding_class": "D",
      "finding_category": "duplicate-key-removed-identical",
      "post_file_state": "modified — shape-β normalized + duplicate removed",
      "sanity_verdict_post": "OK",
      "skill_action": "proceed"
    },
    {
      "file": "cell-C-divergent-plain.md",
      "scenario": "Two pre-existing plain duplicates with divergent values, no inside-colon",
      "sanity_verdict_pre": "DUPLICATE_KEYS_DIVERGENT_VALUES",
      "recipe_f_action": "ABORT_NO_WRITE",
      "finding_class": "A",
      "finding_category": "duplicate-key-divergent-values",
      "post_file_state": "unchanged",
      "sanity_verdict_post": "DUPLICATE_KEYS_DIVERGENT_VALUES",
      "skill_action": "skip + route to user / note-rename"
    },
    {
      "file": "cell-D-identical-plain.md",
      "scenario": "Two pre-existing plain duplicates with identical values, no inside-colon",
      "sanity_verdict_pre": "DUPLICATE_KEYS_IDENTICAL_VALUES",
      "recipe_f_action": "DEDUP_SILENT",
      "finding_class": "D",
      "finding_category": "duplicate-key-removed-identical",
      "post_file_state": "modified — duplicate removed",
      "sanity_verdict_post": "OK",
      "skill_action": "proceed"
    },
    {
      "file": "cell-E-control-no-duplicates.md",
      "scenario": "Well-formed frontmatter, no duplicates, no inside-colon (control)",
      "sanity_verdict_pre": "OK",
      "recipe_f_action": "NOT_INVOKED",
      "finding_class": null,
      "finding_category": null,
      "post_file_state": "unchanged",
      "sanity_verdict_post": "OK",
      "skill_action": "proceed"
    }
  ]
}
```

- [ ] **Step 3: Create `README.md` for fixture**

```markdown
# Recipe-(f) Duplicate-Key Resolution — Test Fixture

5-cell decision matrix for the v0.1.4 W4 policy change in `references/yaml-edits.md` recipe-(f). Each cell exercises one branch of the new branching logic. `_truth.json` is the canonical truth-table.

## Population

| Cell | File | Inside-colon? | Duplicates? | Values | Expected verdict | Expected action |
|------|------|---------------|-------------|--------|------------------|-----------------|
| A | `cell-A-divergent-inside-colon.md` | yes (`status:`) | yes (status × 2) | divergent (`draft` ≠ `ready-for-designer`) | `DUPLICATE_KEYS_DIVERGENT_VALUES` | ABORT, file unchanged, Class-A |
| B | `cell-B-identical-inside-colon.md` | yes (`created:`) | yes (created × 2) | identical (`2024-03-14` = `2024-03-14`) | `BROKEN_KEYS_INSIDE_COLON` | normalize + silent dedup, Class-D |
| C | `cell-C-divergent-plain.md` | no | yes (status × 2) | divergent (`draft` ≠ `ready-for-designer`) | `DUPLICATE_KEYS_DIVERGENT_VALUES` | ABORT, file unchanged, Class-A |
| D | `cell-D-identical-plain.md` | no | yes (modified × 2) | identical (`2024-06-15` = `2024-06-15`) | `DUPLICATE_KEYS_IDENTICAL_VALUES` | silent dedup, Class-D |
| E | `cell-E-control-no-duplicates.md` | no | no | n/a | `OK` | proceed |

## Design rationale

**Why 5 cells, not 2:** A 2-cell fixture (divergent + identical) under-covers the contract. Pre-existing plain-key duplicates without any inside-colon shape were NOT exercised by recipe-f pre-W4 (sanity-check returned OK, file stayed broken, skills processed it as first-wins). v0.1.4 W4 extends sanity-check to detect plain-key duplicates universally; the fixture must exercise both shape-β-collision AND plain-only paths × both divergent AND identical sub-cases. Plus a control. Total = 2 × 2 + 1 = 5.

**Why files are committed directly (no generator):** Unlike W2's clone-cluster fixture (which needed `touch -t` to set filesystem birthtimes), W4's fixture is purely about frontmatter content. Git preserves frontmatter content exactly. No generator needed.

**Why F7 case is verbatim cell A:** The empirical F7 anchor (`status: draft` vs `status: ready-for-designer` on `neckarshore.ai brand style guide brief.md`, GR-3 Cell 1, 2026-05-01) is the smallest non-trivial divergent inside-colon collision. Cell A reproduces the exact pattern; if cell A passes the new policy, the F7 regression is locked.
```

- [ ] **Step 4: Commit fixture (red — assertion harness does not exist yet, but fixture is content-stable)**

```bash
git checkout main
git pull --rebase
git checkout -b obi/v0.1.4-w4-recipe-f-duplicate-keys
git add tests/fixtures/recipe-f-duplicate-keys/
git commit -m "test(v0.1.4 W4): T1 5-cell recipe-f duplicate-key fixture + truth table"
```

Expected: clean commit, 7 new files (5 markdown + _truth.json + README.md).

---

### Task 2: Update `references/yaml-sanity.md` — new verdict + Pattern 5 + per-skill matrix + idempotency contract

**Files:**
- Modify: `references/yaml-sanity.md`

This is the largest single edit in W4 — five distinct mutations to the sanity-check spec doc.

- [ ] **Step 1: Update Verdicts table — add 2 new rows**

Open `references/yaml-sanity.md` line 27 (`## Verdicts`).

`old_string`:

```text
| `BROKEN_KEYS_INSIDE_COLON` | One or more shape β inside-colon patterns detected (`"<key>:":`) — F26 | Repair via recipe (f) (if skill is repair-capable) OR skip + Class-C finding (additive-only skills) |
| `MULTIPLE_FRONTMATTER_BLOCKS` | Two or more `---/---` pairs at frontmatter-boundary positions | Skip + Class-A finding. Route to `note-rename` corrupted-file-detection if not already there. |
```

`new_string`:

```text
| `BROKEN_KEYS_INSIDE_COLON` | One or more shape β inside-colon patterns detected (`"<key>:":`) — F26 | Repair via recipe (f) (if skill is repair-capable) OR skip + Class-C finding (additive-only skills) |
| `DUPLICATE_KEYS_DIVERGENT_VALUES` | Two or more frontmatter lines define the same key with divergent non-empty values (after shape β normalize, if any). F7 family. | Skip + Class-A finding "duplicate-key-divergent-values". Route to user / `note-rename` for manual resolution. Recipe (f) does NOT auto-resolve — file is left unchanged to preserve user intent. |
| `DUPLICATE_KEYS_IDENTICAL_VALUES` | Two or more frontmatter lines define the same key with identical values (no inside-colon shape required). | Repair via recipe (f) silent dedup (keep first, remove rest, Class-D finding per removed line). Same operational path as `BROKEN_KEYS_INSIDE_COLON` for repair-capable skills. |
| `MULTIPLE_FRONTMATTER_BLOCKS` | Two or more `---/---` pairs at frontmatter-boundary positions | Skip + Class-A finding. Route to `note-rename` corrupted-file-detection if not already there. |
```

- [ ] **Step 2: Update Verdict-priority ladder**

`old_string`:

```text
**Verdict-priority:** A file may match multiple patterns. Verdict order: `MULTIPLE_FRONTMATTER_BLOCKS` > `UNCLOSED_FRONTMATTER` > `INVALID_YAML` > `BROKEN_KEYS_INSIDE_COLON` > `OK_QUOTED` > `OK_NO_FRONTMATTER` > `OK`. Highest matching verdict wins. Cosmetic findings logged regardless of verdict.
```

`new_string`:

```text
**Verdict-priority:** A file may match multiple patterns. Verdict order: `MULTIPLE_FRONTMATTER_BLOCKS` > `UNCLOSED_FRONTMATTER` > `INVALID_YAML` > `DUPLICATE_KEYS_DIVERGENT_VALUES` > `BROKEN_KEYS_INSIDE_COLON` > `DUPLICATE_KEYS_IDENTICAL_VALUES` > `OK_QUOTED` > `OK_NO_FRONTMATTER` > `OK`. Highest matching verdict wins. Cosmetic findings logged regardless of verdict.

**Why divergent > inside-colon > identical:** A file with shape β AND divergent-value duplicates is BOTH broken-keyed AND ambiguous. The divergent ambiguity dominates because it requires user-action regardless of repair-capability — the skill must NOT silently pick a winner. Inside-colon-only (no divergent dup) is repairable and dominates over identical-only-duplicates because shape β makes the YAML unparseable, while identical plain duplicates parse (most YAML parsers tolerate identical-value duplicates with a warning) but should still be dedupped for cleanliness.
```

- [ ] **Step 3: Add Pattern 5 — Duplicate-key detection (after Pattern 4 cosmetic, before "Per-skill policy")**

Find the line `## Per-skill policy` (around line 125 currently). Insert before it:

`old_string`:

```text
**Verdict contribution:** logged in finding list, but verdict stays at the worst non-cosmetic verdict found.

## Per-skill policy
```

`new_string`:

```text
**Verdict contribution:** logged in finding list, but verdict stays at the worst non-cosmetic verdict found.

### Pattern 5 — Duplicate-key detection (universal, post-Pattern-1-normalize)

Walk a *post-shape-β-normalize* view of the frontmatter (in-memory; this view is what recipe-f would produce in its Step 2 if invoked). Index lines by key-name. For each key-name appearing on ≥ 2 lines, collect the per-line value strings.

**Per-line value extraction:** strip leading whitespace, strip the `<key>:` prefix, strip leading/trailing whitespace from the remainder, strip a trailing comment (`# ...`). The resulting normalized value string is what gets compared.

**Sub-case branching:**
- All collected value strings are byte-identical → `DUPLICATE_KEYS_IDENTICAL_VALUES` finding (per-key-name).
- Any pair of value strings differs → `DUPLICATE_KEYS_DIVERGENT_VALUES` finding (per-key-name). Empty-string values are treated as identical to each other but divergent vs any non-empty (defensive default — empty values almost certainly indicate a stub the user did not finish; keep the non-empty value's question alive).

**Verdict contribution:**
- If any divergent finding → `DUPLICATE_KEYS_DIVERGENT_VALUES` (Class-A territory).
- Else if any identical finding → `DUPLICATE_KEYS_IDENTICAL_VALUES` (Class-D-aggregate verdict, repairable).
- Else → no contribution from Pattern 5.

**Detection-precedence interaction:** Pattern 5 walks the *post-normalize* view, so a file with shape β AND a divergent duplicate against the normalized form (cell A) yields `DUPLICATE_KEYS_DIVERGENT_VALUES` (verdict-priority puts divergent above shape β). A file with shape β AND identical duplicate against the normalized form (cell B) yields `BROKEN_KEYS_INSIDE_COLON` (the broken shape signals repair-needed; recipe-f's silent dedup handles the identical collision as Class-D side effect). A file with no shape β but plain divergent duplicates (cell C) yields `DUPLICATE_KEYS_DIVERGENT_VALUES` directly. A file with no shape β but plain identical duplicates (cell D) yields `DUPLICATE_KEYS_IDENTICAL_VALUES`.

**Worked example (cell A — F7 empirical case):**

Input:

```yaml
---
"status:": draft
status: ready-for-designer
title: F7 case
---
```

1. Walk lines.
2. Line 1: matches Pattern 1 (shape β, key `status`).
3. Line 2: plain key `status`.
4. Compute post-normalize view: `[status: draft, status: ready-for-designer, title: F7 case]`.
5. Pattern 5 walk: key `status` appears twice. Values: `draft`, `ready-for-designer`. Byte-different → divergent.
6. Verdict: `DUPLICATE_KEYS_DIVERGENT_VALUES` (priority dominates `BROKEN_KEYS_INSIDE_COLON`).
7. Findings: 1× duplicate-key-divergent-values for key `status` (Class A), 1× shape-β cosmetic for `"status:"` line (informational).

## Per-skill policy
```

- [ ] **Step 4: Update Per-skill policy table — add 2 columns**

`old_string`:

```text
| Skill | On Class-A (multi-block / unclosed) | On `BROKEN_KEYS_INSIDE_COLON` (shape β) | On `OK_QUOTED` (shape α) | On Class-D cosmetic |
|-------|-----------|---------------------------------|----------------------------------|---------------------|
| `property-enrich` | skip + Class-A finding (route to user / note-rename) | repair via Step 2a recipe (f), then re-run sanity-check (idempotent fixpoint) | proceed; skill regex matches both shapes | proceed |
| `note-rename` | use existing Corrupted File Detection (rename file with corruption-label) | repair via Step 4a recipe (f) (broadened from existing hardcoded-list) | proceed; skill regex matches both shapes | proceed |
| `inbox-sort` | skip + Class-A finding (route to note-rename) | repair via Step 5a recipe (f) (broadened from existing hardcoded-list) | proceed; skill regex matches both shapes | proceed |
| `property-describe` | skip + Class-A finding | SKIP + Class-C finding "broken-yaml: inside-colon shape detected — run property-enrich first" (NOT repair — boundaries: describe is additive-only) | proceed; broadened filter regex catches both plain and standard-quoted forms | proceed |
| `property-classify` (v0.2.0) | skip + finding | skip + finding | proceed; broadened regex | proceed |
```

`new_string`:

```text
| Skill | On Class-A (multi-block / unclosed) | On `DUPLICATE_KEYS_DIVERGENT_VALUES` | On `BROKEN_KEYS_INSIDE_COLON` (shape β) | On `DUPLICATE_KEYS_IDENTICAL_VALUES` | On `OK_QUOTED` (shape α) | On Class-D cosmetic |
|-------|-----------|--------------------------------------|---------------------------------|--------------------------------------|----------------------------------|---------------------|
| `property-enrich` | skip + Class-A finding (route to user / note-rename) | skip + Class-A finding "duplicate-key-divergent-values" (route to user / note-rename) — recipe (f) does NOT auto-resolve | repair via Step 2a recipe (f), then re-run sanity-check (idempotent fixpoint) | repair via Step 2a recipe (f) silent dedup, then re-run sanity-check | proceed; skill regex matches both shapes | proceed |
| `note-rename` | use existing Corrupted File Detection (rename file with corruption-label) | skip + Class-A finding "duplicate-key-divergent-values" (route to user; do NOT rename — file may legitimately need user merge first) | repair via Step 4a recipe (f) (broadened from existing hardcoded-list) | repair via Step 4a recipe (f) silent dedup | proceed; skill regex matches both shapes | proceed |
| `inbox-sort` | skip + Class-A finding (route to note-rename) | skip + Class-A finding "duplicate-key-divergent-values" (route to user / note-rename) | repair via Step 5a recipe (f) (broadened from existing hardcoded-list) | repair via Step 5a recipe (f) silent dedup | proceed; skill regex matches both shapes | proceed |
| `property-describe` | skip + Class-A finding | skip + Class-A finding "duplicate-key-divergent-values" (route to user / property-enrich for resolution) | SKIP + Class-C finding "broken-yaml: inside-colon shape detected — run property-enrich first" (NOT repair — boundaries: describe is additive-only) | SKIP + Class-C finding "duplicate-keys-identical: run property-enrich first to dedup" (additive-only — defer to repair-capable skill) | proceed; broadened filter regex catches both plain and standard-quoted forms | proceed |
| `property-classify` (v0.2.0) | skip + finding | skip + finding | skip + finding | skip + finding | proceed; broadened regex | proceed |
```

- [ ] **Step 5: Amend Idempotency contract**

`old_string`:

```text
## Idempotency

After a repair-skill runs the inside-colon-quoted-key normalization (recipe f), calling the sanity-check again on the same file MUST return `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER` (any non-`BROKEN_KEYS_INSIDE_COLON` non-Class-A verdict). This is the contract: repair is permanent within the run, normalize is idempotent.
```

`new_string`:

```text
## Idempotency

After a repair-skill runs the inside-colon-quoted-key normalization (recipe f) AND no `DUPLICATE_KEYS_DIVERGENT_VALUES` was present pre-repair, calling the sanity-check again on the same file MUST return `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER` (any non-`BROKEN_KEYS_INSIDE_COLON` non-Class-A verdict). This is the contract: repair is permanent within the run, normalize + identical-dedup are idempotent.

**Exception — divergent-value abort path:** if pre-repair sanity-check returned `DUPLICATE_KEYS_DIVERGENT_VALUES`, recipe (f) does NOT modify the file (per recipe (f) Step 3 branching — see `references/yaml-edits.md`). Post-recipe sanity-check therefore still returns `DUPLICATE_KEYS_DIVERGENT_VALUES`. This is intentional: the file is in an ambiguous state that requires user-action; recipe (f) prevents silent value-loss by refusing to pick a winner. Caller must skip the file and route to user / note-rename per the per-skill policy table.

**Why this is still correct as a contract:** Idempotency means "running twice is equivalent to running once." Both runs of recipe (f) on a divergent-duplicate file produce the same result (no change, same verdict). The contract holds; it just terminates in a non-OK state when the file is genuinely ambiguous.
```

- [ ] **Step 6: Run grep verifications**

```bash
grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES" references/yaml-sanity.md
```

Expected: ≥ 5 (verdicts table, priority ladder, Pattern 5 sub-case branching, Pattern 5 worked example, per-skill policy header, idempotency contract, exception clause). Adjust if grep count differs by inspection.

```bash
grep -c "DUPLICATE_KEYS_IDENTICAL_VALUES" references/yaml-sanity.md
```

Expected: ≥ 3 (verdicts table, priority ladder, Pattern 5 sub-case branching, per-skill policy column).

```bash
grep -n "Pattern 5" references/yaml-sanity.md
```

Expected: 1 occurrence (the section heading), at a line between Pattern 4 and Per-skill policy.

- [ ] **Step 7: Commit**

```bash
git add references/yaml-sanity.md
git commit -m "spec(v0.1.4 W4): T2 yaml-sanity DUPLICATE_KEYS verdicts + Pattern 5 + matrix + idempotency exception"
```

---

### Task 3: Update `references/yaml-edits.md` recipe-(f) — Step 3 branching + replace worked example + add divergent example

**Files:**
- Modify: `references/yaml-edits.md`

- [ ] **Step 1: Replace recipe-(f) Step 3 (current "first wins" → branching)**

Open `references/yaml-edits.md` line 240 (`### Recipe (f) — Normalize inside-colon quoted-keys (F26 repair)` block).

`old_string`:

```text
3. After all replacements, walk frontmatter lines again. If any key-name now
   appears on two or more lines (post-normalization collision):
   a. Keep the FIRST occurrence (= the line that was originally inside-colon-
      quoted, now normalized — assume original/correct value).
   b. Remove subsequent occurrences.
   c. Log each removed line as Class-D finding (file_ref + key_name + value).
```

`new_string`:

```text
3. After all replacements (in-memory; do NOT write yet), walk the computed line
   list. Build a key-name → list-of-values index. For each key-name appearing
   on ≥ 2 lines:
   a. Extract per-line normalized value: strip leading whitespace, strip the
      `<key>:` prefix, strip leading/trailing whitespace from the remainder,
      strip a trailing comment (`# ...`).
   b. Compare values byte-wise across the lines for this key-name.
   c. **All values byte-identical** (the safe-collision sub-case):
      - Keep the FIRST occurrence, remove subsequent occurrences from the
        in-memory list.
      - Log each removed line as Class-D finding "duplicate-key-removed-identical"
        (file_ref + key_name + value).
   d. **Any value differs from another** (the divergent sub-case — F7 family):
      - **ABORT recipe (f) for this file.** Do NOT write the in-memory list
        back to disk. The on-disk file is left exactly as it was when recipe
        (f) was invoked.
      - Log a Class-A finding "duplicate-key-divergent-values" (file_ref +
        key_name + list of all observed values) per affected key-name.
      - Return signal `DIVERGENT` to caller. Caller skips the file per per-skill
        policy in `references/yaml-sanity.md` § "Per-skill policy".
   e. If no divergent collisions are present (all collisions were identical-value
      OR no collisions at all), proceed to step 6 with the deduplicated in-memory
      line list.
```

- [ ] **Step 2: Replace the existing worked example (it contradicts the new policy)**

The current worked example (lines 261-292 of yaml-edits.md) uses divergent values (`2024-03-14` vs `2025-01-01`) and shows silent keep-first dedup. Under W4 this is the WRONG outcome. Replace with two examples: one identical (silent dedup, current happy path) and one divergent (ABORT, new behavior).

`old_string`:

```text
### Worked example — recipe (f)

**Input (broken):**

```yaml
---
"created:": 2024-03-14
created: 2025-01-01
"modified:": 2024-06-15
"description:": Apple Notes export
tags: [AppleNoteImport]
---
```

**Procedure:**

1. Walk frontmatter lines 1..5.
2. Line 1 matches `F26_INSIDE_COLON_PATTERN`: groups `("", "created", " 2024-03-14")` → replace with `created: 2024-03-14`.
3. Line 2: no match (already plain).
4. Line 3 matches: groups `("", "modified", " 2024-06-15")` → replace with `modified: 2024-06-15`.
5. Line 4 matches: groups `("", "description", " Apple Notes export")` → replace with `description: Apple Notes export`.
6. Line 5: no match.
7. Post-replacement: walk again. Two `created:` lines exist now (line 1 = `2024-03-14`, line 2 = `2025-01-01`). Keep first, remove second. Log Class-D finding "duplicate-key removed: created (kept original quoted-form value 2024-03-14, removed plain-form value 2025-01-01)".

**Output:**

```yaml
---
created: 2024-03-14
modified: 2024-06-15
description: Apple Notes export
tags: [AppleNoteImport]
---
```

Re-running recipe (f) on the output: step 2 matches no lines, function is a no-op. Idempotent.
```

`new_string`:

```text
### Worked example A — recipe (f) identical-value collision (silent dedup, Class-D)

**Input (broken — shape β + identical-value collision):**

```yaml
---
"created:": 2024-03-14
created: 2024-03-14
"modified:": 2024-06-15
"description:": Apple Notes export
tags: [AppleNoteImport]
---
```

**Procedure:**

1. Walk frontmatter lines 1..5.
2. Line 1 matches `F26_INSIDE_COLON_PATTERN`: groups `("", "created", " 2024-03-14")` → would replace with `created: 2024-03-14` (in-memory).
3. Line 2: no match (already plain). Value `2024-03-14`.
4. Line 3 matches: groups `("", "modified", " 2024-06-15")` → would replace with `modified: 2024-06-15`.
5. Line 4 matches: groups `("", "description", " Apple Notes export")` → would replace with `description: Apple Notes export`.
6. Line 5: no match.
7. Post-replacement walk (in-memory): two `created:` lines (line 1 = `2024-03-14`, line 2 = `2024-03-14`). Compare normalized values: byte-identical. Sub-case (c): keep first, remove second. Log Class-D finding "duplicate-key-removed-identical: created (kept value `2024-03-14`)".
8. No divergent collisions. Proceed to write back the deduplicated normalized line list.

**Output:**

```yaml
---
created: 2024-03-14
modified: 2024-06-15
description: Apple Notes export
tags: [AppleNoteImport]
---
```

Re-running recipe (f) on the output: step 2 matches no lines, step 3 finds no duplicates, function is a no-op. Idempotent.

### Worked example B — recipe (f) divergent-value collision (ABORT, Class-A, F7 case)

**Input (broken — shape β + divergent-value collision; mirrors the empirical F7 finding from GR-3 Cell 1, 2026-05-01, on `neckarshore.ai brand style guide brief.md`):**

```yaml
---
"status:": draft
status: ready-for-designer
title: F7 case
---
```

**Procedure:**

1. Walk frontmatter lines 1..3.
2. Line 1 matches `F26_INSIDE_COLON_PATTERN`: groups `("", "status", " draft")` → would replace with `status: draft` (in-memory).
3. Line 2: no match (already plain). Value `ready-for-designer`.
4. Line 3: no match.
5. Post-replacement walk (in-memory): two `status:` lines (line 1 = `draft`, line 2 = `ready-for-designer`). Compare normalized values: byte-different. Sub-case (d): **ABORT recipe (f) for this file.** Do NOT write the in-memory list back. Log Class-A finding "duplicate-key-divergent-values: status (observed values: `draft`, `ready-for-designer`)".
6. Return signal `DIVERGENT` to caller.

**Output:** file on disk is unchanged (still has shape β `"status:"` line + plain `status:` line). The in-memory normalized list is discarded.

**Caller behavior** (per `references/yaml-sanity.md` per-skill policy):
- `property-enrich`: skip file, route to user / note-rename.
- `note-rename`: skip file, route to user (do NOT rename — user may legitimately need to merge values first).
- `inbox-sort`: skip file, route to user / note-rename.
- `property-describe`: skip file, route to user / property-enrich.

**Why ABORT vs auto-pick:** Either pick (first/last/heuristic) commits a silent semantic-shift on a field the user explicitly disagreed with (two values exist precisely because the user wrote them — even if one was an old import-residue and one was a manual edit). Recipe (f)'s job is structural normalization, not authorship-arbitration. The user must merge the values manually; the skill must NOT pretend it knows.

Re-running recipe (f) on the unchanged file: same outcome — sub-case (d), ABORT, log, return DIVERGENT. Idempotent in the abort sense (same input → same outcome → same verdict).
```

- [ ] **Step 3: Verify content with grep**

```bash
grep -c "ABORT" references/yaml-edits.md
```

Expected: ≥ 4 (Step 3 sub-case (d), Worked example B procedure step 5, Caller behavior intro, Why ABORT discussion).

```bash
grep -c "duplicate-key-divergent-values" references/yaml-edits.md
```

Expected: ≥ 2 (Step 3 sub-case (d) finding category, Worked example B finding text).

```bash
grep -n "duplicate-key removed: created (kept original quoted-form value 2024-03-14, removed plain-form value 2025-01-01)" references/yaml-edits.md
```

Expected: 0 occurrences (the old contradicting worked-example finding-text is gone).

- [ ] **Step 4: Commit**

```bash
git add references/yaml-edits.md
git commit -m "spec(v0.1.4 W4): T3 recipe-(f) Step 3 branching + replace worked examples (identical + divergent)"
```

---

### Task 4: Wire `skills/property-enrich/SKILL.md` Step 2a routing

**Files:**
- Modify: `skills/property-enrich/SKILL.md`

- [ ] **Step 1: Update Step 2a verdict-handling text**

Open `skills/property-enrich/SKILL.md` line 79.

`old_string`:

```text
   - **2a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md` for each scanned note. If verdict is `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon), normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns (broadened from v0.1.0/v0.1.2 hardcoded list of `"created:"`/`"modified:"`). After normalization, resolve duplicate-key collisions per recipe (f) policy. Re-call sanity-check (idempotent fixpoint) — verdict must now be `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER`. If verdict is `MULTIPLE_FRONTMATTER_BLOCKS` or `UNCLOSED_FRONTMATTER`, skip the file and log Class-A finding (route to user / note-rename). This step is mandatory BEFORE Step 3 (Compute / Source Hierarchy walk) — without it, the Hierarchy falls through to filesystem birthtime on files where YAML had a valid (but broken-keyed) date. Verdict `OK_QUOTED` (shape α — standard quoted-key, valid YAML) proceeds normally; skill regexes accept both plain and standard-quoted forms. Historical bug: F19 LIVE-CONFIRMED in GR-2 Cell 1 (2026-04-28) — 60 of 1016 inbox-tree files affected (5.9% blast-radius). F26 cluster generalizes the pattern across all quoted-keys.
```

`new_string`:

```text
   - **2a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md` for each scanned note. Verdict-routing per `references/yaml-sanity.md` § "Per-skill policy":
     - `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon): normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns (broadened from v0.1.0/v0.1.2 hardcoded list of `"created:"`/`"modified:"`). After normalization, resolve duplicate-key collisions per recipe (f) Step 3 (identical-value collisions silent-dedup'd, divergent-value collisions ABORT — see next bullet). Re-call sanity-check (idempotent fixpoint) — verdict must now be `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER`.
     - `DUPLICATE_KEYS_IDENTICAL_VALUES` (v0.1.4 W4 — pre-existing plain duplicates with identical values): repair via recipe (f) silent dedup, then re-run sanity-check.
     - `DUPLICATE_KEYS_DIVERGENT_VALUES` (v0.1.4 W4 — F7 family; recipe (f) refused to auto-resolve): **skip the file** + log Class-A finding "duplicate-key-divergent-values" (route to user / note-rename for manual resolution). Recipe (f) leaves the file unchanged on disk; user must merge values manually.
     - `MULTIPLE_FRONTMATTER_BLOCKS` or `UNCLOSED_FRONTMATTER`: skip the file and log Class-A finding (route to user / note-rename).
     - `OK_QUOTED` (shape α — standard quoted-key, valid YAML): proceed normally; skill regexes accept both plain and standard-quoted forms.
     - `OK` / `OK_NO_FRONTMATTER`: proceed normally.

     This step is mandatory BEFORE Step 3 (Compute / Source Hierarchy walk) — without it, the Hierarchy falls through to filesystem birthtime on files where YAML had a valid (but broken-keyed) date. Historical bugs: F19 LIVE-CONFIRMED in GR-2 Cell 1 (2026-04-28) — 60 of 1016 inbox-tree files affected (5.9% blast-radius). F26 cluster generalizes the inside-colon pattern across all quoted-keys. F7 (GR-3 Cell 1, 2026-05-01) generalizes duplicate-key resolution beyond first-wins-silent.
```

- [ ] **Step 2: Update Quality Check entry**

`old_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f), not appended-below
```

`new_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f), not appended-below
- [ ] Duplicate-key divergent-value collisions (F7 family) ABORT recipe (f), file unchanged, Class-A finding logged — never silent-pick a winner (v0.1.4 W4)
```

- [ ] **Step 3: Verify with grep**

```bash
grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES\|duplicate-key-divergent-values" skills/property-enrich/SKILL.md
```

Expected: ≥ 2.

- [ ] **Step 4: Commit**

```bash
git add skills/property-enrich/SKILL.md
git commit -m "spec(v0.1.4 W4): T4 property-enrich Step 2a routes DUPLICATE_KEYS_DIVERGENT_VALUES to skip+Class-A"
```

---

### Task 5: Wire `skills/note-rename/SKILL.md` Step 4a routing

**Files:**
- Modify: `skills/note-rename/SKILL.md`

- [ ] **Step 1: Update Step 4a verdict-handling text**

Open `skills/note-rename/SKILL.md` line 155.

`old_string`:

```text
   - **4a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md`. If verdict is `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon), normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns, not just `"created:"`/`"modified:"` (broadened from v0.1.0/v0.1.2 hardcoded list). After normalization, resolve duplicate-key collisions per recipe (f) policy. Re-call sanity-check (idempotent fixpoint) — verdict must now be `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER`. If verdict is `MULTIPLE_FRONTMATTER_BLOCKS`, use existing Corrupted File Detection (rename file with corruption-label). YAML edits MUST follow `references/yaml-edits.md` (recipes b + f). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 4c silently skips legitimate candidates. Verdict `OK_QUOTED` (shape α — standard quoted-key, valid YAML) proceeds normally; classification regex accepts both plain and standard-quoted forms. Historical bug: repo issue #4 (2026-04-27) for `created`/`modified`; F26 cross-skill cluster (2026-04-28) generalized the pattern.
```

`new_string`:

```text
   - **4a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md`. Verdict-routing per `references/yaml-sanity.md` § "Per-skill policy":
     - `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon): normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns, not just `"created:"`/`"modified:"` (broadened from v0.1.0/v0.1.2 hardcoded list). After normalization, resolve duplicate-key collisions per recipe (f) Step 3 (identical → silent dedup; divergent → ABORT, see next bullet). Re-call sanity-check (idempotent fixpoint) — verdict must now be `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER`.
     - `DUPLICATE_KEYS_IDENTICAL_VALUES` (v0.1.4 W4): repair via recipe (f) silent dedup, then re-run sanity-check.
     - `DUPLICATE_KEYS_DIVERGENT_VALUES` (v0.1.4 W4 — F7 family): **skip the file** + log Class-A finding "duplicate-key-divergent-values". Do NOT rename — user may legitimately need to merge values first; rename would obscure the underlying ambiguity. Route to user.
     - `MULTIPLE_FRONTMATTER_BLOCKS`: use existing Corrupted File Detection (rename file with corruption-label).
     - `OK_QUOTED`: proceed normally.
     - `OK` / `OK_NO_FRONTMATTER`: proceed normally.

     YAML edits MUST follow `references/yaml-edits.md` (recipes b + f). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 4c silently skips legitimate candidates. Classification regex accepts both plain and standard-quoted forms. Historical bugs: repo issue #4 (2026-04-27) for `created`/`modified`; F26 cross-skill cluster (2026-04-28) generalized the inside-colon pattern; F7 (GR-3 Cell 1, 2026-05-01) generalized duplicate-key resolution beyond first-wins-silent (v0.1.4 W4).
```

- [ ] **Step 2: Update Quality Check entry**

`old_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f); standard quoted-keys (shape α) pass through as `OK_QUOTED`
```

`new_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f); standard quoted-keys (shape α) pass through as `OK_QUOTED`
- [ ] Duplicate-key divergent-value collisions (F7 family) skip + Class-A finding; file is NOT renamed — user merges manually first (v0.1.4 W4)
```

- [ ] **Step 3: Verify with grep**

```bash
grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES\|duplicate-key-divergent-values" skills/note-rename/SKILL.md
```

Expected: ≥ 2.

- [ ] **Step 4: Commit**

```bash
git add skills/note-rename/SKILL.md
git commit -m "spec(v0.1.4 W4): T5 note-rename Step 4a routes DUPLICATE_KEYS_DIVERGENT_VALUES to skip+Class-A (no rename)"
```

---

### Task 6: Wire `skills/inbox-sort/SKILL.md` Step 5a routing

**Files:**
- Modify: `skills/inbox-sort/SKILL.md`

- [ ] **Step 1: Update Step 5a verdict-handling text**

Open `skills/inbox-sort/SKILL.md` line 51.

`old_string`:

```text
   - **5a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md`. If verdict is `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon, typical Apple Notes / Drafts import artifact), normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns (broadened from v0.1.2 hardcoded `"created:"`/`"modified:"`). After normalization, resolve duplicate-key collisions per recipe (f) policy. Re-call sanity-check (idempotent fixpoint). If verdict is `MULTIPLE_FRONTMATTER_BLOCKS` or `UNCLOSED_FRONTMATTER`, skip the file and log Class-A finding (route to note-rename for handling). YAML edits MUST follow `references/yaml-edits.md` (recipes b + f). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 5c silently skips legitimate candidates. Verdict `OK_QUOTED` (shape α — standard quoted-key, valid YAML) proceeds normally. Mirrors note-rename Step 4a — historical bug: repo issues #4 and #6 (2026-04-27) for `created`/`modified`; F26 cross-skill cluster (2026-04-28) generalized the pattern.
```

`new_string`:

```text
   - **5a. Repair corrupted quoted-key variants first (Nahbereich, sanity-check).** Call `references/yaml-sanity.md`. Verdict-routing per `references/yaml-sanity.md` § "Per-skill policy":
     - `BROKEN_KEYS_INSIDE_COLON` (shape β — F26 inside-colon, typical Apple Notes / Drafts import artifact): normalize via `references/yaml-edits.md` recipe (f) — handles ALL quoted-key patterns (broadened from v0.1.2 hardcoded `"created:"`/`"modified:"`). After normalization, resolve duplicate-key collisions per recipe (f) Step 3 (identical → silent dedup; divergent → ABORT, see next bullet). Re-call sanity-check (idempotent fixpoint).
     - `DUPLICATE_KEYS_IDENTICAL_VALUES` (v0.1.4 W4): repair via recipe (f) silent dedup, then re-run sanity-check.
     - `DUPLICATE_KEYS_DIVERGENT_VALUES` (v0.1.4 W4 — F7 family): **skip the file** + log Class-A finding "duplicate-key-divergent-values" (route to user / note-rename).
     - `MULTIPLE_FRONTMATTER_BLOCKS` or `UNCLOSED_FRONTMATTER`: skip the file and log Class-A finding (route to note-rename for handling).
     - `OK_QUOTED`: proceed normally.
     - `OK` / `OK_NO_FRONTMATTER`: proceed normally.

     YAML edits MUST follow `references/yaml-edits.md` (recipes b + f). Without this normalization a strict YAML parser cannot read the author-intended date, falls back to the Source Hierarchy → filesystem birthtime (often fresh on cloned vaults), and the cooldown evaluation in 5c silently skips legitimate candidates. Mirrors note-rename Step 4a — historical bugs: repo issues #4 and #6 (2026-04-27) for `created`/`modified`; F26 cross-skill cluster (2026-04-28) generalized the inside-colon pattern; F7 (GR-3 Cell 1, 2026-05-01) generalized duplicate-key resolution (v0.1.4 W4).
```

- [ ] **Step 2: Update Quality Check entry**

`old_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f); standard quoted-keys (shape α) pass through as `OK_QUOTED`
```

`new_string`:

```text
- [ ] Quoted-key broken-key variants (shape β — inside-colon) normalized via recipe (f); standard quoted-keys (shape α) pass through as `OK_QUOTED`
- [ ] Duplicate-key divergent-value collisions (F7 family) skip + Class-A finding; file is NOT moved — user resolves first (v0.1.4 W4)
```

- [ ] **Step 3: Verify with grep**

```bash
grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES\|duplicate-key-divergent-values" skills/inbox-sort/SKILL.md
```

Expected: ≥ 2.

- [ ] **Step 4: Commit**

```bash
git add skills/inbox-sort/SKILL.md
git commit -m "spec(v0.1.4 W4): T6 inbox-sort Step 5a routes DUPLICATE_KEYS_DIVERGENT_VALUES to skip+Class-A (no move)"
```

---

### Task 7: Wire `skills/property-describe/SKILL.md` Step 2a routing

**Files:**
- Modify: `skills/property-describe/SKILL.md`

- [ ] **Step 1: Locate Step 2a sanity-check call**

```bash
grep -n "yaml-sanity" skills/property-describe/SKILL.md
```

Expected: 1+ occurrences. Identify the Step 2a block's exact `old_string`.

- [ ] **Step 2: Update Step 2a verdict-handling text** (verbatim old_string + new_string filled in by inspection of current file content)

Read the current Step 2a text in `skills/property-describe/SKILL.md`. Apply the parallel pattern to T4-T6: add `DUPLICATE_KEYS_DIVERGENT_VALUES` and `DUPLICATE_KEYS_IDENTICAL_VALUES` cases. Per-skill policy table mandates property-describe (additive-only) treatment:
- `DUPLICATE_KEYS_DIVERGENT_VALUES` → skip + Class-A finding (route to user / property-enrich for resolution)
- `DUPLICATE_KEYS_IDENTICAL_VALUES` → SKIP + Class-C finding "duplicate-keys-identical: run property-enrich first to dedup" (additive-only — defer to repair-capable skill)

Pattern:

```text
- `DUPLICATE_KEYS_DIVERGENT_VALUES` (v0.1.4 W4 — F7 family): skip + Class-A finding "duplicate-key-divergent-values" (route to user / property-enrich for resolution).
- `DUPLICATE_KEYS_IDENTICAL_VALUES` (v0.1.4 W4): SKIP + Class-C finding "duplicate-keys-identical: run property-enrich first to dedup" (additive-only — defer to repair-capable skill).
```

Insert these two bullets in the Step 2a routing list, in priority-order (divergent first because Class-A).

- [ ] **Step 3: Add Quality Check entry**

Insert (after the existing shape β QC entry):

```text
- [ ] Duplicate-key divergent-value collisions (F7 family) skip + Class-A finding; describe is additive-only and never auto-resolves (v0.1.4 W4)
```

- [ ] **Step 4: Verify with grep**

```bash
grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES\|duplicate-key-divergent-values" skills/property-describe/SKILL.md
```

Expected: ≥ 2.

- [ ] **Step 5: Commit**

```bash
git add skills/property-describe/SKILL.md
git commit -m "spec(v0.1.4 W4): T7 property-describe Step 2a routes DUPLICATE_KEYS_DIVERGENT_VALUES to skip+Class-A"
```

---

### Task 8: Build assertion harness `scripts/test-recipe-f-duplicate-keys.sh` (6 sections)

**Files:**
- Create: `scripts/test-recipe-f-duplicate-keys.sh`

- [ ] **Step 1: Write the 6-section assertion script**

```bash
#!/usr/bin/env bash
# v0.1.4 W4 assertion harness for recipe-(f) duplicate-key resolution policy.
# Mirrors scripts/test-clone-cluster.sh structure (W2). 6 sections.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="${REPO_ROOT}/tests/fixtures/recipe-f-duplicate-keys"
NOTES="${FIXTURE_ROOT}/notes"
TRUTH="${FIXTURE_ROOT}/_truth.json"

PASS=0
FAIL=0

ok()   { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL+1)); }

# ─── Section [1/6] Fixture structure ─────────────────────────────────────────
echo "[1/6] Fixture structure"

[ -d "$NOTES" ] && ok "notes/ exists" || fail "notes/ missing"
[ -f "$TRUTH" ] && ok "_truth.json exists" || fail "_truth.json missing"
[ -f "${FIXTURE_ROOT}/README.md" ] && ok "README.md exists" || fail "README.md missing"

for cell in cell-A-divergent-inside-colon cell-B-identical-inside-colon cell-C-divergent-plain cell-D-identical-plain cell-E-control-no-duplicates; do
  [ -f "${NOTES}/${cell}.md" ] && ok "${cell}.md exists" || fail "${cell}.md missing"
done

# ─── Section [2/6] Decision matrix per fixture ───────────────────────────────
echo "[2/6] Decision matrix — per-cell verdict simulation against _truth.json"

# Inline simulation: walk the YAML frontmatter, detect (a) shape-β inside-colon
# patterns, (b) duplicate-key collisions on the post-normalize view, (c)
# divergent-vs-identical sub-case. Compute the verdict per Pattern 1 + Pattern 5
# in references/yaml-sanity.md.

simulate_verdict() {
  local file="$1"
  awk '
    BEGIN { in_fm = 0; fm_seen = 0 }
    /^---$/ {
      if (fm_seen == 0) { fm_seen = 1; in_fm = 1; next }
      else if (in_fm == 1) { in_fm = 0; next }
    }
    in_fm == 1 { print }
  ' "$file"
}

verdict_for() {
  local file="$1"
  local fm
  fm=$(simulate_verdict "$file")

  # Detect shape-β inside-colon lines.
  local shape_b_count
  shape_b_count=$(printf '%s\n' "$fm" | grep -cE '^[[:space:]]*"[^"]+:"[[:space:]]*:' || true)

  # Build post-normalize view: replace shape-β `"<key>:":<value>` with `<key>:<value>`.
  local normalized
  normalized=$(printf '%s\n' "$fm" | sed -E 's/^([[:space:]]*)"([^"]+):"[[:space:]]*:(.*)$/\1\2:\3/')

  # Extract key-name per line (strip whitespace + value).
  local keys
  keys=$(printf '%s\n' "$normalized" | sed -nE 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_-]*)[[:space:]]*:.*$/\1/p')

  # Find duplicates.
  local dup_keys
  dup_keys=$(printf '%s\n' "$keys" | sort | uniq -d)

  if [ -n "$dup_keys" ]; then
    # For each dup key, compare values.
    local divergent=0
    while IFS= read -r dk; do
      [ -z "$dk" ] && continue
      local vals
      vals=$(printf '%s\n' "$normalized" | awk -v k="$dk" '
        {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          sub(/[[:space:]]*#.*$/, "", line)
          if (match(line, "^" k "[[:space:]]*:")) {
            v = substr(line, RLENGTH + 1)
            sub(/^[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            print v
          }
        }')
      local distinct
      distinct=$(printf '%s\n' "$vals" | sort -u | wc -l | tr -d ' ')
      if [ "$distinct" -gt 1 ]; then
        divergent=1
      fi
    done <<<"$dup_keys"

    if [ "$divergent" -eq 1 ]; then
      echo "DUPLICATE_KEYS_DIVERGENT_VALUES"; return
    fi
    if [ "$shape_b_count" -gt 0 ]; then
      echo "BROKEN_KEYS_INSIDE_COLON"; return
    fi
    echo "DUPLICATE_KEYS_IDENTICAL_VALUES"; return
  fi

  if [ "$shape_b_count" -gt 0 ]; then
    echo "BROKEN_KEYS_INSIDE_COLON"; return
  fi
  echo "OK"
}

declare -A EXPECTED=(
  ["cell-A-divergent-inside-colon"]="DUPLICATE_KEYS_DIVERGENT_VALUES"
  ["cell-B-identical-inside-colon"]="BROKEN_KEYS_INSIDE_COLON"
  ["cell-C-divergent-plain"]="DUPLICATE_KEYS_DIVERGENT_VALUES"
  ["cell-D-identical-plain"]="DUPLICATE_KEYS_IDENTICAL_VALUES"
  ["cell-E-control-no-duplicates"]="OK"
)

for cell in "${!EXPECTED[@]}"; do
  actual=$(verdict_for "${NOTES}/${cell}.md")
  expected="${EXPECTED[$cell]}"
  if [ "$actual" = "$expected" ]; then
    ok "${cell}.md → ${actual}"
  else
    fail "${cell}.md → expected ${expected}, got ${actual}"
  fi
done

# ─── Section [3/6] Recipe-doc content claims (yaml-edits.md) ────────────────
echo "[3/6] yaml-edits.md content claims"

EDITS="${REPO_ROOT}/references/yaml-edits.md"

grep -q "ABORT recipe (f) for this file" "$EDITS" && ok "step 3 sub-case (d) ABORT language present" || fail "step 3 sub-case (d) ABORT language missing"
grep -q "duplicate-key-removed-identical" "$EDITS" && ok "Class-D identical-collision finding category present" || fail "Class-D identical-collision finding category missing"
grep -q "duplicate-key-divergent-values" "$EDITS" && ok "Class-A divergent finding category present" || fail "Class-A divergent finding category missing"
grep -q "Worked example A — recipe (f) identical-value collision" "$EDITS" && ok "worked example A heading present" || fail "worked example A heading missing"
grep -q "Worked example B — recipe (f) divergent-value collision" "$EDITS" && ok "worked example B heading present" || fail "worked example B heading missing"
grep -qF "duplicate-key removed: created (kept original quoted-form value 2024-03-14, removed plain-form value 2025-01-01)" "$EDITS" && fail "old contradicting worked-example finding-text still present" || ok "old contradicting worked-example finding-text removed"

# ─── Section [4/6] Sanity-doc content claims (yaml-sanity.md) ───────────────
echo "[4/6] yaml-sanity.md content claims"

SANITY="${REPO_ROOT}/references/yaml-sanity.md"

grep -q "DUPLICATE_KEYS_DIVERGENT_VALUES" "$SANITY" && ok "new verdict DUPLICATE_KEYS_DIVERGENT_VALUES present" || fail "new verdict DUPLICATE_KEYS_DIVERGENT_VALUES missing"
grep -q "DUPLICATE_KEYS_IDENTICAL_VALUES" "$SANITY" && ok "new verdict DUPLICATE_KEYS_IDENTICAL_VALUES present" || fail "new verdict DUPLICATE_KEYS_IDENTICAL_VALUES missing"
grep -q "Pattern 5 — Duplicate-key detection" "$SANITY" && ok "Pattern 5 section present" || fail "Pattern 5 section missing"
grep -qE "MULTIPLE_FRONTMATTER_BLOCKS.*UNCLOSED_FRONTMATTER.*INVALID_YAML.*DUPLICATE_KEYS_DIVERGENT_VALUES.*BROKEN_KEYS_INSIDE_COLON.*DUPLICATE_KEYS_IDENTICAL_VALUES" "$SANITY" && ok "verdict-priority ladder updated correctly" || fail "verdict-priority ladder missing or wrong order"
grep -q "Exception — divergent-value abort path" "$SANITY" && ok "idempotency exception clause present" || fail "idempotency exception clause missing"

# ─── Section [5/6] SKILL.md cross-references (4 launch-scope skills) ────────
echo "[5/6] SKILL.md cross-references"

for skill in property-enrich note-rename inbox-sort property-describe; do
  SKILL_FILE="${REPO_ROOT}/skills/${skill}/SKILL.md"
  count=$(grep -c "DUPLICATE_KEYS_DIVERGENT_VALUES\|duplicate-key-divergent-values" "$SKILL_FILE" || true)
  if [ "$count" -ge 2 ]; then
    ok "${skill}/SKILL.md references new verdict + finding category (${count} hits)"
  else
    fail "${skill}/SKILL.md missing new verdict references (${count} hits, need ≥ 2)"
  fi
done

# ─── Section [6/6] Grep-uniqueness — single-source-of-truth enforcement ─────
echo "[6/6] Grep-uniqueness"

# DUPLICATE_KEYS_DIVERGENT_VALUES verdict definition lives in yaml-sanity.md only.
# Skills + recipe-doc REFERENCE the verdict by name; they do not redefine it.
# Test: count occurrences of the literal "Verdict | Meaning | Action" table-style
# row defining the verdict — expect exactly 1.
verdict_def_count=$(grep -c "^| \`DUPLICATE_KEYS_DIVERGENT_VALUES\` |" "$SANITY")
if [ "$verdict_def_count" -eq 1 ]; then
  ok "DUPLICATE_KEYS_DIVERGENT_VALUES defined exactly once in yaml-sanity.md verdicts table"
else
  fail "DUPLICATE_KEYS_DIVERGENT_VALUES defined ${verdict_def_count} times (expected 1)"
fi

# Recipe-(f) Step 3 branching logic lives in yaml-edits.md only.
# Test: count occurrences of "ABORT recipe (f) for this file" — expect exactly 1
# (the canonical statement; worked example B references it but uses different wording).
abort_def_count=$(grep -c "ABORT recipe (f) for this file" "$EDITS")
if [ "$abort_def_count" -eq 1 ]; then
  ok "Recipe (f) ABORT clause defined exactly once in yaml-edits.md"
else
  fail "Recipe (f) ABORT clause defined ${abort_def_count} times in yaml-edits.md (expected 1)"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
echo
echo "──────────────────────────────────────────"
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
echo "──────────────────────────────────────────"

[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/test-recipe-f-duplicate-keys.sh
```

- [ ] **Step 3: Run the script (expect ALL sections green now — T2-T7 are merged before T8)**

```bash
./scripts/test-recipe-f-duplicate-keys.sh
```

Expected: All 6 sections PASS, exit code 0.

If any section fails, inspect the failing assertion, fix the upstream task, re-run. Do not modify the assertion to make it pass — fix the spec.

- [ ] **Step 4: Run W2 regression check (no breakage)**

```bash
./scripts/test-clone-cluster.sh && echo "W2 still green"
./scripts/test-windows-trailing-dot.sh && echo "W1 still green"
```

Both must still PASS — W4 must not regress earlier workstreams.

- [ ] **Step 5: Commit**

```bash
git add scripts/test-recipe-f-duplicate-keys.sh
git commit -m "test(v0.1.4 W4): T8 6-section assertion harness for recipe-(f) duplicate-key policy"
```

---

### Task 9: Add changelog row

**Files:**
- Modify: `logs/changelog.md`

- [ ] **Step 1: Add v0.1.4 W4 component row**

```bash
grep -n "v0.1.4" logs/changelog.md | head -10
```

Identify the v0.1.4 marker row from W2/W3. Add a new component row for W4 below it, matching the existing format.

Component row text:

```text
| W4 recipe-(f) duplicate-key policy | F7 close: divergent-value collisions ABORT recipe (f), file unchanged, Class-A finding "duplicate-key-divergent-values"; identical-value collisions silent-dedup as Class-D; new sanity-check verdicts `DUPLICATE_KEYS_DIVERGENT_VALUES` + `DUPLICATE_KEYS_IDENTICAL_VALUES`; Pattern 5 detection covers pre-existing plain duplicates universally (not only post-shape-β-normalize); 4 launch-scope SKILL.md routing tables updated; 5-cell fixture + 6-section assertion harness (`tests/fixtures/recipe-f-duplicate-keys/`, `scripts/test-recipe-f-duplicate-keys.sh`). |
```

- [ ] **Step 2: Commit**

```bash
git add logs/changelog.md
git commit -m "chore(v0.1.4 W4): T9 changelog row for recipe-(f) duplicate-key policy"
```

---

### Task 10: Final cross-cutting review + push + open PR

**Files:**
- (no edits — review-only + git operations)

- [ ] **Step 1: Re-run full assertion suite**

```bash
./scripts/test-recipe-f-duplicate-keys.sh
./scripts/test-clone-cluster.sh
./scripts/test-windows-trailing-dot.sh
```

All three: exit 0, all sections PASS.

- [ ] **Step 2: Verify branch state**

```bash
git log --oneline main..HEAD
```

Expected: 9 commits (T1 fixture, T2 yaml-sanity, T3 yaml-edits, T4-T7 four SKILL.md, T8 harness, T9 changelog).

- [ ] **Step 3: Push branch**

```bash
git push -u origin obi/v0.1.4-w4-recipe-f-duplicate-keys
```

- [ ] **Step 4: Open PR with greenfield-aware framing**

```bash
gh pr create \
  --title "feat(v0.1.4 W4): F7 recipe-(f) duplicate-key resolution policy" \
  --body "$(cat <<'EOF'
## Summary

Closes F7 (`status: ready-for-designer` overwritten by `status: draft` on `neckarshore.ai brand style guide brief.md`, GR-3 Cell 1, 2026-05-01). Replaces recipe-(f)'s silent "first wins" duplicate-key dedup with a divergent-value-aware policy.

## Behavior change

| Pre-W4 | Post-W4 |
|---|---|
| Recipe-(f) Step 3 unconditionally keeps first occurrence, removes rest, logs Class-D | Recipe-(f) Step 3 branches on value comparison: identical → silent dedup (Class-D, current happy path); divergent → ABORT, file unchanged, Class-A finding |
| Sanity-check returns `BROKEN_KEYS_INSIDE_COLON` for shape β, never inspects pre-existing plain duplicates | Sanity-check Pattern 5 inspects post-normalize view universally; new verdicts `DUPLICATE_KEYS_DIVERGENT_VALUES` (Class-A) + `DUPLICATE_KEYS_IDENTICAL_VALUES` (Class-D-aggregate, repairable) |
| F7 case silently kept `draft`, lost `ready-for-designer` | F7 case ABORTS, file unchanged, user sees Class-A finding "duplicate-key-divergent-values: status (observed values: draft, ready-for-designer)" |

This is a **behavior change**, not a refactor. Existing vaults with pre-existing plain-key duplicates that previously slipped through `OK` verdict will now hit the new verdicts. Recoverable in all paths: identical-value duplicates auto-dedup; divergent-value duplicates surface for user resolution (file content preserved).

## Scope

| Workstream | Files | LOC delta (approx.) |
|---|---|---|
| Spec — recipe-(f) Step 3 + worked examples | `references/yaml-edits.md` | +60 / -30 |
| Spec — sanity-check verdicts + Pattern 5 + matrix + idempotency | `references/yaml-sanity.md` | +90 / -15 |
| 4× SKILL.md routing tables | `skills/{property-enrich,note-rename,inbox-sort,property-describe}/SKILL.md` | +60 / -20 |
| Fixture | `tests/fixtures/recipe-f-duplicate-keys/` | +120 (5 md + truth.json + README) |
| Assertion harness | `scripts/test-recipe-f-duplicate-keys.sh` | +180 |
| Changelog | `logs/changelog.md` | +1 row |

## Test evidence

- `./scripts/test-recipe-f-duplicate-keys.sh` — 6/6 sections PASS, 5/5 fixture cells match `_truth.json`
- `./scripts/test-clone-cluster.sh` — W2 regression clean
- `./scripts/test-windows-trailing-dot.sh` — W1 regression clean

## MASCHIN decision-points

1. **Verdict-priority ordering:** new verdicts placed at `MULTIPLE_FRONTMATTER_BLOCKS > UNCLOSED_FRONTMATTER > INVALID_YAML > DUPLICATE_KEYS_DIVERGENT_VALUES > BROKEN_KEYS_INSIDE_COLON > DUPLICATE_KEYS_IDENTICAL_VALUES > OK_QUOTED > OK_NO_FRONTMATTER > OK`. Rationale in `references/yaml-sanity.md` § "Verdict-priority". Acceptable, or different ordering preferred?
2. **`property-describe` treatment of `DUPLICATE_KEYS_IDENTICAL_VALUES`:** Class-C (additive-only — defer to property-enrich). Could alternatively proceed normally (the duplicate values are identical → no semantic loss reading either). Class-C is the conservative choice (signals user that property-enrich should run first). Acceptable, or proceed-normally preferred?
3. **Empty-string value handling in Pattern 5:** empty values treated as identical to other empties, divergent vs any non-empty. Defensive default (signals incomplete user-stub). Acceptable, or empty-equals-anything preferred?

## Closes

- F7 (recipe-f duplicate-key resolution policy spec-clarification, B-Candidate, v0.1.4 P1)
- ship-plan §3 W4 (Roadmap VA-2)

## v0.1.4 progression

- W1 ✅ merged (#15) — F-NEW-A-1 Windows trailing-dot enumeration
- W2 ✅ merged (#16) — clone-cluster mode-shift unification
- W3 ✅ merged (#17) — F3 robocopy preflight
- **W4 (this PR)** — F7 recipe-(f) duplicate-key policy
- v0.1.4 ship PR (next) — version bump + ROADMAP + README cross-check
EOF
)"
```

- [ ] **Step 5: Verify PR opened**

```bash
gh pr view --json number,url,state -q '{number: .number, url: .url, state: .state}'
```

Expected: state OPEN, valid URL.

- [ ] **Step 6: Update report-tracking notes**

Capture PR-URL, commit count, fixture-cell count for the session-close report. Done.

---

## Self-Review

**1. Spec coverage:**
- Ship-plan §3 W4 acceptance criteria:
  - "recipe-f behavior on divergent-value duplicates is documented in `references/yaml-edits.md`" → T3 ✅
  - "Behavior is exercised by fixture test (pass = chosen policy executed; fail = old 'first wins' silent behavior)" → T1 fixture + T8 assertion harness ✅
  - "Findings-file entry (under policy (c)) follows existing `references/findings-file.md` convention" → spec-only — finding-category `duplicate-key-divergent-values` follows existing kebab-case convention; no findings-file.md edit needed ✅
  - "No regression on identical-value duplicates (control case still resolves silently)" → cell B + cell D in T1 + T8 ✅
- Advisor points:
  - #1 worked-example contradiction → T3 Step 2 replaces example ✅
  - #2 fixpoint contract → T2 Step 5 amends with exception clause + new verdict propagated ✅
  - #3 SKILL.md call-sites → T4-T7 ✅
  - #4 pre-existing plain duplicates → cells C + D in T1 + Pattern 5 in T2 ✅
  - #5 class severity explicit → "Class-A territory" in T2 verdicts table + "Class-A finding" in T4-T7 ✅
  - #6 5-cell fixture → T1 ✅

**2. Placeholder scan:** No "TBD" / "TODO" / "implement later" in any task. T7 has a partial `old_string` requiring inspection of current `property-describe/SKILL.md` (parallel to T4-T6 pattern); this is bounded — implementer reads file, applies pattern verbatim from the spec text in T7 Step 2.

**3. Type consistency:** Verdict names used consistently — `DUPLICATE_KEYS_DIVERGENT_VALUES` (capital D, plural KEYS, plural VALUES) and `DUPLICATE_KEYS_IDENTICAL_VALUES` everywhere. Finding category `duplicate-key-divergent-values` (lowercase + kebab) consistently. Recipe-(f) and recipe (f) — current spec uses both interchangeably; plan uses recipe (f) outside parenthetical-headings to match existing prose. No drift.

**4. Risk: T7 partial old_string.** Mitigation: T7 Step 1 is a `grep -n` to locate the existing block; Step 2 applies the verbatim pattern. Same pattern as W2's T7 (which was clean).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-07-w4-recipe-f-duplicate-keys.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review (spec compliance + code quality) per task, ~3-4 min per task. Mirrors W2 (12 commits / 25 min for 4 SKILL.md edits).
2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints for review.

**Which approach?**
