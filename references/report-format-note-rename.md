# Report Format — note-rename

Defines the preview table (before execution) and the report (after execution) for note-rename.

## Preview Format

Show rename plan with bilingual support (match the language the user is speaking). Sequential numbering across all rows.

### English Preview

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

### German Preview

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

### Column Rules

- **New Name:** For Rename → new filename. For Trash → reason for trashing. For Keep → "Reviewed" / "Geprüft".
- **Skill-Log:** ⚠️ Pending before execution, ✅ Done after, ❌ Failed on error. Never show implementation details (e.g. "Append" for notes with existing callouts). The user sees status, not internals.
- **Action values are not bold** — the icon provides enough visual weight.

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
- Auto-enriched `created`: X notes (Nahbereich)
- Repaired corrupted date-keys (`"created:"` → `created`): X notes (Nahbereich)

### Skipped
- Already descriptive: X | Daily Notes: X | TBD: X | Cooldown (< `cooldown_days` old): X

If the Cooldown count is non-zero, list the skipped filenames with their `created` date so the user can spot mis-classifications (e.g. files that look uninformative but have a recent `created` date and were therefore deferred).

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
| 6 | Auto-enriched | `Auto-enriched created: YYYY-MM-DD (source: filename\|git\|birthtime)` |
