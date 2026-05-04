# Run History

Shared run history for the obsidian-vault plugin. Every skill run logs one row here.

| Date | Skill | Scope | Scanned | Processed | Skipped | Findings |
|------|-------|-------|---------|-----------|---------|----------|
| 2026-05-01 | property-enrich | GR-4 Cell 1 — inbox-tree | inbox tree | 312 enriched (created, title, modified); F26 repair on 75 files | — | 0 Class-A |
| 2026-05-01 | note-rename | GR-4 Cell 2 — inbox root | inbox root | 10 renames + 2 soft-deletes; 2 corrupted files labeled | — | 0 Class-A |
| 2026-05-01 | inbox-sort | GR-4 Cell 3 — inbox root | inbox root | 131 files: 125 moved (web=28, work=65, personal=11, edge=21), 2 attachments, 6 cooldown-skipped | 1 error (curly-quote filename, fixed post-run) | 4 findings (F1 Mixed-Content cluster, F2 3 corrupted→_Edge, F3 secret-scan clear, F4 cooldown) |
| 2026-05-01 | property-describe | GR-4 Cell 4 — vault (probe) | vault | 8/8 descriptions written, 0 F1-skipped, 0 errors | 420 eligible of 1,395 checked | F1 near-miss check: 0 hits |
| 2026-05-01 | property-enrich | 099_Archive folder | folder:099_Archive | 27/27 written, 0 errors — title+created (birthtime)+modified added; VaultAutopilot tag; skill-log callout |
| 2026-05-01 | property-describe | 099_Archive folder | folder:099_Archive | 18/18 descriptions written, 5 F1-skipped (existing desc), 0 errors (1 curly-quote filename fixed inline) | — | — |
