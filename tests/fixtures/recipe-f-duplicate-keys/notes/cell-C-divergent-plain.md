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
