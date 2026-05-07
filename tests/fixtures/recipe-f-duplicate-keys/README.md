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
