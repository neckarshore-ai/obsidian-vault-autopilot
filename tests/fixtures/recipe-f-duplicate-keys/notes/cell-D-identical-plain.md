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
