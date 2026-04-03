---
name: note-quality-check
description: Use when an Obsidian vault has accumulated old, low-value, or obsolete notes that need quality review and deletion recommendations. Trigger phrases - "check note quality", "find old notes", "cleanup notes", "prune notes", "stale notes", "delete suggestions", "quality audit". Also trigger when the user mentions notes from an iOS migration, Apple Notes import, or too many unreviewed notes.
---

# Note Quality Check

Analyze vault notes by age, content quality, and relevance. Recommend deletions with per-file user confirmation. Conservative — false positives (deleting something valuable) are far worse than false negatives.

## Principle: Core + Nahbereich + Report

- **Core:** Score notes, produce deletion recommendations
- **Nahbereich:** Delete accidental notes (generic name + no content + no metadata) without asking
- **Report:** Quality distribution, deletion results, findings for other skills

## Quality Criteria

Evaluate each note against all five. Weigh together, not individually.

| # | Criterion | Signal |
|---|-----------|--------|
| 1 | Staleness | >12 months old, no edits in 6+ months |
| 2 | Obsolete | Past events, completed projects, expired offers |
| 3 | Low substance | 1-2 sentences, URL-only, undeveloped thought |
| 4 | Redundancy | Near-duplicate title and opening lines in same folder |
| 5 | No purpose | No action, no reference value, no idea worth keeping |

`TBD -` prefixed notes (from note-rename) count as one pre-existing signal.

## Decision Logic

- **Delete recommended:** 2+ strong criteria
- **Manual review:** 1 strong or 2 weak
- **Keep:** 0-1 weak

When in doubt → review, never delete.

## Age Detection

1. YAML frontmatter (`created`, `date`, `modified`) — authoritative
2. Filesystem timestamps — fallback
3. **Bulk-import:** Many files sharing same creation timestamp → flag age as uncertain. Report, do not modify frontmatter (properties skill's job).

## Workflow

1. **Discover vault** — resolve `${OBSIDIAN_VAULT_PATH}`. Ask for target folder. Non-recursive default. Confirm if 50+ notes.
2. **Nahbereich** — delete accidental notes. Log each.
3. **Score** — evaluate all notes against 5 criteria.
4. **Present** — sorted table (delete first, then review, then keep). One-line justification per note.
5. **Per-file deletion** — show content preview per "delete recommended" note. User confirms: delete, keep, or defer. **Never bulk-delete.** Optionally walk "review" notes after.
6. **Report and log** — write summary, append to `logs/run-history.md`.

Batch in groups of 30 for folders with 100+ notes.

## Report Format

```
## Note Quality Check Report — [Date]

### Done
- Analyzed: X | Deleted: X | Kept: X | Deferred: X
- Accidental notes deleted: X (Nahbereich)

### Distribution
- Delete recommended: X | Review: X | Keep: X

### Findings
- Uncertain age (import suspected): X notes
- [Observations for other skills]
```

## Quality Check

- [ ] Every deletion individually confirmed
- [ ] Content preview shown before each deletion
- [ ] Uncertain-age notes reported, not modified
