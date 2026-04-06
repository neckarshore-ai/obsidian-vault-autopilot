---
name: note-quality-check
status: beta
description: Use when an Obsidian vault has accumulated old, low-value, or obsolete notes that need quality review. Trigger phrases - "check note quality", "find old notes", "cleanup notes", "prune notes", "stale notes", "quality audit", "review notes". Also trigger when the user mentions notes from an iOS migration, Apple Notes import, or too many unreviewed notes.
---

# Note Quality Check

Review vault notes by age, content quality, and relevance. Walk the user through decisions in small batches. Conservative — the skill never recommends trashing a note. Only the user decides what goes.

## Principle: Core + Nahbereich + Report

- **Core:** Score notes, present clusters, walk user through decisions
- **Nahbereich:** Trash whitespace-only files via soft-delete (see `references/trash-concept.md`). Permanently delete only 0-byte files.
- **Report:** Quality distribution, actions taken, parked items, findings for other skills

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cooldown_days` | 3 | Skip notes created within the last N days. Use file creation date (birthtime). |
| `scope` | inbox | Which folder to scan. `inbox` = inbox only. `vault` = entire vault. User confirms before execution. |
| `batch_size` | 5 | Number of notes to present per round. User decides before next round continues. |

## Protected Files and Folders

Never process or score these (see `references/vault-autopilot-note.md`):
- `_vault-autopilot.md` in vault root
- Any file starting with `_` in vault root (reserved for plugin management)
- Everything inside `_trash/` (see `references/trash-concept.md`)

## Four Actions

Every note gets exactly one action, chosen by the user:

| Action | What happens | When to suggest |
|--------|-------------|-----------------|
| **Keep** | Note stays. Optionally suggest a better target folder. | Note has clear purpose or reference value |
| **Archive** | Move to archive folder (e.g. `099_Archive/`) | Completed projects, past events, historical reference |
| **Park** | No action now. Tracked in report for later review. | User is unsure, needs more context, or wants to revisit |
| **Trash** | Soft-delete to `_trash/` with metadata | Only when user explicitly chooses this |

## The Golden Rule: Never Recommend Trash

The skill does not say "delete this" or "trash this". Instead:

- For notes the skill does not understand: "I cannot determine the purpose of this note. What is it for?"
- For notes with weak signals: suggest Keep or Archive, not Trash
- Only the user can say "Trash"

### Intentional Content Signals

A note is considered intentional (and never a Nahbereich candidate) if ANY of these are true:

1. Contains an embed (`![[...]]`)
2. Contains a wikilink (`[[...]]`)
3. Has YAML frontmatter with meaningful values (title, tags, description)
4. Has 3+ lines of non-whitespace content
5. Has a descriptive filename (not generic like "Untitled" or "New Note")

## Quality Criteria

Evaluate each note against all five. These inform the suggested action (Keep vs. Archive), not a delete decision.

| # | Criterion | Signal |
|---|-----------|--------|
| 1 | Staleness | >12 months old, no edits in 6+ months |
| 2 | Obsolete | Past events, completed projects, expired offers |
| 3 | Low substance | 1-2 sentences, URL-only, undeveloped thought |
| 4 | Redundancy | Near-duplicate title and opening lines in same folder |
| 5 | No clear purpose | No action, no reference value, no idea worth keeping |

`TBD -` prefixed notes (from note-rename) count as one pre-existing signal.

## Age Detection

1. YAML frontmatter (`created`, `date`, `modified`) — authoritative
2. Filesystem timestamps — fallback
3. **Bulk-import:** Many files sharing same creation timestamp — flag age as uncertain. Report, do not modify frontmatter (properties skill's job).

## Workflow

### Phase 1: Discover and Scan

1. Resolve `${OBSIDIAN_VAULT_PATH}`. Ask for target folder. Non-recursive default.
2. Confirm scope if 50+ notes.
3. Read all notes: title, frontmatter, first ~30 lines, file metadata.
4. Nahbereich: permanently delete 0-byte files. Trash whitespace-only files. Log each.

### Phase 2: Cluster and Group

5. Detect clusters using (in order):
   - Filename prefix matching (e.g., `MB -`, `CREALOGIX`, `ITG -`)
   - Tag overlap (3+ shared tags between notes)
   - Semantic grouping for remaining unclustered notes
6. Assign unclustered notes to a "Mixed" group.
7. Order clusters: largest first, then alphabetical.

### Phase 3: Walk-Through

8. Present one cluster at a time. Use this exact format:

```
**Cluster X: "[Name]" (N Notes)**
Kontext: [1-line description of what connects these notes]

| # | Note | Typ | Zeilen | Suggested Action |
|---|------|-----|-------:|-----------------|
| 1 | Example Note.md | Brief-Entwurf | 68 | Archive (A) |
| 2 | Another Note.md | Projekt-Doku | 115 | Keep (K) |

**Aktionen:**
- **Keep (K)** — bleibt wo sie ist, optional Ordner-Vorschlag
- **Archive (A)** — verschiebt nach `099_Archive/[Cluster]/`
- **Park (P)** — keine Aktion jetzt, kommt in den Report für später
- **Trash (T)** — Soft-Delete nach `_trash/` (wiederherstellbar)

Beispiel: `1A 2K` oder `alle A` oder `1-5 A, 6T`

→ Deine Entscheidung?
```

9. Show max `batch_size` notes per table (default 5). If a cluster has more, continue with a second table after the user decides.
10. Wait for user decisions. Accept shorthand (e.g. `1A 2A 3K`) or cluster-wide (e.g. `alle A`).
11. Execute actions immediately after each round (move files, add trash metadata).
12. Continue to next round or next cluster.

### Phase 4: Report

14. Write summary report. Append to `logs/run-history.md`.

## Report Format

```
## Note Quality Check Report — [Date]

### Done
- Analyzed: X | Kept: X | Archived: X | Trashed: X | Parked: X
- Nahbereich: X files removed (0-byte: X, whitespace-only trashed: X)

### Parked (revisit later)
- [List of parked notes with 1-line context each]

### Clusters Reviewed
- [Cluster name]: X notes — [actions summary]

### Findings
- Uncertain age (import suspected): X notes
- [Observations for other skills]
```

## Quality Check

- [ ] Every action was chosen by the user (no auto-trash of content notes)
- [ ] Parked notes are listed in report
- [ ] Trash metadata was added before moving files
- [ ] Nahbereich limited to 0-byte and whitespace-only files
- [ ] Uncertain-age notes reported, not modified
