# Incident — The Birthday Bug

**Date:** 2026-04-09
**Severity:** High — data integrity risk on cloned and production vaults
**Fix commit:** `8143e94`
**Status:** Fixed, with post-incident hardening across all skills

We publish this incident because we believe honesty is a feature. You are about to run destructive automation on your own files. You deserve to know what we got wrong, not just what we got right.

## What Happened

During testing of the `note-rename` skill on a cloned vault, the skill appeared to work correctly but skipped every older note with "cooldown active". The vault contained notes years old. Something was wrong.

The test vault was a `cp -R` clone of a snapshot. Every file in the clone had the same filesystem birthtime: the moment the clone was created. The skill's cooldown logic compared "now" to filesystem birthtime, concluded every file was less than 3 days old, and protected them all. The skill completed, reported "0 files processed", and passed its own internal checks.

We did not catch it immediately. The user asked "why is the skill skipping everything?" — and only then did we start tracing.

## Why It Was Dangerous

The visible symptom was benign: the skill no-ops, nothing gets moved. But the invisible failure was worse:

1. A user clones their vault for testing, runs a skill, sees "0 files processed", and assumes the vault is already clean.
2. They run the skill on production, where filesystem birthtimes are real and cooldown works correctly.
3. Production suddenly sees thousands of files eligible for processing — all the notes older than 3 days.
4. The user is blindsided by the volume of changes. If anything goes wrong, trust in the plugin is gone.

We call this the **silent clone-killer**. The skill is not broken; it is telling the truth about what it sees. But the user cannot distinguish "skill verified clean" from "skill never ran".

## Root Cause

Three things converged:

1. **Skills used filesystem birthtime as the only source of truth** for "when was this file created". There was no fallback to YAML `created` fields.
2. **Obsidian edits create new inodes.** When Obsidian saves a file, it writes a new file and renames it over the old one. Filesystem birthtime updates silently.
3. **Most clone methods do not preserve filesystem birthtime.** Finder copy, `cp -R`, Windows Explorer copy, and `git clone` all reset birthtime to "now". Only macOS `ditto -V` preserves it.

Together: filesystem birthtime is a poor proxy for "how old is this note", especially on cloned vaults and especially after Obsidian edits.

## The Fix

Commit `8143e94` made three changes:

1. **YAML `created` is now the primary source of truth.** Skills read frontmatter first. If `created` exists and is parseable, that value wins. Filesystem birthtime is only a last-resort fallback. See the full [source hierarchy](metadata-requirements.md).
2. **After any skill operation that rewrites a file, filesystem birthtime is restored** via `touch -t` using the YAML `created` value. This prevents drift across multiple runs.
3. **`property-enrich` was built as the first-run skill** for vaults without widespread `created` coverage. It fills `created` from filename patterns, filesystem metadata, or Git history without touching any other field.

The fix was verified by two kernel test cases:

- **Birthday-Bug-Test:** A file with YAML `created: 2026-02-20T14:00` (7 weeks old) but filesystem birthtime from the clone moment (fresh). YAML won. The skill processed the file correctly, renamed it, and restored birthtime to `Feb 20 14:00`.
- **Fallback-Test:** A file with no YAML `created`. Filesystem birthtime 4 days old (past cooldown). Skill processed correctly using filesystem birthtime as fallback.

Both tests were accepted under the project's test-acceptance rule: the developer does not get to declare a test as passing — the user decides.

## What We Learned

1. **YAML is more trustworthy than filesystem metadata** for anything related to "when this note was meaningful to the user". Filesystem metadata tracks the file; YAML tracks the note.
2. **Edits and clones both change filesystem metadata invisibly.** Any feature that depends on filesystem metadata must have an explicit fallback strategy.
3. **"The test passed" is not "the tested behavior is correct".** Early tests passed because the test vault was a clone and the cooldown logic was consistent with itself. The logic was wrong. The test was blind to the wrongness.
4. **User-cloning is a first-class deployment scenario**, not an edge case. We now document and test for it before we ship.

## Prevention

- The [Cloning Guide](cloning-guide.md) now explains which clone methods preserve birthtime and which do not.
- The [Metadata Requirements](metadata-requirements.md) document explains YAML `created` coverage and how to check it.
- The [Getting Started](getting-started.md) guide makes `property-enrich` the mandatory first step on any fresh or cloned vault.
- Clone Detection warnings fire when the plugin detects that all files have birthtimes clustering in a narrow window (indicating a recent clone).

We will keep this document updated as future incidents happen. We hope it stays short.
