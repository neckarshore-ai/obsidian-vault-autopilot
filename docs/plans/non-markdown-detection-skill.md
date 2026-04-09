# Plan: Non-Markdown File Detection Skill

**Status:** Backlog (P3 — after launch)
**Author:** Obi (2026-04-07)
**Scope:** New skill for v0.2.0

## Problem

When skills scan vault folders, they encounter non-Markdown files (images, PDFs, media, scripts, calendar files). Currently, these are completely invisible — no report, no classification, no guidance for the user.

Real vault data (OMNIXIS, 2026-04-07):

| # | Type Group | Count | Examples |
|---|-----------|-------|----------|
| 1 | Images (png, jpg, jpeg, heic) | 63 | Pasted images, screenshots, iPhone photos |
| 2 | Documents (pdf) | 10 | Books, invoices, school letters, password docs |
| 3 | Code/Config (ps1, ics, skill) | 5 | PowerShell scripts, calendar events |
| 4 | Other (Alias) | 1 | Obsidian alias file |

Images make up 72% of non-MD files. This is not just a PDF problem.

## Proposed Skill: `attachment-detect`

A standalone skill that scans folders and produces a classified inventory of all non-Markdown files.

### Trigger Phrases

"scan for attachments", "find non-markdown files", "what files are not notes", "attachment inventory", "find orphan files", "check for images and PDFs"

### Core Task

Scan a folder (or entire vault) and classify every non-Markdown file by type and status.

### File Type Groups

| Group | Extensions |
|-------|-----------|
| Images | `.png`, `.jpg`, `.jpeg`, `.heic`, `.gif`, `.svg`, `.webp`, `.bmp`, `.tiff` |
| Documents | `.pdf`, `.docx`, `.xlsx`, `.pptx`, `.csv`, `.txt` |
| Media | `.mp3`, `.mp4`, `.mov`, `.wav`, `.m4a`, `.webm` |
| Code/Config | `.ps1`, `.sh`, `.py`, `.json`, `.yaml`, `.yml`, `.xml`, `.ics` |
| Other | Everything not listed above and not `.md` |

### Classification (independent of file type)

| # | Class | Definition | Detection Method |
|---|-------|-----------|-----------------|
| 1 | **Companion** | Referenced by an MD note via `![[file.ext]]` or `[text](file.ext)` | Vault-wide backlink search |
| 2 | **Orphan** | No MD note references this file | Inverse of companion check |
| 3 | **Sensitive-name** | Filename contains: `password`, `credential`, `key`, `secret`, `IBAN`, `token`, `recovery`, `Passwort`, `Kennwort` | Filename keyword match (case-insensitive) |
| 4 | **Attachment-folder resident** | Already in the vault's configured attachment folders | Path check against known folders |

Notes:
- Sensitive-name is flagged regardless of other classifications (a companion can also be sensitive)
- Attachment-folder residents are reported but not flagged as needing action — they are where they belong
- Detection is filename + backlink based only. Skills never read binary file content.

### Excluded Folders

`_trash/`, `_secret/`, `.obsidian/`, `.trash/`, folders with `_` prefix

### Configurable Attachment Folders

Default: `Attachments/`, `Bilder/` (can be extended per vault)

### Report Format (Core + Nahbereich + Report)

```
## Attachment Detection Report — [Date]

### Inventory
- Total non-Markdown files: X
- Images: X (png: X, jpg: X, heic: X, ...)
- Documents: X (pdf: X, ...)
- Media: X
- Code/Config: X
- Other: X

### Classification
- Companion (embedded in a note): X
- Orphan (no note references them): X
- Sensitive filename: X

### Orphan Files (action needed)
| # | File | Type | Location | Suggestion |
|---|------|------|----------|------------|
| 1 | `example.pdf` | Document | XX Invest/ | Move to appropriate folder or create index note |

### Sensitive Filenames (manual review needed)
| # | File | Type | Location | Keyword |
|---|------|------|----------|---------|
| 1 | `PSPO 1 Assessment Password.pdf` | Document | _secret/ | password |

### Findings
- HEIC files: X (Obsidian cannot display HEIC natively — consider converting to JPG)
- [Other observations for user]
```

### Boundary: Report Only

This skill never reads, renames, moves, or deletes non-Markdown files. It classifies and reports. The user decides what to do.

"AI recommends, human decides."

### Nahbereich

- If an orphan file's name strongly suggests it belongs to a specific note (e.g. `Tesla Fristenplan.pdf` next to `Tesla Fristenplan.md`), suggest linking them.
- Flag HEIC files with a compatibility note (Obsidian cannot render HEIC inline).

## Architecture Decisions

### Why a standalone skill (not Nahbereich of note-rename/inbox-sort)?

1. **One skill, one job.** note-rename renames. inbox-sort sorts. Attachment detection is a distinct concern.
2. **Independent execution.** User can run this on any folder without triggering rename or sort logic.
3. **No scope creep.** Keeps existing skills focused and their SKILL.md files stable.

### Why a shared reference doc is still useful

Even as a standalone skill, a `references/non-markdown-detection.md` provides:
- Shared type group definitions (so future skills use the same categories)
- Shared keyword list for sensitive-name detection
- Convention that other skills can optionally point to ("Found X non-MD files — run attachment-detect for details")

### Open question: Cross-skill pointer

Should note-rename and inbox-sort include a one-liner in their report when they encounter non-MD files?

Option A: Yes — "Found X non-MD files in scanned folder. Run `attachment-detect` for classification."
Option B: No — skills stay silent about non-MD files. User runs attachment-detect separately.

Decision deferred to implementation time.

## Implementation Sequence

1. Create `references/non-markdown-detection.md` (shared type groups + keyword list)
2. Create `skills/attachment-detect/SKILL.md`
3. Live test against OMNIXIS vault (XX Invest folder: 4 PDFs, verify Lernvertrag.pdf = Companion)
4. Optionally add cross-skill pointer to note-rename and inbox-sort reports

## v0.2.0+ Extensions (not in first version)

- Sensitive-name files: auto-move to `_secret/` (with user confirmation)
- Orphan files: generate stub MD note (title + source path + tags)
- Companion tracking: warn when renaming an MD note that embeds a file
- HEIC to JPG conversion suggestion
- Duplicate detection (same file in multiple locations)
- Size audit (flag files > 10MB that bloat the vault)
