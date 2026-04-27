# Report Format — inbox-sort

Defines the preview table (before execution) and the report (after execution) for inbox-sort.

## Preview Format

Show routing plan grouped by bucket with durchgehend nummerierte Zeilen. The user confirms or overrides individual assignments before execution.

```
## Inbox Sort Preview

### _Work

| # | File | Reason | Flag |
|---|------|--------|------|
| 1 | `Note Name.md` | Business/dev/tool content | |
| 2 | `Sensitive Note.md` | Crypto/tech content | **Recovery Phrase** |

### _Personal

| # | File | Reason |
|---|------|--------|
| 3 | `Health Note.md` | Health/habits content |

### _Edge Cases

| # | File | Reason |
|---|------|--------|
| 4 | `Ambiguous Note.md` | Could be work or personal |

### WebCaptures & Social

| # | File | Reason |
|---|------|--------|
| 5 | `Clipped Article.md` | Pre-sort: source URL |
| 6 | `Social Post.md` | Pre-sort: bare link x.com |

### Daily

| # | File | Reason |
|---|------|--------|
| 7 | `2026-03-15.md` | YYYY-MM-DD pattern |

### Nahbereich

| # | File | Action |
|---|------|--------|
| 8 | `Empty.md` | Deleted (0-byte) |
| 9 | `Whitespace.md` | Soft-deleted to _trash/ |

### _Attachments

| # | File | Type |
|---|------|------|
| 10 | `photo.png` | Image |
| 11 | `document.pdf` | PDF |

### Skipped

| # | File | Reason |
|---|------|--------|
| 12 | `Recent.md` | Cooldown: < 3 days |

### Findings

1. **#2** `Sensitive Note.md` — Contains recovery phrase (flag only, not moved to _secret)
2. **#X** `broken.md` — Broken YAML frontmatter (no closing ---)
```

### Column Rules

- **#** — sequential across all sections (not restarting per section)
- **File** — original filename in backticks
- **Reason** — short categorization rationale or routing rule applied
- **Flag** — only for notes with findings (broken YAML, sensitive data). Bold text.
- **Action** — only in Nahbereich section (Deleted/Soft-deleted)

### Confirmation

End the preview with a summary line:

```
**X _Work, Y _Personal, Z _Edge Cases, W WebCaptures & Social, D Daily, A _Attachments. N Nahbereich, S Skipped. Confirm?**
```

Wait for explicit user confirmation before executing any moves.

---

## Report Format (after execution)

```
## Inbox Sort Report — [Date]

### Done
- _Work: X notes moved
- _Personal: X notes moved
- _Edge Cases: X notes moved
- WebCaptures & Social: X notes moved
- Daily: X notes moved
- _Attachments: X files moved (images, PDFs, etc.)
- Nahbereich: X files removed (0-byte deleted: X, whitespace-only trashed: X)
- Auto-enriched `created`: X notes (Nahbereich)
- Repaired corrupted date-keys (`"created:"` → `created`): X notes (Nahbereich)

### Skipped
- Cooldown (< [cooldown_days] days): X notes

If the Cooldown count is non-zero, list the skipped filenames with their `created` date (the table in the preview's Skipped section already does this; carry it through to the report so the user can audit afterwards).

### Findings
- [Observations — e.g., broken frontmatter, sensitive data, suspicious duplicates]

### Suggestions
- [Improvements for this skill — e.g., criteria unclear for X topic]
```

---

## Findings Catalog

Known finding types that inbox-sort can detect:

| # | Finding | Detection | Severity |
|---|---------|-----------|----------|
| 1 | Broken YAML frontmatter | Missing closing `---` delimiter, malformed YAML | Low — note still categorized by content |
| 2 | Sensitive data: recovery phrase | 12/24 word sequences matching BIP-39 pattern | High — flag for user review |
| 3 | Sensitive data: IBAN/BIC | Pattern matching IBAN format (2 letters + 2 digits + up to 30 alphanumeric) | High — flag for user review |
| 4 | Sensitive data: API key/token | Patterns like `sk-`, `Bearer`, `token:`, `api_key` with adjacent values | Medium — context-dependent, may be false positive |

Findings are reported but never trigger automatic actions. "AI empfiehlt, Mensch entscheidet."
