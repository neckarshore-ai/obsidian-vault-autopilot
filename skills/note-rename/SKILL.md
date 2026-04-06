---
name: note-rename
status: stable
description: Use when Obsidian vault notes have poor, generic, or uninformative filenames and need clear, descriptive names. Trigger phrases - "rename notes", "fix note names", "clean up filenames", "give notes better names". Also trigger for single notes - "rename this note", "give this a better name". Trigger when the user mentions "Untitled notes", "unnamed notes", or notes that are hard to find by name.
---

# Note Rename

Give poorly named vault notes clear, descriptive filenames. Rename and fix backlinks. No sorting, no restructuring.

## Principle: Core + Nahbereich + Report

- **Core:** Rename uninformative filenames, update backlinks across vault
- **Nahbereich:** Trash accidental notes via soft-delete (see rule below and `references/trash-concept.md`). Minimal YAML syntax repairs when already editing frontmatter. Syntactic fixes only — never add or change field values (that is property-enrich's job). Allowed repairs:
  - `*` → `-` in tag lists
  - Remove duplicate `---` separators
  - Convert inline tags `[X]` to block format
  - Remove junk text before opening `---` (e.g. dictation artifacts like `Thx ---` → `---`)
  - Fix quoted keys with embedded colon: `"type:"` → `type` (the colon belongs to YAML syntax, not the key name)
- **Report:** Renames, backlink updates, findings for other skills

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. Use file creation date (birthtime), not modification date. |
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only. `vault` = entire vault (excluding vault root). `folder:path` = specific subfolder. User confirms before execution. |

## Scope Rules

- **Vault root is always excluded** unless the user explicitly asks to process root-level files. Root files are typically structural (OPS docs, config notes, plugin files) and rarely rename candidates.
- Folders starting with `_` are excluded from scanning (`_trash/`, `_secret/`, `_test-backup/`).
- Folders starting with `.` are excluded (`.trash/`, `.obsidian/`).
- Template folders (e.g. `00_Templates`) are excluded.

## Protected Files

Never rename or process these files (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)

## Rename Candidates

Rename notes with **uninformative** filenames: `Untitled`, `Unbenannt`, `New Note`, `Draft`, `Blank note`, `Note from iPhone`, `Quick Note`, URL-only names, hash-only names, obvious typos (95%+ clear intent).

**Never rename:** Already descriptive names.

**Daily Notes (`YYYY-MM-DD.md`):** Not automatically kept. Classify by content:
- **Empty or boilerplate-only** → Trash candidate (accidental note detection)
- **Has content (links, text, ideas)** → Rename candidate. Keep date prefix: `YYYY-MM-DD - Context - Detail`
- **Multi-topic (links from different platforms, mixed themes)** → TBD suffix. Flag for manual review.

**Web captures:** Apply prefix per `references/web-capture-detection.md`. Skip existing categorical prefixes.

**Unclear cases:** `[Original Name] - TBD`. When the original name contains a date, keep the date first: `YYYY-MM-DD - TBD`. The date must always lead for chronological sorting.

## Accidental Note Detection (Nahbereich)

Soft-delete to `_trash/` if ALL true: (1) generic filename, (2) no content beyond template boilerplate, (3) frontmatter has only generic tags and no real title. Add trash metadata per `references/trash-concept.md`. When in doubt → TBD prefix instead.

## Daily Note Detection (Nahbereich)

Notes matching the Daily Note pattern (`YYYY-MM-DD.md`) get special handling. They are NOT auto-kept — classify by content (see Rename Candidates above). Location handling:

**Detection rules:**
1. **Misplaced daily notes** — `YYYY-MM-DD.md` outside the vault's canonical Daily Notes folder → move there first, then classify for rename like any other note. Add skill-log with Daily action for the move.
2. **Hybrid names** (`YYYY-MM-DD Some Description.md`) — this is NOT a daily note. It is a regular note with a date prefix. Process as a rename candidate — the date prefix is informative context, not a daily note pattern.
3. **Future dates** — if the note has a `created` date in frontmatter, use it as the correct date and rename accordingly. If a note with the corrected date already exists, resolve via naming (e.g. add a suffix). If no `created` date is available, flag for manual review. Always log the date correction in the skill-log action: `Renamed from [original] (date corrected)`.
4. **Already in correct Daily Notes folder** — no move needed. Still classify for rename based on content.
5. **Nested Daily Notes folders** (e.g. `inbox/Daily Notes/YYYY-MM-DD.md`) — these are misplaced. The vault has ONE canonical Daily Notes folder. Move there, avoid duplicates.

## Corrupted File Detection (Nahbereich)

Detect files with multiple YAML frontmatter blocks (two or more `---`/`---` pairs). This happens when two notes get accidentally merged — typically an append error during sync or import. These files cannot be reliably processed.

**Action:** Rename with a descriptive corruption label (e.g. `YYYY-MM-DD - Korrupte Datei - Zwei Notizen verschmolzen`). Write skill-log. Do not attempt to split the file — that requires manual review by the user.

**Detection:** Count `---` lines at positions that look like frontmatter boundaries (start of file, after content blocks). Two complete frontmatter blocks = corrupted.

## Sensitive Content Detection (Nahbereich)

Move to `_secret/` if the note contains sensitive data: recovery phrases, API keys, passwords, tokens, or other credentials stored as plaintext. These notes are a security risk and must not remain in the vault unprotected. Add trash metadata with `trash_source: note-rename` and the original path. The `_secret/` folder signals to the user that these files need manual review and secure handling — not just deletion.

## Naming Rules

1. Capture **core topic** — scannable at a glance
2. **Dash separator:** `Topic - Detail` for two-level names
3. No filler words ("Note about", "Draft of")
4. Match content language
5. Max ~70 characters

**Clusters:** If 3+ notes share a topic, suggest a common prefix before renaming.

## Context Segment

When renaming notes that have a date prefix, use a three-part name: `YYYY-MM-DD - Context - Detail`.

The **Context** segment answers: "What gives the reader the fastest orientation?" It can be:
- A **platform** (Instagram, YouTube, ChatGPT, Perplexity, Grok, GitHub, Reddit, LinkedIn)
- A **project** (OMNIXIS, OpenClaw, Neckarshore)
- A **life area** (Family, Finance, Career, Health)
- An **activity** (Research, Interview, Meeting, Review)

**Platform detection** (when primary content is a link or capture):

| URL Pattern | Context Segment |
|---|---|
| `instagram.com` | Instagram |
| `youtube.com`, `youtu.be` | YouTube |
| `perplexity.ai` | Perplexity |
| `chatgpt.com` | ChatGPT |
| `grok.com` | Grok |
| `linkedin.com` | LinkedIn |
| `github.com` | GitHub |
| `reddit.com` | Reddit |
| Other recognizable domain | Domain name (capitalized) |

See also `references/web-capture-detection.md` for social platform detection rules.

**Multiple links, same platform:** One context segment. E.g. 3 Instagram links → still just "Instagram".
**Multiple links, different platforms:** Use the dominant platform as context, or `Research` if no platform dominates.
**No links (pure text):** Use project, life area, or activity as context.

## Multi-Topic Rules

When a note covers multiple unrelated topics, join them with `&` in the Detail segment:

| # | Topic Count | Platforms | Rule |
|---|-------------|-----------|------|
| 1 | 1-2 | any | All topics in the name with `&` |
| 2 | 3-4 | any | All topics in the name with `&` if it stays readable and under ~70 characters. Skill decides. |
| 3 | 5-6 | one dominant | All topics as keywords with `&`. One keyword per topic — enough to find the note later. |
| 4 | 5+ | multiple | `YYYY-MM-DD - Mixed Content - Mixed Topics.md`. Too chaotic for a meaningful name. |
| 5 | 7+ | any | `YYYY-MM-DD - Mixed Content - Mixed Topics.md`. Topic Override — content this fragmented cannot produce a meaningful name regardless of platform dominance. |

Examples:
- 2 topics: `2025-12-03 - Instagram - HR Interview Tipps & SaaS.md`
- 3 topics: `2025-12-04 - Instagram - SaaS & Dev Tools & Karpathy LLM.md`
- 5-6 topics, one platform: `2025-12-11 - Instagram - Product & Interview & Claude & AI Cases & Cursor.md`
- 5+ topics, multiple platforms: `2025-12-08 - Mixed Content - Mixed Topics.md`
- 7+ topics, one platform: `2026-01-08 - Mixed Content - Mixed Topics.md` (Topic Override — 7 topics, 93% Instagram, still too fragmented)

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Default scope: inbox root. Confirm with user.
2. **Scan** — list `.md` files.
3. **Nahbereich** — detect and trash accidental notes (soft-delete to `_trash/`). Move misplaced Daily Notes to the Daily Notes folder. Log each.
4. **Classify** — read title, tags, first ~30 lines (skip template boilerplate). Mark as: rename, keep, or TBD.
5. **Detect clusters** — 3+ candidates on same topic → prepare prefix suggestion.
6. **Check backlinks** — find all `[[Old Name]]` references across vault.
7. **Preview and confirm** — show the preview table below. Match the language the user is speaking. **Do not execute until the user explicitly confirms.**

   **English preview (when user speaks English):**

   ```
   | # | Note | Action | New Name | Skill-Log |
   |---|------|--------|----------|-----------|
   | 1 | `Old Name.md` | ✏️ Rename | `New Name` | ⚠️ Pending |
   | 2 | `Empty.md` | 🗑️ Trash | Reason for trashing | ⚠️ Pending |
   | 3 | `Secret.md` | 🔒 Secret | Sensitive content found | ⚠️ Pending |
   | 4 | `2026-01-15.md` | 📅 Daily | → Daily Notes folder | ⚠️ Pending |
   | 5 | `Good Name.md` | ✅ Keep | Reviewed | ⚠️ Pending |

   **X Renames, Y Trashes, Z Reviewed. Confirm?**
   ```

   **German preview (when user speaks German):**

   ```
   | # | Notiz | Aktion | Neuer Name | Skill-Log |
   |---|-------|--------|------------|-----------|
   | 1 | `Alter Name.md` | ✏️ Umbenennen | `Neuer Name` | ⚠️ Ausstehend |
   | 2 | `Leer.md` | 🗑️ Löschen | Begründung | ⚠️ Ausstehend |
   | 3 | `Geheim.md` | 🔒 Sensibel | Sensible Inhalte gefunden | ⚠️ Ausstehend |
   | 4 | `2026-01-15.md` | 📅 Daily | → Daily Notes Ordner | ⚠️ Ausstehend |
   | 5 | `Guter Name.md` | ✅ Behalten | Geprüft | ⚠️ Ausstehend |

   **X Umbenennungen, Y Löschungen, Z Geprüft. Bestätigen?**
   ```

   **Column rules:**
   - **New Name:** For Rename → new filename. For Trash → reason for trashing. For Keep → "Reviewed" / "Geprüft".
   - **Skill-Log:** ⚠️ Pending before execution, ✅ Done after, ❌ Failed on error. Never show implementation details (e.g. "Append" for notes with existing callouts). The user sees status, not internals.
   - **Action values are not bold** — the icon provides enough visual weight.

   **Rationale section (below the table):**
   After the summary line, add a numbered rationale for each non-trivial decision:
   ```
   **Rationale:**
   - **#1:** 6 Links, 3 platforms (Instagram 4, GitHub 1, Google 1), 5+ topics → Rule 4: Mixed Content.
   - **#3:** 5 Links, 3 topics with AI dev thread. `&`-chain under 70 chars.
   - **#7:** IBAN, BIC, full name in plaintext → _secret/.
   ```
   Always include rationale — it is part of the standard output, not optional. The table shows the "what", rationale explains the "why". Format per entry: link count, platform breakdown, topic count, which rule was applied.
8. **Execute** — rename files, update all `[[Old Name]]` and `[[Old Name|` references.
9. **Skill Log** — for every processed note (renamed, reviewed, or trashed), write the skill log. See `references/skill-log.md` for the full spec.

   **Tag (idempotent):**
   - Check if `VaultAutopilot` already exists in the `tags` list in YAML frontmatter.
   - If missing: add it. If present: do nothing. Never duplicate.
   - If no `tags` field exists: create one with `VaultAutopilot` as the first entry.

   **Callout (append-only):**
   - Check if `> [!info] Vault Autopilot` exists at the end of the note.
   - If missing: create the full callout block:
     ```
     > [!info] Vault Autopilot
     >
     > | Date | Skill | Action |
     > |------|-------|--------|
     > | YYYY-MM-DD | note-rename | [action] |
     ```
   - If present: append only a new `> | YYYY-MM-DD | note-rename | [action] |` row to the existing table. Never create a second callout.
   - Ensure one blank line separates the callout from the preceding content.

   **Action types:**
   - Renamed: `Renamed from [old filename without .md]`
   - Reviewed (name was already good): `Reviewed — name already descriptive`
   - Trashed (Nahbereich): `Trashed — accidental note (soft-delete to _trash/)`
   - Secret (Nahbereich): `Secret — sensitive content (moved to _secret/)`
   - Daily (Nahbereich): `Daily — moved to Daily Notes folder`

10. **Report and log** — write summary, append to `logs/run-history.md`.

## Report Format

```
## Note Rename Report — [Date]

### Done
- Renamed: X notes | Backlinks updated: X refs in Y notes
- Accidental notes trashed: X (Nahbereich, soft-delete to `_trash/`)

### Skipped
- Already descriptive: X | Daily Notes: X | TBD: X

### Findings
- Broken YAML frontmatter: X notes (→ property-enrich)
- [Other observations for other skills]
```

## Quality Check

- [ ] Renamed files exist at new paths
- [ ] All backlinks updated (no broken `[[]]`)
- [ ] No Daily Notes renamed
- [ ] User confirmed before execution
- [ ] Every processed file has `VaultAutopilot` tag in frontmatter (exactly once)
- [ ] Every processed file has skill log callout at the end
- [ ] Reviewed notes have "Reviewed" action, not "Renamed"
- [ ] Re-renamed notes have multiple callout rows, not multiple callouts
