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
  abs_min=$(( 20 * 60 + 3 + (10#$i - 1) * 3 ))
  hh=$(( abs_min / 60 ))
  mm=$(( abs_min % 60 ))
  printf -v stamp "2026-04-16T%02d:%02d:23" "$hh" "$mm"
  set_btime "$f" "$stamp"
done

# Cell B: 5 files, clustered birthtime, YAML alt source
for i in $(seq -f "%02g" 1 5); do
  f="$NOTES_DIR/cell-b-${i}.md"
  write_note "$f" "created: 2024-06-15" "Cell B note ${i} — has YAML created."
  abs_min=$(( 20 * 60 + 3 + (10#$i - 1) * 3 + 5 ))  # +5 to avoid exact overlap with cell-a
  hh=$(( abs_min / 60 ))
  mm=$(( abs_min % 60 ))
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
