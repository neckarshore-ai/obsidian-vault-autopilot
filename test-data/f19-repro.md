---
"created:": 2024-03-14
"modified:": 2024-03-14
title: F19 Quoted-Key Repro
tags:
  - AppleNoteImport
---

# F19 Quoted-Key Repro

This file reproduces F19 (LIVE-CONFIRMED in GR-2 Cell 1, 2026-04-28).

property-enrich Step 2a should detect the inside-colon quoted-keys via
sanity-check (verdict `BROKEN_KEYS_INSIDE_COLON`), normalize via recipe (f),
then proceed normally. Without v0.1.3 fix, property-enrich missed these and
appended new `created:` / `modified:` lines below the broken originals →
duplicate-key corruption.

Both `"created:"` and `"modified:"` are shape β (inside-colon AND outside-colon).
Recipe (f)'s `F26_INSIDE_COLON_PATTERN` matches both.

Expected post-enrich frontmatter:

```yaml
---
created: 2024-03-14
modified: 2024-03-14
title: F19 Quoted-Key Repro
tags:
  - AppleNoteImport
  - VaultAutopilot
---
```

(plus skill-log callout appended at end of body per `references/skill-log.md`)

Sanity-check verdict on this file (pre-normalize): `BROKEN_KEYS_INSIDE_COLON`.
After Step 2a normalize, re-running sanity-check returns `OK`.
