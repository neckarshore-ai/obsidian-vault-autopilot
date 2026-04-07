# Expected Outcomes — inbox-sort Test Data

## How to Use (Master/Copy Pattern)

1. Copy `vault/` to a temporary location: `cp -R vault/ /tmp/inbox-sort-test/`
2. Set `export OBSIDIAN_VAULT_PATH=/tmp/inbox-sort-test`
3. Set birthtimes on all files to > 3 days ago, EXCEPT `Fresh Idea from Today.md` (keep recent)
4. Run inbox-sort skill with `cooldown_days=3`
5. Compare results against this manifest
6. Delete the copy after verification. Master data in `vault/` stays untouched.

Repeat for each test run. Add new test files to `vault/` and update this manifest as needed.

---

## Outcomes

| # | File | Action | Destination | Routing Rule | Notes |
|---|------|--------|-------------|-------------|-------|
| A1 | `2026-03-15.md` | Move | `Inbox/daily/` | Pre-sort: YYYY-MM-DD pattern | |
| A2 | `2026-03-20 Friday Reflection.md` | Move | `Inbox/daily/` | Pre-sort: YYYY-MM-DD *.md pattern | |
| B1 | `How to Build a CLI Tool.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: `source:` URL in frontmatter | |
| B2 | `Obsidian Plugins Worth Trying.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: `clippings` tag in frontmatter | |
| B3 | `Serverless Architecture Patterns.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: inline `#clippings` in body | |
| C1 | `Interesting Thread on AI Agents.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: bare link to x.com | |
| C2 | `Leadership Post from CEO.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: bare link to linkedin.com | |
| D1 | `API Rate Limiting Strategy.md` | Move | `Inbox/_Work/` | Categorize: dev/engineering content | |
| D2 | `Client Onboarding Checklist.md` | Move | `Inbox/_Work/` | Categorize: business/client management | |
| D3 | `Content Calendar Q2.md` | Move | `Inbox/_Work/` | Categorize: content creation/marketing | |
| D4 | `Meeting Notes - Product Roadmap.md` | Move | `Inbox/_Work/` | Categorize: product meeting notes | |
| E1 | `Morning Routine Overhaul.md` | Move | `Inbox/_Personal/` | Categorize: health/habits | |
| E2 | `Summer Vacation Planning.md` | Move | `Inbox/_Personal/` | Categorize: family/travel | |
| E3 | `Home Office Desk Setup.md` | Move | `Inbox/_Personal/` | Categorize: household purchases | |
| E4 | `Monthly Budget Review March.md` | Move | `Inbox/_Personal/` | Categorize: personal finance | |
| F1 | `Career Development Plan 2026.md` | Move | `Inbox/_Edge Cases/` | Categorize: ambiguous work/personal | |
| F2 | `Book Notes - Thinking in Systems.md` | Move | `Inbox/_Edge Cases/` | Categorize: ambiguous domain application | |
| F3 | `Networking Event Notes.md` | Move | `Inbox/_Edge Cases/` | Categorize: mixed business/personal contacts | |
| G1 | `Untitled.md` | Delete | (removed) | Nahbereich: 0-byte file | Permanently deleted, not trashed |
| G2 | `Quick Thought.md` | Delete | (removed) | Nahbereich: 0-byte file | Permanently deleted, not trashed |
| G3 | `Draft Ideas.md` | Trash | `_trash/` | Nahbereich: whitespace-only | Verify trash metadata (trashed date, trash_source, trash_origin) |
| H1 | `meeting-photo.png` | Skip | (unchanged) | Non-markdown file | Remains in Inbox root |
| H2 | `project-brief.pdf` | Skip | (unchanged) | Non-markdown file | Remains in Inbox root |
| H3 | `Fresh Idea from Today.md` | Skip | (unchanged) | Cooldown: created < 3 days ago | Remains in Inbox root |
| I1 | `Notes & Thoughts (Brainstorm).md` | Move | `Inbox/_Work/` | Categorize: work/automation content | Verify `mv` handles `&` and `()` correctly |
| I2 | `broken-frontmatter.md` | Move | `Inbox/_Work/` | Categorize: market research content | Should appear in Report Findings (broken YAML: no closing `---`) |
| J1 | `Crypto Wallet Setup.md` | Move | `Inbox/_Work/` | Categorize: crypto/dev content | Should appear in Report Findings (sensitive data: recovery phrase). NOT moved to `_secret` — flag only. |

---

## Expected Report Summary

```
_Work: 7 notes moved (D1-D4, I1, I2, J1)
_Personal: 4 notes moved (E1-E4)
_Edge Cases: 3 notes moved (F1-F3)
WebCaptures & Social: 5 notes moved (B1-B3, C1-C2)
Daily: 2 notes moved (A1-A2)
Nahbereich: 3 files removed (0-byte deleted: 2, whitespace-only trashed: 1)
Skipped — Cooldown: 1 note (H3)
Skipped — Non-markdown: 2 files (H1, H2)
Findings: 1 broken frontmatter (I2), 1 sensitive data warning (J1)
```

Total processed: 21 notes moved + 3 cleanup + 3 skipped = 27 files accounted for

---

## Structural Verification

### Auto-Creation (buckets must NOT pre-exist)

- [ ] `Inbox/_Work/` was created by the skill
- [ ] `Inbox/_Personal/` was created by the skill
- [ ] `Inbox/_Edge Cases/` was created by the skill
- [ ] `Inbox/WebCaptures & Social/` was created by the skill

### Protected Files

- [ ] `_vault-autopilot.md` was NOT moved, renamed, or modified

### Skill Log (per moved file)

- [ ] `VaultAutopilot` tag added to YAML frontmatter
- [ ] Skill log callout appended with date, skill name, and action

### Trash Metadata (G3 only)

- [ ] `Draft Ideas.md` exists in `_trash/`
- [ ] Has `trashed` date in frontmatter
- [ ] Has `trash_source: inbox-sort` in frontmatter
- [ ] Has `trash_origin` path in frontmatter

---

## Routing Review Notes

Observations from designing the test data. These are NOT bugs — they are input for v0.2.0 configurability.

### ~~1. Web Captures always route to `_Work`~~ RESOLVED

Now routes to `WebCaptures & Social` bucket.

### ~~2. Social Posts always route to `_Work`~~ RESOLVED

Now routes to `WebCaptures & Social` bucket.

### 3. "Home Office" ambiguity

Test file E3 is categorized as `_Personal` (household purchases). But for freelancers and self-employed users, home office equipment is a business expense. The skill cannot know the user's employment context. Acceptable for v0.1.0 — user can override at preview.

### 4. Daily note pattern is strict

Only `YYYY-MM-DD.md` and `YYYY-MM-DD *.md` are detected. Users with `DD.MM.YYYY`, `YYYY/MM/DD`, or `March 15, 2026` patterns will not be caught. Configurable in v0.2.0 via `date_format` attribute.

### 5. Bare-link threshold is undefined

Web-capture-detection says "bare-link note (just a URL, no real content)." But what counts as "no real content"? URL + one-line comment — bare or not? A future test file should probe this boundary (URL + 1 sentence vs. URL + 3 paragraphs).
