# Report Format — note-rename

Defines the preview table (before execution) and the report (after execution) for note-rename.

## Preview Format

Show rename plan with bilingual support (match the language the user is speaking). Sequential numbering across all rows.

### English Preview

```
| # | Note | Action | New Name | Skill-Log |
|---|------|--------|----------|-----------|
| 1 | `Old Name.md` | Rename | `New Name` | Pending |
| 2 | `Empty.md` | Trash | Reason for trashing | Pending |
| 3 | `Secret.md` | Secret | Sensitive content found | Pending |
| 4 | `2026-01-15.md` | Daily | Daily Notes folder | Pending |
| 5 | `Good Name.md` | Keep | Reviewed | Pending |

**X Renames, Y Trashes, Z Reviewed. Confirm?**
```

### German Preview

```
| # | Notiz | Aktion | Neuer Name | Skill-Log |
|---|-------|--------|------------|-----------|
| 1 | `Alter Name.md` | Umbenennen | `Neuer Name` | Ausstehend |
| 2 | `Leer.md` | Loeschen | Begruendung | Ausstehend |
| 3 | `Geheim.md` | Sensibel | Sensible Inhalte gefunden | Ausstehend |
| 4 | `2026-01-15.md` | Daily | Daily Notes Ordner | Ausstehend |
| 5 | `Guter Name.md` | Behalten | Geprueft | Ausstehend |

**X Umbenennungen, Y Loeschungen, Z Geprueft. Bestaetigen?**
```

### Column Rules

- **#** — sequential across all rows (not restarting per action type)
- **Note** — original filename in backticks
- **Action** — one of: Rename, Trash, Secret, Daily, Keep. Action values are not bold — the icon provides enough visual weight.
- **New Name** — for Rename: new filename. For Trash: reason for trashing. For Secret: detection type. For Daily: target folder. For Keep: "Reviewed" / "Geprueft"
- **Skill-Log** — "Pending" before execution. "Done" after successful execution. "Failed" on error. Never show implementation details (e.g., "Append" for notes with existing callouts). The user sees status, not internals.

### Rationale Section

After the summary line, add a numbered rationale for each non-trivial decision:

```
**Rationale:**
- **#1:** 6 Links, 3 platforms (Instagram 4, GitHub 1, Google 1), 5+ topics → Rule 4: Mixed Content.
- **#3:** 5 Links, 3 topics with AI dev thread. `&`-chain under 70 chars.
- **#7:** IBAN, BIC, full name in plaintext → _secret/.
```

Always include rationale — it is part of the standard output, not optional. The table shows the "what", rationale explains the "why". Format per entry: link count, platform breakdown, topic count, which rule was applied.

### Confirmation

Wait for explicit user confirmation before executing any renames or moves.

---

## Report Format (after execution)

```
## Note Rename Report — [Date]

### Done
- Renamed: X notes | Backlinks updated: X refs in Y notes
- Accidental notes trashed: X (Nahbereich, soft-delete to _trash/)
- Sensitive notes moved: X (Nahbereich, moved to _secret/)
- Daily notes moved: X (Nahbereich, moved to Daily Notes folder)

### Skipped
- Already descriptive: X | Daily Notes: X | TBD: X

### Findings
- Broken YAML frontmatter: X notes (recommend property-enrich)
- [Other observations for other skills]
```

---

## Action Types for Skill Log

Each processed note gets a skill-log callout entry with one of these action types:

| # | Action | Skill-Log Text |
|---|--------|---------------|
| 1 | Renamed | `Renamed from [old filename without .md]` |
| 2 | Reviewed | `Reviewed — name already descriptive` |
| 3 | Trashed | `Trashed — accidental note (soft-delete to _trash/)` |
| 4 | Secret | `Secret — sensitive content (moved to _secret/)` |
| 5 | Daily | `Daily — moved to Daily Notes folder` |
