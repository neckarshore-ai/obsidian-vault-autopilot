# Clone-Cluster Detection

Shared utility doc for the W2 mode-shift unification (v0.1.4). Defines the two recipes that detect whether a file's filesystem birthtime falls inside a clone-induced cluster window AND whether the file has an alternate date source. Used by `property-enrich`, `note-rename`, `inbox-sort`, and `property-describe` to gate auto-enrichment / cooldown evaluation when the only available date source would be a poisoned (clone-time) birthtime.

> **Why this exists.** GR-3 strict-path validation (2026-05-01) on `nexus-clone-robocopy` discovered that 36.8 % (189 / 514) of inbox-tree files had filesystem birthtime equal to the clone time, clustered within a 1 h window. Auto-enriching `created` from filesystem birthtime in this state would write the clone date as the user's note creation date — destructive metadata loss. The mode-shift adopted in three Cell-by-Cell verdicts (Options B, C, D) was: **when birthtime is in the cluster AND there is no alternate source, SKIP — leave the field absent. Recoverable absence is strictly better than poisoned presence.**

## Decision Matrix

| birthtime in cluster window | alternate date source | Action |
|-----------------------------|------------------------|--------|
| YES | YES (YAML `created` parses, OR filename `YYYY-MM-DD`, OR git first-commit) | **PROCESS** — use the alternate source per Source Hierarchy in `docs/metadata-requirements.md` |
| YES | NO | **SKIP** — leave `created` absent, log file in Findings (Class C: "clone-cluster birthtime, no alt source") |
| NO | * | **PROCESS** — normal Source Hierarchy walk |

## Cluster Window Detection

A "clone cluster" is detected vault-scan-wide once at the start of every skill invocation. The detector:

1. Reads filesystem birthtime for every in-scope `.md` file.
2. Bucketizes birthtimes into 1 hour bins (UTC, edges aligned to the hour).
3. If any bin contains **≥ 10 files**, that bin is the cluster window. The window is widened to ±30 min around the median of the bin's contents (so ±30 min tolerance).
4. If multiple bins exceed the threshold (rare — multi-clone vault), the **most populated** bin wins. The other clusters are reported as Findings (Class D) but not used for SKIP gating.
5. If no bin reaches threshold, no cluster is declared. All files PROCESS normally.

The 10-file / 1 h heuristic is empirically anchored: in `nexus-clone-robocopy`, 189 of 514 files clustered within ±30 s of `2026-04-16T20:33:23Z` — well above threshold. A 10-file floor avoids false positives on small vaults where 2-3 files share a birthtime by coincidence (e.g. a batch import).

The window is computed once per skill invocation and cached in memory (variable `$CLONE_CLUSTER_WINDOW_START` / `$CLONE_CLUSTER_WINDOW_END`, ISO 8601). Per-file checks reuse this baseline.

**Runnable implementation:** The detection algorithm above (steps 1–5) is implemented in [`scripts/detect-clone-cluster.sh`](../scripts/detect-clone-cluster.sh). Callers run `eval "$(scripts/detect-clone-cluster.sh "$VAULT")"` to populate `$CLUSTER_FOUND`, `$CLONE_CLUSTER_WINDOW_START`, `$CLONE_CLUSTER_WINDOW_END`, and `$CLUSTER_FILE_COUNT`. The script is the single source of truth for the bucketize-and-find-winner step, used by both the runtime SKIP-gate flow described below (recipes a + b) and the cross-platform user-facing preflight WARN in [`references/clone-preflight.md`](clone-preflight.md).

## Recipes

### Recipe (a) — `is_birthtime_in_clone_cluster_window`

Returns `0` (in cluster) or `1` (not in cluster). Reads filesystem birthtime as raw epoch seconds, compares numerically against the pre-computed cluster-window epoch bounds emitted by `scripts/detect-clone-cluster.sh`.

> **Why epoch, not ISO strings.** v0.1.4 W2 first shipped this recipe with an ISO-string compare using `stat -f '%SB' -t '%Y-%m-%dT%H:%M:%SZ'` on Darwin. That format string formats local time and slaps a literal `Z` suffix; on a non-UTC host the resulting "ISO" string was off by the local-UTC offset and disagreed with the genuinely-UTC window emitted by the detector — producing **wrong SKIP verdicts on every macOS user in a non-UTC timezone**. The Linux path was already epoch-based and was therefore correct. v0.1.5 extracts the epoch contract for both platforms and deletes the lying-format-string. Detector now also emits `CLONE_CLUSTER_WINDOW_START_EPOCH` and `CLONE_CLUSTER_WINDOW_END_EPOCH` for this recipe to consume; the ISO strings are retained for the user-facing WARN message in [`clone-preflight.md`](clone-preflight.md) only.

```bash
# Inputs: $FILE — absolute path to .md file
#         $CLONE_CLUSTER_WINDOW_START_EPOCH, $CLONE_CLUSTER_WINDOW_END_EPOCH
#                — integer seconds since epoch (UTC), set by
#                  scripts/detect-clone-cluster.sh
# Output: exit 0 if birthtime epoch ∈ [start, end], else exit 1
# No output to stdout. Quiet on success.

# Guard: if no cluster was detected this skill invocation, all files PROCESS
if [ -z "${CLONE_CLUSTER_WINDOW_START_EPOCH:-}" ] || [ -z "${CLONE_CLUSTER_WINDOW_END_EPOCH:-}" ]; then
  exit 1
fi

# Read birthtime as raw epoch seconds (cross-platform).
case "$(uname)" in
  Darwin)
    # BSD stat: %B = birthtime as seconds since epoch (raw integer).
    BTIME_EPOCH=$(stat -f '%B' "$FILE")
    ;;
  Linux)
    # GNU stat: %W = birthtime as seconds since epoch (0 if unavailable)
    BTIME_EPOCH=$(stat -c '%W' "$FILE")
    if [ "$BTIME_EPOCH" = "0" ]; then
      # ext4 may not store crtime — fall back to mtime, which on a freshly
      # cloned vault is usually also clone-time. Caller must accept the
      # approximation; mtime is the closest available proxy.
      BTIME_EPOCH=$(stat -c '%Y' "$FILE")
    fi
    ;;
  *)
    echo "ERROR: unsupported OS $(uname)" >&2
    exit 2
    ;;
esac

# Numeric in-window compare — POSIX `-ge` / `-le` are unambiguous.
if [ "$BTIME_EPOCH" -ge "$CLONE_CLUSTER_WINDOW_START_EPOCH" ] && \
   [ "$BTIME_EPOCH" -le "$CLONE_CLUSTER_WINDOW_END_EPOCH" ]; then
  exit 0
else
  exit 1
fi
```

The recipe self-guards: when neither `$CLONE_CLUSTER_WINDOW_START_EPOCH` nor `$CLONE_CLUSTER_WINDOW_END_EPOCH` is set (no cluster declared this invocation), recipe (a) returns 1 (PROCESS) for every file. Callers do not need to pre-check.

> **Migrating from v0.1.4.** Prior callers that exported `CLONE_CLUSTER_WINDOW_START` / `_END` (ISO strings) and relied on recipe (a) to read them must update to also export `CLONE_CLUSTER_WINDOW_START_EPOCH` / `_END_EPOCH` (integers). The detector script now emits both. The simplest update is to switch from a custom window computation to `eval "$(scripts/detect-clone-cluster.sh "$VAULT")"` which sets all four variables in one call. The ISO strings remain useful for the user-facing WARN message; the epoch values are the recipe contract.

### Recipe (b) — `has_alternate_date_source`

Returns `0` (alt source exists) or `1` (no alt source). Walks the Source Hierarchy minus filesystem birthtime — i.e. checks Prio 1 (YAML), Prio 2 (filename), Prio 3 (git) without falling through to Prio 4.

```bash
# Inputs: $FILE — absolute path to .md file
#         $VAULT — vault root (for git lookup; optional, skipped if empty)
# Output: exit 0 if any alt source yields a parseable ISO date, else exit 1.
#         Quiet on success.

# Prio 1: YAML created
# Read first 30 lines of file, look for `created:` (plain or quoted) within frontmatter
YAML_DATE=$(awk '
  BEGIN { in_fm = 0 }
  /^---$/ { in_fm = !in_fm; next }
  in_fm && /^[ ]*"?created"?:[ ]*[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    # Extract the date value
    sub(/^[ ]*"?created"?:[ ]*/, "")
    sub(/[ ].*$/, "")  # Strip time portion + trailing junk
    print
    exit
  }
' "$FILE")
if [ -n "$YAML_DATE" ]; then
  exit 0
fi

# Prio 2: Filename YYYY-MM-DD pattern
NAME=$(basename "$FILE")
if printf -- "%s" "$NAME" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
  exit 0
fi

# Prio 3: git first-commit (only if $VAULT is a git repo)
if [ -n "${VAULT:-}" ] && [ -d "$VAULT/.git" ]; then
  GIT_DATE=$(cd "$VAULT" && git log --follow --diff-filter=A --format=%aI -- "$FILE" 2>/dev/null | tail -1)
  if [ -n "$GIT_DATE" ]; then
    exit 0
  fi
fi

# No alt source found
exit 1
```

This recipe deliberately does NOT check filesystem birthtime — that is what the SKIP gate is protecting against. If you change this to fall through to Prio 4, the mode-shift breaks.

## Behavior Contract

When a skill invokes both recipes for a file:

```bash
# Pseudocode (agent reads SKILL.md, executes per-file)
if recipe_a "$FILE"; then
  # birthtime is in cluster window
  if ! recipe_b "$FILE"; then
    # no alt source → SKIP
    log_finding "$FILE" "Class-C: clone-cluster birthtime, no alt source"
    skip_file "$FILE"
  else
    # alt source → PROCESS via Source Hierarchy Prio 1-3
    proceed_with_alt_source "$FILE"
  fi
else
  # not in cluster → PROCESS normally (full Source Hierarchy including birthtime)
  proceed_normally "$FILE"
fi
```

When `clone_cluster_skip` config is `false` (escape hatch), recipe (a) is skipped entirely and all files PROCESS normally. The escape hatch exists so a user with a known-clean clone (e.g. fresh local install, no clone) can opt out of the gate. **Default is `true`.** Surfacing it now allows MASCHIN to flip to `false` per-skill in v0.1.4 review without a code change.

## Findings format

Files SKIPped under this gate are reported as Class-C in the per-skill findings file (`<VAULT>/_vault-autopilot/findings/<YYYY-MM-DD>-<skill>.md`):

```markdown
## Class C — clone-cluster birthtime, no alt source

| File | birthtime | cluster window |
|------|-----------|----------------|
| Inbox/note-foo.md | 2026-04-16T20:33:23Z | 2026-04-16T20:03Z .. 2026-04-16T21:03Z |
```

The user can then manually decide: provide a date via YAML / filename rename, or accept the absence.

## Callers

This file is referenced from the following SKILL.md files. Updates to recipes must keep the call-shape stable:

- `skills/property-enrich/SKILL.md` — Step 3a (gate before Source Hierarchy Prio 4)
- `skills/note-rename/SKILL.md` — Step 4b (gate before Source Hierarchy fallback)
- `skills/inbox-sort/SKILL.md` — Step 5b (gate before auto-enrich fallback)
- `skills/property-describe/SKILL.md` — cooldown evaluator (gate before reading birthtime for cooldown)

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-05-07 | Obi | Created. Codifies GR-3 Cell-by-Cell mode-shifts (Options B/C/D 2026-05-01) into one shared utility. v0.1.4 W2. |
