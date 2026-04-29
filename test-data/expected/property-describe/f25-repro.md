---
created: 2024-03-14
"description": A pre-existing description with standard quoted-key shape
tags:
  - SomeTag
---

# F25 Filter-Regex Repro

This file reproduces F25 (Class-A near-miss, caught by Pre-Run-Memo Stop in
GR-2 Cell 4, 2026-04-28).

**Shape α — standard quoted-key** (no inside-colon). Valid YAML. The fix is
filter-regex broadening, NOT skip-with-finding.

Pre-v0.1.3 (buggy): property-describe filter regex `^([A-Za-z_]...)\s*:` only
matched plain keys, missed `"description":` standard quoted form, treated
description as missing, flagged file as eligible. Without Pre-Run-Memo Stop,
would have written NEW `description:` line below the existing → duplicate-key.

Post-v0.1.3 (fixed): broadened filter regex matches both plain identifier
AND standard quoted-key shape (per `references/yaml-sanity.md` + property-describe
SKILL.md Step 2b). File correctly recognized as having description, length 65 ≥ 10
→ eligible-skip "already has description".

Sanity-check verdict on this file: `OK_QUOTED` (standard quoted-key, valid
YAML, no inside-colon). Skill proceeds. NO repair, NO sanity-check skip.

Expected post-describe state: BYTE-IDENTICAL to input (skill skipped — eligible-skip,
no write).
