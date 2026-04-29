---
"created:": 2024-03-14
"description": Standard quoted-key (shape alpha — should NOT be touched by recipe f)
title: Mixed shapes
---

# F26 Mixed Shapes Repro

This file mixes shape α and shape β to verify recipe (f) only touches β.

- Line 1 `"created:"` is shape β (inside-colon + outside-colon). Recipe (f) MATCHES.
- Line 2 `"description"` is shape α (no inside-colon, just outside-colon). Recipe (f) MISSES (on purpose).
- Line 3 `title:` is plain.

Expected behavior on property-enrich Step 2a:

1. Sanity-check verdict: `BROKEN_KEYS_INSIDE_COLON` (line 1 is β).
2. Recipe (f) normalizes line 1: `"created:"` → `created`. Line 2 untouched.
3. Re-call sanity-check on result: verdict `OK_QUOTED` (shape α still present
   on `"description"`, valid YAML — no further repair needed).
4. Skill proceeds normally.

Expected post-enrich frontmatter:

```yaml
---
created: 2024-03-14
"description": Standard quoted-key (shape alpha — should NOT be touched by recipe f)
title: Mixed shapes
tags:
  - VaultAutopilot
---
```

(plus skill-log callout appended)
