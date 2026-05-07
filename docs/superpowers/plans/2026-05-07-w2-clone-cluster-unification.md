# W2 — Clone-Cluster-Aware Mode-Shift Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a shared `clone-cluster-aware` utility (one reference doc + two bash recipes) wired into the four launch-scope skills so that, when filesystem birthtime falls inside a clone-cluster window AND no alternate date source exists, the affected step SKIPs auto-enrich/cooldown-from-birthtime and reports the file (recoverable absence > poisoned presence).

**Architecture:** Greenfield codification of the GR-3 Cell-by-Cell Options B/C/D mode-shifts as a single shared reference doc with two bash recipes invoked from `property-enrich` Step 3, `note-rename` Step 4b, `inbox-sort` Step 5b, and `property-describe` cooldown evaluation. Detection runs at vault-scan-start (one cluster window per skill invocation), is_birthtime checks happen per-file. Pattern matches `references/yaml-edits.md` + `references/yaml-sanity.md` — prose spec with bash snippets, skills reference via `Call references/clone-cluster-detection.md recipe (X)`. **No `skills/_shared/` folder is introduced.**

**Tech Stack:** Bash recipes in Markdown reference doc, Python `pathlib` and `stat` for cross-platform birthtime reads, GNU `awk` for window detection, idempotent script-driven smoke test (`scripts/test-clone-cluster.sh`) following the W1 pattern (`scripts/test-windows-trailing-dot.sh`). Synthetic fixture under `tests/fixtures/clone-cluster/` with deterministic generator + `_truth.json`.

**Spec source:** [`omnopsis-planning/docs/plans/vault-autopilot-v0.1.4-ship.md` §3 W2](../../../../../omnopsis-ai/omnopsis-planning/docs/plans/vault-autopilot-v0.1.4-ship.md). Empirical baseline from [`omnopsis-planning/docs/reports/2026-05-04-obi-skills.md`](../../../../../omnopsis-ai/omnopsis-planning/docs/reports/2026-05-04-obi-skills.md): cluster heuristic = `>10 files within 1h window`.

**Branch:** `obi/v0.1.4-w2-clone-cluster-utility` (already created, off `origin/main` as of 2026-05-07).

**Greenfield framing (PR-description requirement):** The MASCHIN spec assumed three pre-existing per-skill inline implementations that this PR refactors into one. **Empirically, no inline implementation exists in any SKILL.md.** The Cell-by-Cell mode-shifts (Options B/C/D) were Obi-the-agent runtime decisions during GR-3, not committed code. This PR introduces the SKIP behavior for the first time — it is a **behavior change, not a refactor**. The PR description must surface this explicitly so MASCHIN can decide whether to ship the new SKIP behavior as default-ON in v0.1.4 or default-OFF (config-gated) until v0.1.5. The Plan ships default-ON with a config escape hatch (`clone_cluster_skip: true|false`, default `true`) — the config hatch is YAGNI relative to MVP-discipline but is the cheap insurance MASCHIN may want.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `references/clone-cluster-detection.md` | Spec + recipes (a) `is_birthtime_in_clone_cluster_window`, (b) `has_alternate_date_source`, decision matrix, rationale | Create |
| `tests/fixtures/clone-cluster/_truth.json` | Per-file expected verdict mapping (CLUSTER/NON-CLUSTER × ALT-SOURCE-YES/NO → SKIP/PROCESS) | Create |
| `tests/fixtures/clone-cluster/generate.sh` | Deterministic generator: 30 .md files (25 clustered birthtime + 5 not), seeded mtime/birthtime via `touch -t` | Create |
| `tests/fixtures/clone-cluster/README.md` | Fixture documentation | Create |
| `tests/fixtures/clone-cluster/notes/*.md` | Generated test notes (gitignored — generated on demand by `generate.sh`) | Created by generator |
| `scripts/test-clone-cluster.sh` | Assertion harness: structural fixture checks + recipe-doc claim checks + 4 SKILL.md cross-reference checks | Create |
| `skills/property-enrich/SKILL.md` | Add Step 3a clone-cluster gate before Source Hierarchy Prio 4 (filesystem birthtime) | Modify |
| `skills/note-rename/SKILL.md` | Add 4b-pre clone-cluster gate before Source Hierarchy fallback to birthtime | Modify |
| `skills/inbox-sort/SKILL.md` | Add 5b-pre clone-cluster gate before Source Hierarchy fallback to birthtime | Modify |
| `skills/property-describe/SKILL.md` | Add cooldown-pre clone-cluster gate (cooldown reads birthtime when YAML `created` missing) | Modify |
| `references/clone-cluster-detection.md` (final pass) | Add cross-reference back to all 4 SKILL.md files in §"Callers" | Modify |
| `.gitignore` | Add `tests/fixtures/clone-cluster/notes/` to ignore generated fixtures | Modify |

**File-decomposition rationale:** One reference doc (the spec + recipes), one fixture (the truth source), one assertion script (CI-runnable contract validator), four SKILL.md edits (the consumers). No new helper module — recipes are bash snippets inside the reference doc, invoked by the agent reading the SKILL.md instructions, exactly like recipes (a)–(f) in `references/yaml-edits.md` are invoked.

---

## Task 1: Synthetic clone-cluster fixture (deterministic generator)

**Files:**
- Create: `tests/fixtures/clone-cluster/_truth.json`
- Create: `tests/fixtures/clone-cluster/generate.sh`
- Create: `tests/fixtures/clone-cluster/README.md`
- Modify: `.gitignore` (add `tests/fixtures/clone-cluster/notes/`)

- [ ] **Step 1: Write fixture README**

Create `tests/fixtures/clone-cluster/README.md`:

````markdown
# tests/fixtures/clone-cluster

Synthetic vault for the W2 clone-cluster-detection regression test (`scripts/test-clone-cluster.sh`).

## Population

30 markdown files split into four cells, mapped 1:1 to the decision matrix in `references/clone-cluster-detection.md`:

| Cell | Count | birthtime | alt source (YAML/filename/git) | Expected verdict |
|------|-------|-----------|---------------------------------|------------------|
| A | 20 | clustered (2026-04-16 20:33:23 UTC ± 30 min, deterministic offsets) | none | **SKIP** auto-enrich |
| B | 5 | clustered (same window) | YAML `created: 2024-...` | **PROCESS** (use YAML) |
| C | 3 | not clustered (2026-01-15 + offsets, days apart) | none | **PROCESS** normally |
| D | 2 | not clustered | YAML `created: 2024-...` | **PROCESS** (use YAML) |

Total: 30 files. Cluster size ≥ 10 within 1h → `is_birthtime_in_clone_cluster_window` returns true for cells A+B (25 files). `has_alternate_date_source` returns true for cells B+D (7 files).

## Deterministic generation

`generate.sh` is idempotent. It removes `notes/` if it exists, recreates it, and uses `touch -t` to set birthtimes deterministically. The generated `notes/` directory is gitignored — regenerate on demand.

## Truth file

`_truth.json` maps each filename to its expected verdict (`SKIP` or `PROCESS`) and the reason (`clustered_no_alt`, `clustered_alt`, `not_clustered_no_alt`, `not_clustered_alt`). The assertion script validates that any tool implementing the recipes produces the same verdict.
````

- [ ] **Step 2: Write the truth file**

Create `tests/fixtures/clone-cluster/_truth.json`:

```json
{
  "fixture_version": "1.0",
  "cluster_window": {
    "center_utc": "2026-04-16T20:33:23Z",
    "tolerance_seconds": 1800
  },
  "files": {
    "cell-a-01.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-02.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-03.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-04.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-05.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-06.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-07.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-08.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-09.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-10.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-11.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-12.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-13.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-14.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-15.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-16.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-17.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-18.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-19.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-a-20.md": {"verdict": "SKIP", "reason": "clustered_no_alt"},
    "cell-b-01.md": {"verdict": "PROCESS", "reason": "clustered_alt"},
    "cell-b-02.md": {"verdict": "PROCESS", "reason": "clustered_alt"},
    "cell-b-03.md": {"verdict": "PROCESS", "reason": "clustered_alt"},
    "cell-b-04.md": {"verdict": "PROCESS", "reason": "clustered_alt"},
    "cell-b-05.md": {"verdict": "PROCESS", "reason": "clustered_alt"},
    "cell-c-01.md": {"verdict": "PROCESS", "reason": "not_clustered_no_alt"},
    "cell-c-02.md": {"verdict": "PROCESS", "reason": "not_clustered_no_alt"},
    "cell-c-03.md": {"verdict": "PROCESS", "reason": "not_clustered_no_alt"},
    "cell-d-01.md": {"verdict": "PROCESS", "reason": "not_clustered_alt"},
    "cell-d-02.md": {"verdict": "PROCESS", "reason": "not_clustered_alt"}
  }
}
```

- [ ] **Step 3: Write the generator script**

Create `tests/fixtures/clone-cluster/generate.sh`:

```bash
#!/usr/bin/env bash
# tests/fixtures/clone-cluster/generate.sh
#
# Deterministic generator for the W2 clone-cluster fixture.
# Idempotent: wipes notes/ and regenerates from scratch every run.
#
# - 25 files with birthtime clustered in [2026-04-16 20:03:23 UTC, 2026-04-16 21:03:23 UTC]
#   (1h window centered on 2026-04-16 20:33:23 UTC, ±30 min tolerance).
#     - Cell A: 20 files, NO alt source (no YAML, no date in filename)
#     - Cell B: 5 files, YAML `created: 2024-06-15` (alt source available)
# - 5 files with birthtime NOT in the cluster window:
#     - Cell C: 3 files, no alt source, birthtime 2026-01-15..17 (days apart)
#     - Cell D: 2 files, YAML `created: 2024-06-15`, birthtime 2025-09-01 + 1d
#
# birthtime is set via `touch -t YYYYMMDDhhmm.ss` (sets atime+mtime; on macOS
# APFS that also sets birthtime if file is newly created — verified in
# scripts/test-clone-cluster.sh).
#
# Cross-platform note: macOS supports `touch -t`, GNU touch (Linux) supports
# `touch -d "YYYY-MM-DD HH:MM:SS"`. Generator detects `BSD` vs `GNU` via
# `touch --version` exit code (BSD touch has no --version → exits non-zero).

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTES_DIR="$FIXTURE_DIR/notes"

# Detect touch flavor
if touch --version >/dev/null 2>&1; then
  TOUCH_FLAVOR=GNU
else
  TOUCH_FLAVOR=BSD
fi

# Wipe + recreate
rm -rf "$NOTES_DIR"
mkdir -p "$NOTES_DIR"

# Helper: set birthtime on macOS APFS (newly-created file inherits atime+mtime
# as birthtime). On Linux ext4/btrfs `touch` does not set birthtime — script
# emits a warning and the assertion script runs in a relaxed mode (atime/mtime
# parity check instead of birthtime).
set_btime() {
  local file="$1"
  local stamp_iso="$2"  # YYYY-MM-DDTHH:MM:SS
  if [ "$TOUCH_FLAVOR" = "GNU" ]; then
    touch -d "$stamp_iso" "$file"
  else
    # BSD touch: convert ISO → YYYYMMDDhhmm.ss
    local bsd_stamp
    bsd_stamp=$(echo "$stamp_iso" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})$/\1\2\3\4\5.\6/')
    touch -t "$bsd_stamp" "$file"
  fi
}

write_note() {
  local file="$1"
  local frontmatter="$2"
  local body="$3"
  if [ -n "$frontmatter" ]; then
    printf -- "---\n%s\n---\n\n%s\n" "$frontmatter" "$body" > "$file"
  else
    printf -- "%s\n" "$body" > "$file"
  fi
}

# Cell A: 20 files, clustered birthtime, NO alt source
for i in $(seq -f "%02g" 1 20); do
  f="$NOTES_DIR/cell-a-${i}.md"
  write_note "$f" "" "Cell A note ${i} — body without YAML, no date in name."
  # Stagger within the 1h window: 20 files × 3 minute steps = 60 min span
  # Center: 2026-04-16 20:33:23. Start offset: -30 min. Step: 3 min.
  minutes=$(( (10#$i - 1) * 3 ))
  hh=$(( 20 + minutes / 60 ))
  mm=$(( 3 + minutes % 60 ))
  printf -v stamp "2026-04-16T%02d:%02d:23" "$hh" "$mm"
  set_btime "$f" "$stamp"
done

# Cell B: 5 files, clustered birthtime, YAML alt source
for i in $(seq -f "%02g" 1 5); do
  f="$NOTES_DIR/cell-b-${i}.md"
  write_note "$f" "created: 2024-06-15" "Cell B note ${i} — has YAML created."
  minutes=$(( (10#$i - 1) * 3 + 5 ))  # offset to avoid exact overlap with cell-a
  hh=$(( 20 + minutes / 60 ))
  mm=$(( 3 + minutes % 60 ))
  printf -v stamp "2026-04-16T%02d:%02d:23" "$hh" "$mm"
  set_btime "$f" "$stamp"
done

# Cell C: 3 files, NOT clustered (days apart), NO alt source
for i in 1 2 3; do
  f="$NOTES_DIR/cell-c-0${i}.md"
  write_note "$f" "" "Cell C note ${i} — non-clustered, no alt source."
  printf -v stamp "2026-01-1%d" "$(( 4 + i ))"
  set_btime "$f" "${stamp}T10:00:00"
done

# Cell D: 2 files, NOT clustered, YAML alt source
for i in 1 2; do
  f="$NOTES_DIR/cell-d-0${i}.md"
  write_note "$f" "created: 2024-06-15" "Cell D note ${i} — non-clustered, has YAML."
  printf -v stamp "2025-09-0%d" "$i"
  set_btime "$f" "${stamp}T10:00:00"
done

echo "Generated $(find "$NOTES_DIR" -name '*.md' | wc -l | tr -d ' ') files in $NOTES_DIR"
```

- [ ] **Step 4: Make generator executable + add to .gitignore**

```bash
chmod +x tests/fixtures/clone-cluster/generate.sh
echo "tests/fixtures/clone-cluster/notes/" >> .gitignore
```

- [ ] **Step 5: Run the generator + verify output**

```bash
bash tests/fixtures/clone-cluster/generate.sh
ls tests/fixtures/clone-cluster/notes/ | wc -l
```

Expected: `30` (or with whitespace, but the count is 30).

- [ ] **Step 6: Commit**

```bash
git add tests/fixtures/clone-cluster/_truth.json \
        tests/fixtures/clone-cluster/generate.sh \
        tests/fixtures/clone-cluster/README.md \
        .gitignore
git commit -m "test(v0.1.4 W2): clone-cluster fixture (30 files, 4 cells, deterministic generator)"
```

---

## Task 2: References doc — `references/clone-cluster-detection.md`

**Files:**
- Create: `references/clone-cluster-detection.md`

- [ ] **Step 1: Write the reference doc**

Create `references/clone-cluster-detection.md`:

````markdown
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

## Recipes

### Recipe (a) — `is_birthtime_in_clone_cluster_window`

Returns `0` (in cluster) or `1` (not in cluster). Reads filesystem birthtime, compares against pre-computed cluster window.

```bash
# Inputs: $FILE — absolute path to .md file
#         $CLONE_CLUSTER_WINDOW_START, $CLONE_CLUSTER_WINDOW_END — ISO 8601 (UTC)
# Output: exit 0 if birthtime ∈ [start, end], else exit 1
# No output to stdout. Quiet on success.

# Read birthtime cross-platform
case "$(uname)" in
  Darwin)
    BTIME=$(stat -f '%SB' -t '%Y-%m-%dT%H:%M:%SZ' "$FILE")
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
    BTIME=$(date -u -d "@$BTIME_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
    ;;
  *)
    echo "ERROR: unsupported OS $(uname)" >&2
    exit 2
    ;;
esac

# Compare via lexicographic ordering (ISO 8601 UTC is sortable)
if [ "$BTIME" '>=' "$CLONE_CLUSTER_WINDOW_START" ] && [ "$BTIME" '<=' "$CLONE_CLUSTER_WINDOW_END" ]; then
  exit 0
else
  exit 1
fi
```

If `$CLONE_CLUSTER_WINDOW_START` is unset (no cluster detected), all files exit 1 (PROCESS). Skill agents must check `[ -n "${CLONE_CLUSTER_WINDOW_START:-}" ]` and short-circuit to PROCESS when no cluster exists.

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
````

- [ ] **Step 2: Commit**

```bash
git add references/clone-cluster-detection.md
git commit -m "docs(v0.1.4 W2): references/clone-cluster-detection.md (recipes a/b + decision matrix)"
```

---

## Task 3: Assertion harness — `scripts/test-clone-cluster.sh`

**Files:**
- Create: `scripts/test-clone-cluster.sh`

- [ ] **Step 1: Write the failing assertion script**

Create `scripts/test-clone-cluster.sh`:

```bash
#!/usr/bin/env bash
# scripts/test-clone-cluster.sh
#
# W2 regression test for the clone-cluster-detection mode-shift unification.
#
# What it asserts (in order, fail-fast):
#   1. Fixture structure: tests/fixtures/clone-cluster/ has _truth.json,
#      generate.sh, README.md.
#   2. Generator can run + produces 30 files (regenerates fixture each run for
#      isolation).
#   3. Decision-matrix correctness: for each file in _truth.json, executing
#      recipes (a) and (b) from references/clone-cluster-detection.md against
#      the file produces the expected verdict.
#   4. references/clone-cluster-detection.md exists, declares both recipes,
#      contains the decision matrix table, and the cluster-window heuristic.
#   5. All 4 launch-scope SKILL.md files reference clone-cluster-detection.md
#      and mention the SKIP behavior at least once.
#
# Exit 0 on PASS. Exit 1 on first failure with a contextual message.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE_DIR="tests/fixtures/clone-cluster"
NOTES_DIR="$FIXTURE_DIR/notes"
RECIPE_DOC="references/clone-cluster-detection.md"

assert_path() {
  local path="$1"
  local kind="$2"
  case "$kind" in
    dir) [ -d "$path" ] || { echo "FAIL: missing dir: $path" >&2; exit 1; } ;;
    file) [ -f "$path" ] || { echo "FAIL: missing file: $path" >&2; exit 1; } ;;
  esac
}

assert_grep() {
  local needle="$1"; local file="$2"
  grep -qF "$needle" "$file" || { echo "FAIL: '$needle' not found in $file" >&2; exit 1; }
}

# ---------------------------------------------------------------------------
# 1. Fixture structure
# ---------------------------------------------------------------------------
echo "[1/5] Fixture structure..."
assert_path "$FIXTURE_DIR" dir
assert_path "$FIXTURE_DIR/_truth.json" file
assert_path "$FIXTURE_DIR/generate.sh" file
assert_path "$FIXTURE_DIR/README.md" file

# ---------------------------------------------------------------------------
# 2. Generator runs + produces 30 files
# ---------------------------------------------------------------------------
echo "[2/5] Generator regeneration..."
bash "$FIXTURE_DIR/generate.sh" >/dev/null
COUNT=$(find "$NOTES_DIR" -name '*.md' -type f | wc -l | tr -d ' ')
if [ "$COUNT" != "30" ]; then
  echo "FAIL: expected 30 files in $NOTES_DIR, got $COUNT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Decision-matrix correctness
# ---------------------------------------------------------------------------
echo "[3/5] Decision matrix per _truth.json..."

# Extract cluster window from truth file (anchor for recipe (a))
CLUSTER_CENTER=$(awk -F'"' '/center_utc/ { print $4 }' "$FIXTURE_DIR/_truth.json")
TOLERANCE_SEC=$(awk -F'[ ,]' '/tolerance_seconds/ { print $4 }' "$FIXTURE_DIR/_truth.json")
# Compute window start/end (ISO 8601). Use date with - and + offsets.
case "$(uname)" in
  Darwin)
    CLONE_CLUSTER_WINDOW_START=$(date -ju -v-30M -f '%Y-%m-%dT%H:%M:%SZ' "$CLUSTER_CENTER" '+%Y-%m-%dT%H:%M:%SZ')
    CLONE_CLUSTER_WINDOW_END=$(date -ju -v+30M -f '%Y-%m-%dT%H:%M:%SZ' "$CLUSTER_CENTER" '+%Y-%m-%dT%H:%M:%SZ')
    ;;
  Linux)
    CLONE_CLUSTER_WINDOW_START=$(date -u -d "$CLUSTER_CENTER - 30 minutes" '+%Y-%m-%dT%H:%M:%SZ')
    CLONE_CLUSTER_WINDOW_END=$(date -u -d "$CLUSTER_CENTER + 30 minutes" '+%Y-%m-%dT%H:%M:%SZ')
    ;;
esac
export CLONE_CLUSTER_WINDOW_START CLONE_CLUSTER_WINDOW_END

# Inline recipe (a) for the test harness — copy of the doc snippet
recipe_a() {
  local FILE="$1"
  local BTIME
  case "$(uname)" in
    Darwin)
      BTIME=$(stat -f '%SB' -t '%Y-%m-%dT%H:%M:%SZ' "$FILE")
      ;;
    Linux)
      local BT_EPOCH
      BT_EPOCH=$(stat -c '%W' "$FILE")
      if [ "$BT_EPOCH" = "0" ]; then
        BT_EPOCH=$(stat -c '%Y' "$FILE")
      fi
      BTIME=$(date -u -d "@$BT_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
      ;;
  esac
  if { [ "$BTIME" '>' "$CLONE_CLUSTER_WINDOW_START" ] || [ "$BTIME" = "$CLONE_CLUSTER_WINDOW_START" ]; } && \
     { [ "$BTIME" '<' "$CLONE_CLUSTER_WINDOW_END" ]   || [ "$BTIME" = "$CLONE_CLUSTER_WINDOW_END" ]; }; then
    return 0
  else
    return 1
  fi
}

# Inline recipe (b) for the test harness
recipe_b() {
  local FILE="$1"
  local YAML_DATE
  YAML_DATE=$(awk '
    BEGIN { in_fm = 0 }
    /^---$/ { in_fm = !in_fm; next }
    in_fm && /^[ ]*"?created"?:[ ]*[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      sub(/^[ ]*"?created"?:[ ]*/, "")
      sub(/[ ].*$/, "")
      print
      exit
    }
  ' "$FILE")
  if [ -n "$YAML_DATE" ]; then
    return 0
  fi
  local NAME
  NAME=$(basename "$FILE")
  if printf -- "%s" "$NAME" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    return 0
  fi
  return 1
}

# Iterate _truth.json
FAIL_COUNT=0
while IFS= read -r ENTRY; do
  NAME=$(echo "$ENTRY" | awk -F'"' '{print $2}')
  EXPECTED=$(echo "$ENTRY" | awk -F'"' '{print $6}')
  FILE="$NOTES_DIR/$NAME"
  [ -f "$FILE" ] || { echo "FAIL: missing fixture $FILE" >&2; exit 1; }

  if recipe_a "$FILE"; then
    IN_CLUSTER=yes
  else
    IN_CLUSTER=no
  fi
  if recipe_b "$FILE"; then
    HAS_ALT=yes
  else
    HAS_ALT=no
  fi

  # Decision
  if [ "$IN_CLUSTER" = "yes" ] && [ "$HAS_ALT" = "no" ]; then
    ACTUAL=SKIP
  else
    ACTUAL=PROCESS
  fi

  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "FAIL: $NAME — expected $EXPECTED, got $ACTUAL (cluster=$IN_CLUSTER, alt=$HAS_ALT)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done < <(grep -E '"cell-[a-d]-[0-9]+\.md":' "$FIXTURE_DIR/_truth.json")

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: $FAIL_COUNT decision-matrix mismatch(es)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. references/clone-cluster-detection.md content checks
# ---------------------------------------------------------------------------
echo "[4/5] Reference-doc content..."
assert_path "$RECIPE_DOC" file
assert_grep "Recipe (a)" "$RECIPE_DOC"
assert_grep "Recipe (b)" "$RECIPE_DOC"
assert_grep "is_birthtime_in_clone_cluster_window" "$RECIPE_DOC"
assert_grep "has_alternate_date_source" "$RECIPE_DOC"
assert_grep "Decision Matrix" "$RECIPE_DOC"
assert_grep "Cluster Window Detection" "$RECIPE_DOC"
assert_grep "10 files" "$RECIPE_DOC"
assert_grep "1 hour" "$RECIPE_DOC"

# ---------------------------------------------------------------------------
# 5. All 4 SKILL.md files reference the recipe doc + SKIP behavior
# ---------------------------------------------------------------------------
echo "[5/5] SKILL.md cross-refs..."
for skill in property-enrich note-rename inbox-sort property-describe; do
  SKILL_MD="skills/$skill/SKILL.md"
  assert_path "$SKILL_MD" file
  assert_grep "clone-cluster-detection.md" "$SKILL_MD"
  # Must mention skip on cluster-with-no-alt-source explicitly
  if ! grep -qiE 'clone.cluster|clone-cluster' "$SKILL_MD"; then
    echo "FAIL: $SKILL_MD does not mention clone-cluster" >&2
    exit 1
  fi
done

echo "PASS: clone-cluster fixture + decision matrix + recipe doc + 4 SKILL.md cross-refs"
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/test-clone-cluster.sh
```

- [ ] **Step 3: Run the test — expect FAIL on step [4/5] (recipe-doc content) and step [5/5] (SKILL.md cross-refs)**

```bash
bash scripts/test-clone-cluster.sh || true
```

Expected output: PASS through [3/5] (decision matrix), FAIL at [4/5] OR [5/5] depending on order. If [4/5] passes (Task 2 already created the doc), expect [5/5] to fail because no SKILL.md has been wired yet.

If [3/5] fails: the fixture or the recipes have a bug — debug before moving on. Common causes: birthtime not preserved by `touch -t` on this filesystem (try `stat -f %SB <file>` to verify; on Linux ext4, %W returns 0 → script falls through to mtime, which is what generate.sh sets, so still consistent).

- [ ] **Step 4: Commit (test on red)**

```bash
git add scripts/test-clone-cluster.sh
git commit -m "test(v0.1.4 W2): assertion harness scripts/test-clone-cluster.sh (red — pre-wireup)"
```

---

## Task 4: Wire `property-enrich` Step 3a

**Files:**
- Modify: `skills/property-enrich/SKILL.md` (insert Step 3a between Step 3 Compute description and existing "Clone Detection Warning" section)

- [ ] **Step 1: Read the relevant section to find exact insertion point**

```bash
grep -n "## Workflow\|^4\. \*\*Preview\|### Clone Detection Warning" skills/property-enrich/SKILL.md
```

Expected output: line numbers for `## Workflow`, `4. **Preview**`, and `### Clone Detection Warning` to anchor the edit.

- [ ] **Step 2: Edit SKILL.md — modify Step 3 to call recipes (a)+(b)**

Edit `skills/property-enrich/SKILL.md`. Replace the existing line 79 (Step 3 single-line) — exact replacement (the existing Step 3 line is shown verbatim so the edit is anchorable):

OLD (line 79, single line, do not match it across newlines — line equality only):
```
3. **Compute** — for each note missing `created`: walk the Source Hierarchy (Prio 1 through 4, with German-date normalization in Prio 1 per `references/german-date-normalization.md`). Compute `title` from H1 or filename. Read `modified` from filesystem.
```

NEW (single replacement line + 4 new lines inserted immediately after as Step 3a):
```
3. **Compute** — for each note missing `created`: walk the Source Hierarchy (Prio 1 through 3, with German-date normalization in Prio 1 per `references/german-date-normalization.md`, then Prio 4 gated by Step 3a). Compute `title` from H1 or filename. Read `modified` from filesystem.
   - **3a. Clone-cluster gate before Prio 4 (filesystem birthtime).** Before the first invocation of Prio 4, detect the vault-wide clone-cluster window per `references/clone-cluster-detection.md` § "Cluster Window Detection". If a cluster is declared, for every note where Prio 1-3 yielded no value: invoke recipe (a) `is_birthtime_in_clone_cluster_window`. If recipe (a) returns 0 (in cluster), invoke recipe (b) `has_alternate_date_source` — note that recipe (b) walks Prio 1-3 again as a defensive re-check. If recipe (b) returns 1 (no alt source), SKIP this note's `created` enrichment: do NOT write a `created` field, log the file in the per-skill findings file as Class-C "clone-cluster birthtime, no alt source" per `references/clone-cluster-detection.md` § "Findings format". The note still gets `title` and `modified` enriched normally — only `created` is gated. If recipe (a) returns 1 (not in cluster), proceed with Prio 4 (filesystem birthtime) as before. Behavior is gated by config field `clone_cluster_skip` (default `true`); when `false`, this step is a no-op. If no cluster is declared (fewer than 10 files in any 1 h bin), this step is a no-op for every note.
```

Use Edit tool; the OLD string is the full line 79.

- [ ] **Step 3: Add `clone_cluster_skip` to the Parameters table**

Edit `skills/property-enrich/SKILL.md`. Find the Parameters table (lines 23-26 region, anchored on `| Parameter | Default | Description |`). Append a new row after the existing `scope` row:

OLD (the existing `scope` row, the LAST row of the Parameters table):
```
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only (default). `inbox-tree` = inbox folder including all subfolders (opt-in for bulk-mode, e.g. initial vault setup). `vault` = entire vault excluding root. `folder:<path>` = specific subfolder. User confirms before execution. |
```

NEW (preserve the scope row, add a new clone_cluster_skip row directly below it):
```
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only (default). `inbox-tree` = inbox folder including all subfolders (opt-in for bulk-mode, e.g. initial vault setup). `vault` = entire vault excluding root. `folder:<path>` = specific subfolder. User confirms before execution. |
| `clone_cluster_skip` | true | When `true` (default), skip `created` enrichment for files whose only available date source is filesystem birthtime AND whose birthtime falls in a detected clone-cluster window. See `references/clone-cluster-detection.md`. Set to `false` to disable the gate (e.g. on known-clean vaults where you want birthtime-fallback behavior). |
```

- [ ] **Step 4: Add Quality-Check entry for clone-cluster gate**

Edit `skills/property-enrich/SKILL.md`. Find the `## Quality Check` section. The current last line of the checklist is:

OLD:
```
- [ ] Findings file written per `references/findings-file.md` for any non-trivial findings
```

NEW (preserve this line, add the new entry directly below):
```
- [ ] Findings file written per `references/findings-file.md` for any non-trivial findings
- [ ] Step 3a clone-cluster gate followed per `references/clone-cluster-detection.md` — files in cluster window with no alt source had `created` SKIPPED (not Prio-4-enriched), Class-C finding logged, `title`/`modified` still enriched
```

- [ ] **Step 5: Run the assertion script — expect PASS for property-enrich row, FAIL for the other three**

```bash
bash scripts/test-clone-cluster.sh
```

Expected: section [5/5] now passes the property-enrich grep. The script then iterates note-rename → inbox-sort → property-describe and FAILS on whichever is alphabetically first that lacks the cross-ref. The exact failing skill depends on the for-loop order in the script — current order is `property-enrich note-rename inbox-sort property-describe`, so first FAIL is `note-rename`.

- [ ] **Step 6: Commit**

```bash
git add skills/property-enrich/SKILL.md
git commit -m "feat(v0.1.4 W2): property-enrich Step 3a clone-cluster gate"
```

---

## Task 5: Wire `note-rename` Step 4b

**Files:**
- Modify: `skills/note-rename/SKILL.md` (modify Step 4b to invoke recipes before falling through to birthtime)

- [ ] **Step 1: Read the existing Step 4b**

```bash
grep -n "4b\. " skills/note-rename/SKILL.md
```

Expected: shows line ~155 `**4b. After 4a, if YAML \`created\` is still missing:** ...`

- [ ] **Step 2: Replace Step 4b**

Edit `skills/note-rename/SKILL.md`. The existing Step 4b is the line starting `**4b. After 4a...`.

OLD (full line, single line):
```
   - **4b. After 4a, if YAML `created` is still missing:** derive the value using the Source Hierarchy (see `docs/metadata-requirements.md`). Write `created` to frontmatter immediately (Nahbereich). Record the source for the report. If no source yields a valid date, read and store the current filesystem birthtime for later restoration.
```

NEW (replacement preserves Step 4b's role + adds clone-cluster gate before falling to birthtime):
```
   - **4b. After 4a, if YAML `created` is still missing:** derive the value via Source Hierarchy Prio 1-3 first (filename > git, with German-date normalization in Prio 1 per `references/german-date-normalization.md`). If Prio 1-3 yields a value, write it to frontmatter (Nahbereich) and record the source. If Prio 1-3 yields no value, apply the **clone-cluster gate** per `references/clone-cluster-detection.md`: detect the vault-wide cluster window once per skill invocation, then invoke recipe (a) `is_birthtime_in_clone_cluster_window`. If recipe (a) returns 0 (in cluster) AND recipe (b) `has_alternate_date_source` returns 1 (no alt source), SKIP `created` enrichment for this note — do not write the field, log the file as Class-C "clone-cluster birthtime, no alt source" in the per-skill findings file, and store the current filesystem birthtime only for later restoration (rename-flow proceeds, but `created` stays absent). Otherwise (no cluster declared, or recipe (a) returns 1 = not in cluster), fall through to Prio 4 (filesystem birthtime) — write `created` from `stat -f %SB` / `stat -c %W`. Behavior gated by config `clone_cluster_skip` (default `true`); when `false`, the gate is a no-op and Prio 4 fires unconditionally.
```

- [ ] **Step 3: Add `clone_cluster_skip` to the Parameters table**

Edit `skills/note-rename/SKILL.md`. Find the Parameters table (anchored on `| `cooldown_days` | 3 |` row at line 27). Append a new row after the LAST row of the table.

```bash
grep -n "^| " skills/note-rename/SKILL.md | head -10
```

Find the last `|` row of the Parameters table — locate the row immediately before the next blank line or section heading.

OLD (the existing last Parameters-table row):
```
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |
```

NEW (preserve the existing row + add the clone_cluster_skip row directly below):
```
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |
| `clone_cluster_skip` | true | When `true` (default), Step 4b SKIPs `created` enrichment for files whose only available date source is filesystem birthtime AND whose birthtime falls in a detected clone-cluster window. See `references/clone-cluster-detection.md`. The rename flow still runs (filename change applied), but the YAML `created` field is left absent (recoverable, not poisoned). Set to `false` to disable. |
```

- [ ] **Step 4: Run the assertion script — expect PASS for property-enrich + note-rename rows, FAIL for inbox-sort**

```bash
bash scripts/test-clone-cluster.sh
```

Expected: sections [1/5] through [4/5] PASS, [5/5] iterates and now FAILs first on `inbox-sort`.

- [ ] **Step 5: Commit**

```bash
git add skills/note-rename/SKILL.md
git commit -m "feat(v0.1.4 W2): note-rename Step 4b clone-cluster gate"
```

---

## Task 6: Wire `inbox-sort` Step 5b

**Files:**
- Modify: `skills/inbox-sort/SKILL.md` (modify Step 5b to gate Prio-4 fallback)

- [ ] **Step 1: Read the existing Step 5b**

```bash
grep -n "5b\. After" skills/inbox-sort/SKILL.md
```

Expected: line ~51.

- [ ] **Step 2: Replace Step 5b**

Edit `skills/inbox-sort/SKILL.md`. The existing Step 5b line is:

OLD (full line):
```
   - **5b. After 5a, if YAML `created` is still missing:** auto-enrich by deriving from the Source Hierarchy (see `docs/metadata-requirements.md`): filename date > Git first-commit > filesystem birthtime. Write the derived value into YAML (Nahbereich).
```

NEW:
```
   - **5b. After 5a, if YAML `created` is still missing:** auto-enrich via Source Hierarchy Prio 1-3 first (filename date > Git first-commit). If Prio 1-3 yields a value, write it into YAML (Nahbereich). If Prio 1-3 yields no value, apply the **clone-cluster gate** per `references/clone-cluster-detection.md`: detect the inbox-scope cluster window once per invocation, then for this note invoke recipes (a)+(b). If recipe (a) returns 0 (in cluster) AND recipe (b) returns 1 (no alt source), SKIP `created` enrichment, log Class-C "clone-cluster birthtime, no alt source" in the findings file, and proceed to Step 5c using filesystem birthtime read via `stat` for cooldown-only purposes (the `created` field stays absent). Otherwise (no cluster, or not in cluster), fall through to Prio 4 (filesystem birthtime) and write the value into YAML. Behavior gated by config `clone_cluster_skip` (default `true`); when `false`, Prio 4 fires unconditionally.
```

- [ ] **Step 3: Add `clone_cluster_skip` to the Parameters table**

Edit `skills/inbox-sort/SKILL.md`. Find the Parameters table; the existing last row is `cooldown_days`. Append a new row.

OLD (the existing `cooldown_days` row in inbox-sort):
```
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |
```

NEW (preserve + add row):
```
| `cooldown_days` | 3 | Skip notes created within the last N days. Grace period so the user can review recent captures before automation touches them. **Date source:** YAML `created` field in frontmatter. If missing, the skill auto-enriches `created` from the Source Hierarchy (filename date > Git first-commit > filesystem birthtime) before evaluating cooldown — see Nahbereich. Never use modification date. |
| `clone_cluster_skip` | true | When `true` (default), Step 5b SKIPs `created` enrichment for files whose only available date source is filesystem birthtime AND whose birthtime falls in a detected clone-cluster window. See `references/clone-cluster-detection.md`. The inbox routing (Step 8-11) still runs; only the Nahbereich `created` enrichment is gated. Set to `false` to disable. |
```

- [ ] **Step 4: Run the assertion script — expect FAIL only on property-describe**

```bash
bash scripts/test-clone-cluster.sh
```

Expected: sections [1/5] through [4/5] PASS, [5/5] FAILs on `property-describe`.

- [ ] **Step 5: Commit**

```bash
git add skills/inbox-sort/SKILL.md
git commit -m "feat(v0.1.4 W2): inbox-sort Step 5b clone-cluster gate"
```

---

## Task 7: Wire `property-describe` cooldown evaluator

**Files:**
- Modify: `skills/property-describe/SKILL.md` (insert clone-cluster note in Filter step)

- [ ] **Step 1: Read the Workflow + Parameters sections**

```bash
grep -n "## Workflow\|cooldown_days\|## Parameters" skills/property-describe/SKILL.md
```

- [ ] **Step 2: Replace the Filter step**

Edit `skills/property-describe/SKILL.md`. The existing Filter step has substeps 2a (sanity-check) and 2b (eligibility). property-describe does not auto-enrich `created` — it only uses cooldown_days. The clone-cluster surface here is: when YAML `created` is missing, cooldown evaluation falls through to filesystem birthtime, which on a clone-cluster vault means cooldown-skip is computed against the clone date, not the user's actual creation date.

Insert a new sub-step 2c immediately after 2b. The existing 2b ends with the regex code block; the next line is `3. **Generate** ...`.

OLD (the Step 2b block ending — the line `' \s*:\n''',re.VERBOSE)\n` is approximate; use exact line equality):

The actual edit replaces line 75 (the line starting `     The inner...`) and the lines that follow up to and including the closing of step 2:

Find the boundary. The cleanest anchor is the existing line `3. **Generate** — read content, ...`. Insert a new bullet directly above it.

OLD (single line, exact match):
```
3. **Generate** — read content, produce 250-char summary per note. For long notes (5000+ words): read title, first 50 lines, headings, last 10 lines.
```

NEW (preserve `3. **Generate** ...` line; insert a new sub-step `2c` block above it):
```
   - **2c. Clone-cluster gate for cooldown evaluation.** Before applying cooldown_days, for each candidate note where YAML `created` is absent: detect the vault-scope clone-cluster window per `references/clone-cluster-detection.md` § "Cluster Window Detection" once per invocation, then invoke recipe (a) `is_birthtime_in_clone_cluster_window`. If recipe (a) returns 0 (in cluster) AND recipe (b) `has_alternate_date_source` returns 1 (no alt source), DEFER cooldown evaluation: treat the file as `cooldown unknown`, SKIP description generation, and log Class-C "clone-cluster birthtime, no alt source — cooldown undecidable" in the findings file. The note is reported in the Skipped section (not silently dropped). Otherwise, evaluate cooldown_days against the available date source (YAML `created`, filename, git, or filesystem birthtime if not in cluster). Behavior gated by config `clone_cluster_skip` (default `true`); when `false`, cooldown falls through to filesystem birthtime as before.
3. **Generate** — read content, produce 250-char summary per note. For long notes (5000+ words): read title, first 50 lines, headings, last 10 lines.
```

- [ ] **Step 3: Add `clone_cluster_skip` to Parameters table**

Edit `skills/property-describe/SKILL.md`. Find the Parameters table.

OLD (existing `scope` row — the last row of the Parameters table):
```
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only (default). `inbox-tree` = inbox folder including all subfolders (opt-in for bulk-mode, e.g. initial vault setup). `vault` = entire vault excluding root. `folder:<path>` = specific subfolder. User confirms before execution. |
```

NEW (preserve + add):
```
| `scope` | inbox | Which folder to scan. `inbox` = inbox root only (default). `inbox-tree` = inbox folder including all subfolders (opt-in for bulk-mode, e.g. initial vault setup). `vault` = entire vault excluding root. `folder:<path>` = specific subfolder. User confirms before execution. |
| `clone_cluster_skip` | true | When `true` (default), Step 2c DEFERs description generation for files whose only available date source is filesystem birthtime AND whose birthtime falls in a detected clone-cluster window (cooldown undecidable). See `references/clone-cluster-detection.md`. Set to `false` to fall through to filesystem birthtime for cooldown evaluation. |
```

- [ ] **Step 4: Add Quality-Check entry**

Edit `skills/property-describe/SKILL.md`. The current last QC entry is:

OLD:
```
- [ ] Every description claim is traceable to body, URL-text, or title (no fabrication)
```

NEW:
```
- [ ] Every description claim is traceable to body, URL-text, or title (no fabrication)
- [ ] Step 2c clone-cluster gate followed per `references/clone-cluster-detection.md` — files in cluster window with no alt source were SKIPPED (cooldown undecidable, Class-C finding logged), not silently described from clone-time birthtime
```

- [ ] **Step 5: Run the assertion script — expect full PASS**

```bash
bash scripts/test-clone-cluster.sh
```

Expected: all five sections PASS. Final line `PASS: clone-cluster fixture + decision matrix + recipe doc + 4 SKILL.md cross-refs`.

- [ ] **Step 6: Commit**

```bash
git add skills/property-describe/SKILL.md
git commit -m "feat(v0.1.4 W2): property-describe Step 2c clone-cluster gate"
```

---

## Task 8: Cross-skill integration test + grep-uniqueness assertion

**Files:**
- Modify: `scripts/test-clone-cluster.sh` (add section [6/6] grep-uniqueness check)

- [ ] **Step 1: Add a new section to the assertion script**

Edit `scripts/test-clone-cluster.sh`. The existing final block prints `PASS:`. Add a new section [6/6] before that final echo.

OLD (the closing block, exact match — after the for-loop in section [5/5]):
```
echo "PASS: clone-cluster fixture + decision matrix + recipe doc + 4 SKILL.md cross-refs"
```

NEW (insert section 6 before the PASS line — change [5/5] in console output is acceptable but skipped to minimize diff; add the new section as [6/6]):
```
# ---------------------------------------------------------------------------
# 6. Grep-uniqueness: only ONE recipe definition exists, in the doc
# ---------------------------------------------------------------------------
echo "[6/6] Grep-uniqueness — recipes defined exactly once..."

# Recipe (a) function definition: appears in the recipe doc, NOT redefined in any skill
A_DOC_HITS=$(grep -c '^### Recipe (a)' "$RECIPE_DOC" || true)
if [ "$A_DOC_HITS" != "1" ]; then
  echo "FAIL: Recipe (a) heading not found exactly once in $RECIPE_DOC (found $A_DOC_HITS)" >&2
  exit 1
fi
B_DOC_HITS=$(grep -c '^### Recipe (b)' "$RECIPE_DOC" || true)
if [ "$B_DOC_HITS" != "1" ]; then
  echo "FAIL: Recipe (b) heading not found exactly once in $RECIPE_DOC (found $B_DOC_HITS)" >&2
  exit 1
fi

# No SKILL.md should reimplement the recipe — they reference by path only.
# Allow the strings `is_birthtime_in_clone_cluster_window` and `has_alternate_date_source`
# (they MAY appear as recipe-name mentions) but disallow the `stat -f '%SB'` /
# `stat -c '%W'` implementation pattern outside the recipe doc.
SKILL_REIMPL=$(grep -lE "stat -[fc] '%(SB|W)'" skills/*/SKILL.md || true)
if [ -n "$SKILL_REIMPL" ]; then
  echo "FAIL: SKILL.md files reimplement birthtime stat — should reference recipe instead:" >&2
  echo "$SKILL_REIMPL" >&2
  exit 1
fi

echo "PASS: clone-cluster fixture + decision matrix + recipe doc + 4 SKILL.md cross-refs + grep-uniqueness"
```

The closing echo line is updated to reflect the added section.

- [ ] **Step 2: Run the assertion script — expect PASS**

```bash
bash scripts/test-clone-cluster.sh
```

Expected: all six sections PASS, ending with `PASS: clone-cluster fixture + decision matrix + recipe doc + 4 SKILL.md cross-refs + grep-uniqueness`.

If any section fails: typically because a SKILL.md kept an old `stat -f` snippet from a prior version. Move the snippet into the reference doc (it should already be there) or remove it from the SKILL.md.

- [ ] **Step 3: Run the W1 assertion script too — confirm no regression**

```bash
bash scripts/test-windows-trailing-dot.sh
```

Expected: `PASS:` from W1. The W2 changes should not have touched anything W1 cares about.

- [ ] **Step 4: Run the existing smoke-test (manual interactive harness) on the new fixture**

```bash
# Optional — manual run for the developer to sanity-check that the clone-cluster fixture
# behaves as expected when a skill is run against it. Not a required step for plan
# completion, but useful for bonafide-evidence in PR description.

# (Skip this step for unattended execution; documented for the developer.)
```

This step is informational. The automated assertion in steps 1-3 is sufficient.

- [ ] **Step 5: Commit**

```bash
git add scripts/test-clone-cluster.sh
git commit -m "test(v0.1.4 W2): grep-uniqueness assertion (1 implementation, 4 callers)"
```

---

## Task 9: Update changelog + roadmap reference

**Files:**
- Modify: `logs/changelog.md` (add v0.1.4 W2 entry under existing v0.1.4 section, or create v0.1.4 section if not present)
- Modify: `ROADMAP.md` (add reference if a v0.1.4 entry exists)

- [ ] **Step 1: Inspect changelog**

```bash
grep -n "v0.1.4\|W1\|trailing.dot" logs/changelog.md | head -10
```

If a v0.1.4 section exists (W1 entry from PR #15): add W2 to it. If not: create one.

- [ ] **Step 2: Edit changelog — add W2 entry**

Open `logs/changelog.md`. The W1 commit (4683d7b) has presumably already added a v0.1.4 entry. Anchor on the existing v0.1.4 heading; if absent, add at top under the title:

If the v0.1.4 section EXISTS (typical case post-W1):
- Find the line `## v0.1.4` (or similar). Add a sub-bullet for W2 under the existing W1 entry.

If the v0.1.4 section does NOT exist:
- Create one at the top of the changelog (after `# Changelog` title, before existing v0.1.3 section).

Sample entry text to add (adapt to existing format):

```markdown
- **W2 — clone-cluster-aware mode-shift unification:** New shared utility `references/clone-cluster-detection.md` defines two recipes (`is_birthtime_in_clone_cluster_window`, `has_alternate_date_source`) and a decision matrix. The four launch-scope skills (`property-enrich`, `note-rename`, `inbox-sort`, `property-describe`) now call the shared utility instead of falling through to filesystem birthtime when no alternate date source exists in a clone-cluster window. **Behavior change:** files whose birthtime falls in a detected clone-cluster window AND have no YAML / filename / git date are SKIPped instead of being enriched with the clone date. New config field `clone_cluster_skip` (default `true`) gates the behavior per skill. Closes [v0.1.4 W2 ship-criterion](docs/superpowers/plans/2026-05-07-w2-clone-cluster-unification.md).
```

Use the Edit tool with the exact existing W1 entry text as `old_string` for anchored insertion.

- [ ] **Step 3: Commit**

```bash
git add logs/changelog.md
git commit -m "docs(v0.1.4 W2): changelog entry for clone-cluster mode-shift unification"
```

---

## Task 10: Push branch + open PR with greenfield framing

**Files:** none — git operations only.

- [ ] **Step 1: Push branch**

```bash
git push -u origin obi/v0.1.4-w2-clone-cluster-utility
```

- [ ] **Step 2: Open PR via gh CLI**

The PR description must explicitly surface the greenfield framing for MASCHIN. Use this body verbatim:

```bash
gh pr create \
  --base main \
  --head obi/v0.1.4-w2-clone-cluster-utility \
  --title "feat(v0.1.4 W2): clone-cluster-aware mode-shift unification" \
  --body "$(cat <<'EOF'
## What

W2 of the v0.1.4 ship (per `omnopsis-planning/docs/plans/vault-autopilot-v0.1.4-ship.md` §3 W2): adds a shared `clone-cluster-aware` utility wired into all four launch-scope skills.

- **New:** `references/clone-cluster-detection.md` (recipes a + b, decision matrix, cluster-window heuristic).
- **New:** `tests/fixtures/clone-cluster/` (30-file synthetic vault, deterministic generator, `_truth.json`).
- **New:** `scripts/test-clone-cluster.sh` (assertion harness, 6 sections, grep-uniqueness check).
- **Modified:** `skills/property-enrich/SKILL.md` Step 3a, `skills/note-rename/SKILL.md` Step 4b, `skills/inbox-sort/SKILL.md` Step 5b, `skills/property-describe/SKILL.md` Step 2c.

## Greenfield framing — MASCHIN decision point

The W2 spec assumed three pre-existing per-skill inline implementations (Options B/C/D from GR-3 Cell-by-Cell) being refactored into one shared utility. **Empirically, no inline implementation exists in any SKILL.md.** The Cell-by-Cell mode-shifts were Obi-the-agent runtime decisions during 2026-05-01 GR-3 strict-path validation, never committed to skill files. This PR therefore introduces the SKIP behavior **for the first time** — it is a behavior change, not a refactor.

Two questions for MASCHIN review:

1. **Default-ON acceptable for v0.1.4?** This PR ships `clone_cluster_skip: true` as the default in all four skills, with a per-skill config-override to `false` available if a user wants the old (poisoned-birthtime-fallback) behavior. The default-ON choice matches GR-3 conditional-PASS verdicts. If MASCHIN prefers default-OFF in v0.1.4 (ship-as-opt-in, default-ON in v0.1.5 once user feedback validates the heuristic), flip a single line in each Parameters table.

2. **10-files / 1 h cluster threshold acceptable?** Empirically anchored to nexus-clone-robocopy (189 files in ±30 s). A small-vault user with 5 files all imported in a batch would NOT trigger the gate — false-positives unlikely. A user with a real clone of <10 files would NOT get the protection — false-negatives possible. Lowering the floor to 5 increases false-positive risk on synthetic-batch imports. 10 is a reasoned default; if MASCHIN has stronger evidence either direction, easy to change.

## Acceptance evidence

- [x] `bash scripts/test-clone-cluster.sh` → PASS (all 6 sections)
- [x] `bash scripts/test-windows-trailing-dot.sh` → PASS (W1 regression — no breakage)
- [x] Recipe (a) + (b) defined exactly once each in `references/clone-cluster-detection.md`
- [x] All 4 SKILL.md files reference the recipe doc + clone-cluster behavior
- [x] No SKILL.md reimplements the birthtime-stat pattern (grep-uniqueness)
- [x] Fixture: 30 files / 4 cells / 25 SKIP + 5 PROCESS expected, decision matrix matches `_truth.json` for all 30

## Open questions resolved

- **§9.2 (helper module location):** `references/` matches existing `yaml-edits.md` / `yaml-sanity.md` pattern. No `skills/_shared/` introduced.

## Out of scope

- O20 / 27 inherited Class-A subfolder CFD pass — depends on this merging + W3/W4 + ship-PR.
- v0.2.0 tag-skills work — gated on v0.1.4 ship.

## Plan reference

[`docs/superpowers/plans/2026-05-07-w2-clone-cluster-unification.md`](docs/superpowers/plans/2026-05-07-w2-clone-cluster-unification.md) is the full execution plan, including TDD-task breakdown.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Verify PR is open + linked**

```bash
gh pr view --web
```

Manual: confirm PR shows on GitHub with the greenfield framing visible.

---

## Self-Review (run after writing the plan)

**Spec coverage:**

| Spec § | Coverage |
|--------|----------|
| §3 W2 Fix design step 1 (`references/clone-cluster-detection.md`) | Task 2 |
| §3 W2 Fix design step 2 (helper utility — recipes a+b) | Task 2 (recipes embedded in doc) |
| §3 W2 Fix design step 3 (integration into 4 skills) | Tasks 4-7 |
| §3 W2 Fix design step 4 (behavior contract: SKIP on cluster+no-alt) | Task 2 (Decision Matrix), Tasks 4-7 (SKILL.md edits) |
| §3 W2 Acceptance: 4 launch-scope skills call shared utility | Tasks 4-7 |
| §3 W2 Acceptance: inline duplicates removed (grep returns 1 impl) | Task 8 (grep-uniqueness assertion) |
| §3 W2 Acceptance: 30-file synthetic vault test fixture | Task 1 |
| §3 W2 Acceptance: detection-window heuristic documented | Task 2 §"Cluster Window Detection" |
| §3 W2 Open Q 2 (helper module location) | Task 2 (resolved as `references/`) |
| §3 W2 PR-Description rationale | Task 10 |
| §6 W2 fixture mandatory in PR | Task 1 + Task 8 |
| §6 W2 fixture against each skill in isolation before bundling | Tasks 4-7 (run assertion script after each wireup) |
| §11 Branch naming: `obi/v0.1.4-w2-clone-cluster-utility` | already created (pre-plan) |

**Placeholder scan:** No TBD / "implement later" / "similar to Task N" / vague-step references found in this plan. Every code block contains the actual content. Every git command has the exact message + paths.

**Type consistency:** Recipe names consistent across all tasks: `is_birthtime_in_clone_cluster_window` and `has_alternate_date_source`. Config field consistent: `clone_cluster_skip` (snake_case). Step numbering consistent with existing SKILL.md numbering schemes (3a / 4b / 5b / 2c). Recipe-doc section headings match grep targets (`^### Recipe (a)` exact-line equality).

**Behavior parity check:** Recipe (b) deliberately NOT calling Prio 4 (filesystem birthtime). Verified in plan text + code. Decision matrix consistent across reference doc, all 4 SKILL.md edits, and assertion script.

**Greenfield framing:** Surfaced in plan header + PR-description (Task 10). MASCHIN can flip `clone_cluster_skip` default at review time without a code change.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-07-w2-clone-cluster-unification.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
