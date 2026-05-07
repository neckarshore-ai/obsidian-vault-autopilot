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
