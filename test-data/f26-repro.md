---
"created:": 2024-03-14
created: 2025-01-01
"modified:": 2024-06-15
"description:": Apple Notes export
"tags:": []
---

# F26 Cross-Skill Cluster Repro (shape β only)

This file reproduces F26 (LIVE-REPRODUCED in GR-2 Cell 4, 60 of 1016 inbox-tree
files = 5.9% blast-radius cross-skill).

**Shape β — inside-colon quoted-keys** (Apple-Notes-Vintage import artifact).
Invalid-as-author-intended. Recipe (f) normalize required.

This file has multiple inside-colon quoted-keys AND a duplicate-collision (both
`"created:"` and `created` exist).

All four quoted lines have inside-colon shape (`":` before closing quote AND `:`
after). Recipe (f) `F26_INSIDE_COLON_PATTERN` matches all four.

Expected behavior on property-enrich Step 2a:

1. Sanity-check verdict: `BROKEN_KEYS_INSIDE_COLON` (4 inside-colon lines).
2. Walk lines, apply recipe (f) per-line:
   - `"created:"` → `created`, `"modified:"` → `modified`,
     `"description:"` → `description`, `"tags:"` → `tags`.
3. Duplicate-collision: TWO `created:` lines now exist (line 1 normalized-from-
   quoted, line 2 already-plain).
4. Per recipe (f) policy: keep first (= the normalized-from-quoted, value
   `2024-03-14`), remove second. Log Class-D finding "duplicate-key removed:
   created (kept original quoted-form value 2024-03-14, removed plain-form
   value 2025-01-01)".
5. Re-run sanity-check (idempotent fixpoint): verdict now `OK`. Proceed.

Expected post-enrich frontmatter:

```yaml
---
created: 2024-03-14
modified: 2024-06-15
description: Apple Notes export
tags: []
---
```

Note: empty `tags: []` becomes block-format `tags:\n  - VaultAutopilot` after
skill-log Nahbereich (per skill-log.md tag-format-rules — convert inline `[]`
to block).
