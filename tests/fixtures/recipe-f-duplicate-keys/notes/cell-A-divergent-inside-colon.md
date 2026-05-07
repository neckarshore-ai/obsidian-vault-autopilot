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
