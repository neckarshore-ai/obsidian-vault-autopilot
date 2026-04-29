---
created: 30.01.2026, 17:02:59
modified: {{ISO_DATE}}
title: F2 German-Date Repro
tags:
  - VaultAutopilot
---

# F2 German-Date Repro

This file reproduces F2 (German DACH-locale `DD.MM.YYYY[, HH:mm:ss]` date
format in YAML `created`).

Pre-v0.1.3 (buggy): property-enrich Source Hierarchy Prio 1 only accepted ISO
8601. The German format `30.01.2026, 17:02:59` is not parseable as ISO → falls
through to Prio 2-4 (filename / git / birthtime). On a cloned vault, birthtime
is "now" → `created` would be misreported (or worse, appended-as-new-line below
the existing unparseable one).

Post-v0.1.3 (fixed): German-date normalization in Source Hierarchy Prio 1 (per
`references/german-date-normalization.md`) produces ISO `2026-01-30T17:02:59`
for internal use. The YAML value is preserved as-authored (additive-only
contract — `created` is never overwritten by property-enrich).

`modified` is refreshed via filesystem mtime (the only Always-overwrite field
per existing SKILL spec).

Expected post-enrich frontmatter:

```yaml
---
created: 30.01.2026, 17:02:59
modified: 2026-04-29
title: F2 German-Date Repro
tags:
  - VaultAutopilot
---
```

(`modified` value depends on actual filesystem mtime at run-time. `created`
preserved as-authored.)

Sanity-check verdict on this file: `OK` (no quoted-keys at all).

> [!info] Vault Autopilot
>
> | Date | Skill | Action |
> |------|-------|--------|
> | {{TIMESTAMP}} | property-enrich | Added title from filename, modified from mtime; created Source = YAML (German-date-normalized) |
