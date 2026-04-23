# Expected Outcomes — Launch Flow Test

The launch flow runs four phases in order and verifies that note-rename and inbox-sort compose correctly, that the skill log is idempotent, and that birthtime preservation works across multiple skill runs on the same note.

**Flow:** `note-rename Run 1 → inbox-sort → manual rename 2 files → note-rename Run 2`

**Why rename-first:** The filename is a primary routing signal for inbox-sort. Running note-rename first increases signal quality before the sort happens, and the two skills compose cleanly if the order is respected.

---

## How to Use (Master/Clone Pattern)

1. **Clone master data into a timestamped test vault:**
   ```bash
   TS=$(date +"%Y-%m-%d %H-%M")
   mkdir -p ~/Vaults/"$TS test-obsidian-vault-autopilot"
   cp -R "test-data/Test Management/inbox-sort/vault/"* ~/Vaults/"$TS test-obsidian-vault-autopilot/"
   export OBSIDIAN_VAULT_PATH=~/Vaults/"$TS test-obsidian-vault-autopilot"
   ```
   Naming convention: `YYYY-MM-DD HH-MM test-obsidian-vault-autopilot` — allows multiple runs per day. Clones live directly in `~/Vaults/` so Obsidian can inspect them in real time. Master data in `vault/` stays untouched.

2. **Set dates on the cloned vault:**
   a. Set birthtimes on all inbox files to > 3 days ago:
      ```bash
      cd "$OBSIDIAN_VAULT_PATH/Inbox" && for f in *; do touch -t 202604060900 "$f"; done
      ```
   b. `Fresh Idea from Today.md` — set YAML `created` to yesterday:
      ```bash
      sed -i '' "s/created: DYNAMIC/created: $(date -v-1d +%Y-%m-%dT%H:%M)/" "Fresh Idea from Today.md"
      ```
   c. `Edited Old Note.md` — restore fresh birthtime (simulates an APFS inode reset). YAML `created` (2026-02-20) must conflict with birthtime (today). This is the birthday bug test.
   d. `No Dates Note.md` — birthtime was set in step 2a (old), no YAML `created`. Tests the filesystem fallback path.

3. **Run the four phases in order.** After each phase, verify vault state against the phase table below before proceeding.

4. **Do not reuse a test vault across test runs.** Each run starts from a fresh clone.

---

## Phase 1 — note-rename Run 1

**Command:** run `note-rename` skill with `scope=inbox`, `cooldown_days=3`.

### Expected Actions per File

| # | File | Action | New Name / Destination | Rule |
|---|------|--------|------------------------|------|
| 1 | `2026-03-15.md` | **Daily (Nahbereich)** | `Inbox/daily/2026-03-15.md` | Pure daily pattern (`YYYY-MM-DD.md`). note-rename's Daily Note Detection moves misplaced daily notes to the canonical Daily Notes folder. Skill-log callout: `Daily — moved to Daily Notes folder`. |
| 2 | `2026-03-20 Friday Reflection.md` | Reviewed | (unchanged) | Hybrid name (date + description) — not a pure daily pattern. Descriptive. |
| 3 | `API Rate Limiting Strategy.md` | Reviewed | (unchanged) | Already descriptive |
| 4 | `Book Notes - Thinking in Systems.md` | Reviewed | (unchanged) | Already descriptive |
| 5 | `broken-frontmatter.md` | Reviewed | (unchanged) | **Edge case:** filename is descriptive. YAML repair "no closing `---`" is NOT in note-rename's allow-list (see SKILL.md:14). Must be flagged under Findings but left as-is. |
| 6 | `Career Development Plan 2026.md` | Reviewed | (unchanged) | Already descriptive |
| 7 | `Client Onboarding Checklist.md` | Reviewed | (unchanged) | Already descriptive |
| 8 | `Content Calendar Q2.md` | Reviewed | (unchanged) | Already descriptive |
| 9 | `Crypto Wallet Setup.md` | **Secret (Nahbereich)** | `_secret/Crypto Wallet Setup.md` | Sensitive content detection: body contains recovery-phrase / seed keywords. note-rename's Sensitive Content Detection moves the note to `_secret/` with `trash_source: note-rename`, `trash_origin: Inbox/Crypto Wallet Setup.md`. Skill-log callout: `Secret — sensitive content (moved to _secret/)`. |
| 10 | `Draft Ideas.md` | **Trashed** | `_trash/Draft Ideas.md` | Accidental note: generic name + whitespace-only content. `trash_source: note-rename` |
| 11 | `Edited Old Note.md` | **Renamed** | TBD (content-based, verify at run) | Generic name, has content. Exact new name not predicted — assertion is "was renamed to a descriptive name". |
| 12 | `Fresh Idea from Today.md` | **Skipped** | (unchanged) | Cooldown: YAML `created` = yesterday (< 3 days). Generic-ish name, but cooldown wins. |
| 13 | `Home Office Desk Setup.md` | Reviewed | (unchanged) | Already descriptive |
| 14 | `How to Build a CLI Tool.md` | Reviewed | (unchanged) | Already descriptive |
| 15 | `Interesting Thread on AI Agents.md` | Reviewed | (unchanged) | Descriptive, even though content is a bare link |
| 16 | `Leadership Post from CEO.md` | Reviewed | (unchanged) | Descriptive |
| 17 | `Meeting Notes - Product Roadmap.md` | Reviewed | (unchanged) | Descriptive |
| 18 | `meeting-photo.png` | (not processed) | (unchanged) | Non-markdown. note-rename does not touch it. |
| 19 | `Monthly Budget Review March.md` | Reviewed | (unchanged) | Descriptive |
| 20 | `Morning Routine Overhaul.md` | Reviewed | (unchanged) | Descriptive |
| 21 | `Networking Event Notes.md` | Reviewed | (unchanged) | Descriptive |
| 22 | `No Dates Note.md` | **Renamed** | TBD (content-based, verify at run) | Generic name, has content. Fallback test: no YAML `created`, uses birthtime for cooldown. |
| 23 | `Notes & Thoughts (Brainstorm).md` | Reviewed | (unchanged) | Descriptive enough. Filename has `&` and `()` — verify quoting does not break skill log write. |
| 24 | `Obsidian Plugins Worth Trying.md` | Reviewed | (unchanged) | Descriptive |
| 25 | `project-brief.pdf` | (not processed) | (unchanged) | Non-markdown |
| 26 | `Quick Thought.md` | **Trashed** | `_trash/Quick Thought.md` | Accidental note: 0 bytes, generic name. `trash_source: note-rename`. **Key difference vs. inbox-sort:** note-rename soft-deletes 0-byte files, inbox-sort permadeletes them. |
| 27 | `Serverless Architecture Patterns.md` | Reviewed | (unchanged) | Descriptive |
| 28 | `Summer Vacation Planning.md` | Reviewed | (unchanged) | Descriptive |
| 29 | `Untitled.md` | **Trashed** | `_trash/Untitled.md` | Accidental note: 0 bytes, generic name in the explicit list. `trash_source: note-rename`. |

### Phase 1 Report Summary (expected)

```
Renamed: 2 notes (Edited Old Note, No Dates Note)
Reviewed: 20 notes (descriptive names, skill log row added)
Daily (Nahbereich): 1 note (2026-03-15.md → Inbox/daily/)
Secret (Nahbereich): 1 note (Crypto Wallet Setup.md → _secret/)
Trashed (Nahbereich): 3 notes (Untitled.md, Quick Thought.md, Draft Ideas.md → _trash/)
Skipped (cooldown): 1 note (Fresh Idea from Today.md)
Not processed (non-markdown): 2 files (meeting-photo.png, project-brief.pdf)
Findings: 1 broken frontmatter (broken-frontmatter.md: missing closing ---)
```

Total accounted for: 2 + 20 + 1 + 1 + 3 + 1 + 2 = **30 files**.

### Phase 1 Verification

- [ ] `_trash/` contains `Untitled.md`, `Quick Thought.md`, `Draft Ideas.md`
- [ ] Each trashed file has YAML `trashed`, `trash_source: note-rename`, `trash_origin: Inbox/...`
- [ ] `_secret/` contains `Crypto Wallet Setup.md` with `trash_source: note-rename`, `trash_origin: Inbox/Crypto Wallet Setup.md`
- [ ] `Inbox/daily/` contains `2026-03-15.md` with `Daily — moved to Daily Notes folder` callout row
- [ ] `Edited Old Note.md` no longer exists — the renamed file does
- [ ] `No Dates Note.md` no longer exists — the renamed file does
- [ ] Every reviewed/renamed/daily/secret file has `VaultAutopilot` tag (exactly once) in frontmatter
- [ ] Every reviewed/renamed/daily/secret file has exactly ONE `> [!info] Vault Autopilot` callout at the end, with one data row
- [ ] `broken-frontmatter.md` is in the Findings section of the Phase 1 report
- [ ] `Fresh Idea from Today.md` still in `Inbox/` root, untouched

---

## Phase 2 — inbox-sort

**Command:** run `inbox-sort` skill with `cooldown_days=3`.

Input: state after Phase 1. Three accidental notes are in `_trash/`, one sensitive note is in `_secret/`, and one daily note is already in `Inbox/daily/`. 21 markdown files + 2 attachments remain at the inbox root to be sorted (plus the cooldown-skip file, which stays in inbox root).

### Expected Actions per File

Phase 2 processes files still at the inbox root. Files handled by Phase 1's Nahbereich (trash / secret / daily) are already gone and not listed here.

| # | File (post-Phase-1 name) | Action | Destination | Routing Rule |
|---|--------------------------|--------|-------------|--------------|
| 1 | `2026-03-20 Friday Reflection.md` | Move | `Inbox/daily/` | Pre-sort: `YYYY-MM-DD *.md` pattern |
| 2 | `How to Build a CLI Tool.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: `source:` URL in frontmatter |
| 3 | `Obsidian Plugins Worth Trying.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: `clippings` tag in frontmatter |
| 4 | `Serverless Architecture Patterns.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: inline `#clippings` in body |
| 5 | `Interesting Thread on AI Agents.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: bare link to x.com |
| 6 | `Leadership Post from CEO.md` | Move | `Inbox/WebCaptures & Social/` | Pre-sort: bare link to linkedin.com |
| 7 | `API Rate Limiting Strategy.md` | Move | `Inbox/_Work/` | Categorize: dev/engineering |
| 8 | `Client Onboarding Checklist.md` | Move | `Inbox/_Work/` | Categorize: business/client management |
| 9 | `Content Calendar Q2.md` | Move | `Inbox/_Work/` | Categorize: content/marketing |
| 10 | `Meeting Notes - Product Roadmap.md` | Move | `Inbox/_Work/` | Categorize: product meeting |
| 11 | `Notes & Thoughts (Brainstorm).md` | Move | `Inbox/_Work/` | Categorize: work/automation. Verify `mv` handles `&` and `()`. |
| 12 | `broken-frontmatter.md` | Move | `Inbox/_Work/` | Categorize: market research. Also reported under Findings (broken YAML). |
| 13 | `Edited Old Note.md` *(or its Phase 1 renamed form — e.g. `Microservices - Communication Patterns.md`)* | Move | `Inbox/_Work/` | **Birthday bug test:** YAML `created` is old (2026-02-20), birthtime was fresh. YAML wins → processed. Categorize: dev/architecture. |
| 14 | `No Dates Note.md` *(or its Phase 1 renamed form — e.g. `Focus Timer - Techniques.md`)* | Move | `Inbox/_Personal/` | **Fallback test:** no YAML `created`, birthtime (old) used for cooldown. Categorize: productivity/habits (deep-work routines). See Routing Review Notes. |
| 15 | `Morning Routine Overhaul.md` | Move | `Inbox/_Personal/` | Categorize: health/habits |
| 16 | `Summer Vacation Planning.md` | Move | `Inbox/_Personal/` | Categorize: family/travel |
| 17 | `Home Office Desk Setup.md` | Move | `Inbox/_Personal/` | Categorize: household purchases |
| 18 | `Monthly Budget Review March.md` | Move | `Inbox/_Personal/` | Categorize: personal finance |
| 19 | `Career Development Plan 2026.md` | Move | `Inbox/_Edge Cases/` | Categorize: ambiguous work/personal |
| 20 | `Book Notes - Thinking in Systems.md` | Move | `Inbox/_Edge Cases/` | Categorize: ambiguous domain |
| 21 | `Networking Event Notes.md` | Move | `Inbox/_Edge Cases/` | Categorize: mixed business/personal |
| 22 | `meeting-photo.png` | Move | `Inbox/_Attachments/` | Pre-sort: non-markdown (image) |
| 23 | `project-brief.pdf` | Move | `Inbox/_Attachments/` | Pre-sort: non-markdown (PDF) |
| 24 | `Fresh Idea from Today.md` | Skip | (unchanged) | Cooldown: YAML `created` < 3 days ago |

### Phase 2 Report Summary (expected)

```
_Work: 7 notes moved
_Personal: 5 notes moved
_Edge Cases: 3 notes moved
WebCaptures & Social: 5 notes moved
daily: 1 note moved
_Attachments: 2 files moved
Nahbereich: 0 files removed  <-- KEY DIFFERENCE vs. inbox-sort-solo: Phase 1 already handled trash/secret/daily
Skipped (cooldown): 1 note (Fresh Idea from Today.md)
Findings: 1 broken frontmatter (broken-frontmatter.md)
```

Total processed: 21 notes moved + 2 attachments moved + 1 cooldown skip = **24 items accounted for**.

Checksum: 30 total - 3 trashed (P1 Nahbereich) - 1 secret (P1 Nahbereich) - 1 daily (P1 Nahbereich) - 1 cooldown skip = 24 items Phase 2 routes out of the inbox root. ✓

### Phase 2 Verification

- [ ] `Inbox/_Work/`, `Inbox/_Personal/`, `Inbox/_Edge Cases/`, `Inbox/WebCaptures & Social/`, `Inbox/_Attachments/` all auto-created
- [ ] Nahbereich counter in report is 0 (NOT 3 — Phase 1 already handled accidentals)
- [ ] `_vault-autopilot.md` at vault root was not moved, renamed, or modified
- [ ] The 2 files that were renamed in Phase 1 (e.g. `Microservices - Communication Patterns.md`, `Focus Timer - Techniques.md`) each have exactly ONE `> [!info] Vault Autopilot` callout block with **2 data rows** (P1 Renamed + P2 Moved) — row appended, no second block created
- [ ] The other 19 moved `.md` files each have exactly ONE `> [!info] Vault Autopilot` callout block with **1 data row** (P2 Moved only)
- [ ] Every moved `.md` file has `VaultAutopilot` tag exactly once in frontmatter (not duplicated)
- [ ] Birthday bug: `Edited Old Note.md` (or renamed form) was processed, not skipped — routed to `_Work/`
- [ ] Fallback: `No Dates Note.md` (or renamed form) was processed — routed to `_Personal/`

---

## Phase 3 — Manual Rename (Simulate User Error)

**Purpose:** create rename candidates in `Inbox/_Work/` that already carry a two-row skill-log callout. This sets up Phase 4 to test the callout-append path.

**Action (manual, by the user):**

```bash
cd "$OBSIDIAN_VAULT_PATH/Inbox/_Work"
mv "Client Onboarding Checklist.md" "Unbekannt.md"
mv "Content Calendar Q2.md" "Neue Notiz.md"
```

**Why these two:**
- Both have unambiguous content that cleanly maps to a descriptive new name in Phase 4.
- Neither participates in the birthday-bug or fallback test paths.
- Neither is the broken-frontmatter file or the sensitive-data file.

### Phase 3 Verification

- [ ] `Inbox/_Work/Unbekannt.md` exists, has the original Client Onboarding content
- [ ] `Inbox/_Work/Neue Notiz.md` exists, has the original Content Calendar content
- [ ] Both files still have their original `VaultAutopilot` tag (exactly once)
- [ ] Both files still have their original Vault Autopilot callout with **2 rows** (Phase 1 Reviewed + Phase 2 Moved)
- [ ] No other files in `_Work/` were touched

---

## Phase 4 — note-rename Run 2

**Command:** run `note-rename` skill with `scope=folder:Inbox/_Work`, `cooldown_days=3`.

Scope must be explicit — the default `scope=inbox` scans only the inbox root, and the two candidates now live in `Inbox/_Work/`.

### Expected Actions per File (in the target folder)

| # | File | Action | New Name | Rule |
|---|------|--------|----------|------|
| 1 | `Unbekannt.md` | **Renamed** | TBD (content-based, verify at run) | Generic name in the rename-candidate list (`Unbenannt` is the German variant) |
| 2 | `Neue Notiz.md` | **Renamed** | TBD (content-based, verify at run) | Generic "new note" pattern |
| 3 | All other `_Work/` files | Reviewed | (unchanged) | Descriptive names. Get a THIRD callout row. |

**Assertion — the critical one:**

For `Unbekannt.md` and `Neue Notiz.md`, the existing `> [!info] Vault Autopilot` callout must receive a **third data row** appended to the same callout block. There must NOT be a second callout block. This is the infobox-append idempotency test.

### Phase 4 Report Summary (expected)

```
Renamed: 2 notes (Unbekannt.md, Neue Notiz.md → new descriptive names)
Reviewed: 5 notes (remaining _Work/ files — _Work has 7 total, minus the 2 rename candidates)
Trashed (Nahbereich): 0
Skipped (cooldown): 0
Findings: 1 broken frontmatter (broken-frontmatter.md — still flagged, still not auto-fixed)
```

### Phase 4 Verification

- [ ] `Unbekannt.md` no longer exists in `_Work/` — a renamed file does
- [ ] `Neue Notiz.md` no longer exists in `_Work/` — a renamed file does
- [ ] Both renamed files have exactly ONE `VaultAutopilot` tag in frontmatter (not two)
- [ ] Both renamed files have exactly ONE `> [!info] Vault Autopilot` callout (not two)
- [ ] That one callout has **3 data rows**: Phase 1 Reviewed, Phase 2 Moved, Phase 4 Renamed
- [ ] All other `_Work/` files got a third row appended to their callout (Reviewed — name already descriptive)
- [ ] Filesystem birthtime on renamed files matches YAML `created` (or old birthtime if no YAML), not "now"

---

## Date/Cooldown Test Matrix

| # | File | YAML `created` | Birthtime (post-setup) | Cooldown Result | What This Tests |
|---|------|----------------|------------------------|-----------------|-----------------|
| 1 | Most files (26) | Old (Feb-Apr) or none | Old (step 2a) | Not triggered | Normal case |
| 2 | `Fresh Idea from Today.md` | Yesterday (dynamic) | Old (step 2a) | **Triggered** → skip | YAML `created` is primary source for cooldown |
| 3 | `Edited Old Note.md` | 2026-02-20 (old) | Fresh (step 2c) | **Not triggered** → process | **Birthday bug test:** YAML wins over fresh birthtime |
| 4 | `No Dates Note.md` | — (none) | Old (step 2a) | Not triggered | Fallback: no YAML → use birthtime |
| 5 | `broken-frontmatter.md` | — (unparseable YAML) | Old (step 2a) | Not triggered | Edge case: unparseable YAML, fallback to birthtime |

---

## Structural Verification (End-to-End)

### Auto-Creation

- [ ] `Inbox/_Work/`, `Inbox/_Personal/`, `Inbox/_Edge Cases/`, `Inbox/WebCaptures & Social/`, `Inbox/_Attachments/` all created by inbox-sort
- [ ] `_trash/` created by note-rename (Phase 1) at vault root

### Protected Files

- [ ] `_vault-autopilot.md` at vault root was NOT moved, renamed, or modified in any phase

### Trash Metadata (Phase 1 output)

For each of `_trash/Untitled.md`, `_trash/Quick Thought.md`, `_trash/Draft Ideas.md`:

- [ ] `trashed` date in frontmatter (today)
- [ ] `trash_source: note-rename` (NOT `inbox-sort`)
- [ ] `trash_origin` path in frontmatter

### Skill Log Idempotency (End State)

- [ ] No file has more than one `> [!info] Vault Autopilot` callout block
- [ ] No file has the `VaultAutopilot` tag listed twice in frontmatter
- [ ] Callout tables have the correct number of data rows per file at the end of Phase 4:
  - **0 rows** — cooldown-skipped file (`Fresh Idea from Today.md`) and non-markdown attachments (no callout block at all)
  - **1 row** — Phase-1-Nahbereich files (trashed, secret, daily) that Phase 2 never re-processed
  - **2 rows** — files moved in Phase 2 but not in Phase 4 scope (`_Personal/`, `_Edge Cases/`, `WebCaptures & Social/`, `daily/` additions from Phase 2, `_Attachments/`): P1 Reviewed/Renamed + P2 Moved
  - **3 rows** — files in `_Work/` after Phase 4: P1 Reviewed/Renamed + P2 Moved + P4 Reviewed/Renamed

### Birthtime Preservation

- [ ] Files with YAML `created` have filesystem birthtime matching that date after every skill run
- [ ] Files without YAML `created` retain their pre-run birthtime after every skill run

---

## Routing Review Notes

Observations kept from the previous inbox-sort-solo doc. These are NOT bugs — they are input for v0.2.0 configurability.

### 1. "Home Office" ambiguity

Test file `Home Office Desk Setup.md` is categorized as `_Personal` (household purchases). For freelancers and self-employed users, home office equipment is a business expense. The skill cannot know the user's employment context. Acceptable for v0.1.0 — user can override at preview.

### 2. Daily note pattern is strict

Only `YYYY-MM-DD.md` and `YYYY-MM-DD *.md` are detected. Users with `DD.MM.YYYY`, `YYYY/MM/DD`, or `March 15, 2026` patterns will not be caught. Configurable in v0.2.0 via `date_format` attribute.

### 3. Bare-link threshold is undefined

Web-capture-detection says "bare-link note (just a URL, no real content)." But what counts as "no real content"? URL + one-line comment — bare or not? A future test file should probe this boundary (URL + 1 sentence vs. URL + 3 paragraphs).

### 4. Focus Timer — productivity/habits boundary (_Personal vs _Edge Cases)

Test file `Focus Timer - Techniques.md` (the Phase 1 rename target for `No Dates Note.md`) is categorized as `_Personal` in Phase 2. Rationale: content is a deep-work routine (Flowtime / Pomodoro / 52-17), which matches the existing `_Personal` examples `Morning Routine Overhaul` and `Home Office Desk Setup`. An `_Edge Cases` assignment would also be defensible — productivity techniques can belong to either context depending on the user's framing. For v0.1.0 we accept `_Personal`; user can override at preview.

### 5. 0-byte file handling differs between note-rename and inbox-sort

In rename-first, 0-byte files land in `_trash/` (note-rename soft-deletes). In inbox-sort-solo, 0-byte files are permanently deleted. Both behaviors are internally consistent; the difference only matters for test expectations. Whether the two skills should align on a single behavior is a v0.1.1 design question.
