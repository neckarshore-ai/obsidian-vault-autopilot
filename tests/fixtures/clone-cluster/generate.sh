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

# Helper: set birthtime to a UTC instant on macOS APFS (newly-created file
# inherits atime+mtime as birthtime). On Linux ext4/btrfs `touch` does not
# set birthtime — script emits a warning and the assertion script runs in a
# relaxed mode (atime/mtime parity check instead of birthtime).
#
# The input is always a UTC ISO 8601 string (no TZ suffix in the param;
# implicitly UTC by contract). The function converts to epoch first, then
# applies the platform-appropriate `touch` form. This avoids the "naked ISO
# string interpreted as local time by touch" trap that the v0.1.4 W2 fixture
# hit (and v0.1.5 fixes) — the prior implementation's "convert ISO → BSD
# YYYYMMDDhhmm.ss with sed" passed the timestamp to BSD `touch -t`, which
# interprets its argument as LOCAL time. The result was an epoch shifted by
# the local-UTC offset relative to the documented UTC instant.
set_btime() {
  local file="$1"
  local stamp_iso_utc="$2"  # YYYY-MM-DDTHH:MM:SS, implicitly UTC

  # Convert UTC ISO → epoch (cross-platform).
  local epoch
  if [ "$TOUCH_FLAVOR" = "GNU" ]; then
    # GNU date with -u and -d "ISO" treats the input as UTC.
    epoch=$(date -u -d "$stamp_iso_utc" '+%s')
  else
    # BSD date -ju -f parses according to the format; -j = no set, -u = UTC.
    epoch=$(date -ju -f '%Y-%m-%dT%H:%M:%S' "$stamp_iso_utc" '+%s')
  fi

  if [ "$TOUCH_FLAVOR" = "GNU" ]; then
    # GNU touch supports `-d "@$epoch"` for direct epoch set — bypasses TZ.
    touch -d "@$epoch" "$file"
  else
    # BSD touch -t reads its argument as LOCAL time. Format the epoch as
    # the local-time equivalent so the resulting epoch matches our UTC
    # instant. Without -u → local-time format.
    local bsd_stamp
    bsd_stamp=$(date -j -r "$epoch" '+%Y%m%d%H%M.%S')
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

# Cell A: 20 files, clustered birthtime (UTC), NO alt source.
# Stagger: 20 files × 2-minute steps = 38 min span. Starts at 20:03:23 UTC,
# ends at 20:41:23 UTC. Whole spread fits inside any reasonable detector
# window (median ± 30 min) for these 25 cluster files. The v0.1.4 W2 design
# used 3-min steps × 20 = 57-min span, which only fit because the broken
# string-compare in recipe (a) was symmetrically wrong with the broken
# generator (passes by coincidence, see v0.1.5 changelog). With epoch-correct
# birthtimes and the detector's median-±30-min window, the wider spread
# would push 3 edge files outside the window. Shrinking to 2-min step keeps
# the design intent (all 20 cell-A files SKIP) while making the test
# deterministic against the real detector output.
for i in $(seq -f "%02g" 1 20); do
  f="$NOTES_DIR/cell-a-${i}.md"
  write_note "$f" "" "Cell A note ${i} — body without YAML, no date in name."
  abs_min=$(( 20 * 60 + 3 + (10#$i - 1) * 2 ))
  hh=$(( abs_min / 60 ))
  mm=$(( abs_min % 60 ))
  printf -v stamp "2026-04-16T%02d:%02d:23" "$hh" "$mm"
  set_btime "$f" "$stamp"
done

# Cell B: 5 files, clustered birthtime (UTC), YAML alt source.
# Uses 3-min step + 5-min offset from cell-A start (20:08, 20:11, 20:14,
# 20:17, 20:20). Seconds field set to :47 so even if a minute aligns with
# a cell-A minute the epochs don't collide (cell-A uses :23). All 5 files
# fall well inside the detector's median-±30-min window.
for i in $(seq -f "%02g" 1 5); do
  f="$NOTES_DIR/cell-b-${i}.md"
  write_note "$f" "created: 2024-06-15" "Cell B note ${i} — has YAML created."
  abs_min=$(( 20 * 60 + 3 + (10#$i - 1) * 3 + 5 ))
  hh=$(( abs_min / 60 ))
  mm=$(( abs_min % 60 ))
  printf -v stamp "2026-04-16T%02d:%02d:47" "$hh" "$mm"
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
