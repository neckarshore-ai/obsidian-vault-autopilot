#!/usr/bin/env bash
# scripts/detect-clone-cluster.sh
#
# Scans a directory of markdown files, bucketizes filesystem birthtimes into
# 1-hour bins (UTC), and emits the dominant cluster window if any bin contains
# >= 10 files. Eval-friendly KEY=VALUE output for use in shell preflights.
#
# Usage:
#   eval "$(scripts/detect-clone-cluster.sh /path/to/vault)"
#   if [ "$CLUSTER_FOUND" = "yes" ]; then
#     echo "WARN: clone-cluster window detected"
#   fi
#
# Output keys (always):
#   CLUSTER_FOUND=yes|no
#
# When CLUSTER_FOUND=yes, additionally:
#   CLONE_CLUSTER_WINDOW_START=<ISO 8601 UTC, Z-suffixed>
#   CLONE_CLUSTER_WINDOW_END=<ISO 8601 UTC, Z-suffixed>
#   CLUSTER_FILE_COUNT=<int — file count in winning bin>
#
# Heuristic (per references/clone-cluster-detection.md "Cluster Window
# Detection"):
#   - Bin width: 1 hour, edges aligned to UTC hour.
#   - Floor: 10 files / bin minimum to declare a cluster.
#   - Window: median of winning bin's birthtimes ± 30 min (1800 sec).
#   - Tie-break: awk traversal order (rare; multi-clone vaults are out of
#     scope for v0.1.4 per W2 spec — only the most populated bin gates).
#
# Cross-platform: Darwin via `stat -f '%B'`, Linux via `stat -c '%W'` with
# `%Y` mtime fallback when birthtime is unavailable (matches the recipe-(a)
# convention in references/clone-cluster-detection.md).
#
# This script does NOT decide skill behavior. It produces detection output
# that a caller (preflight WARN, runtime SKIP-gate) interprets.

set -euo pipefail

VAULT="${1:-}"
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  # Empty/missing dir → no cluster. Callers do not stop on this — the
  # upstream LongPathsEnabled check is the data-safety gate; this is
  # informational only.
  echo "CLUSTER_FOUND=no"
  exit 0
fi

# Collect birthtime epoch seconds per .md file into a temp file (one per line)
TMP=$(mktemp -t ova-detect-cluster-XXXXXX)
trap 'rm -f "$TMP"' EXIT

case "$(uname)" in
  Darwin)
    # `stat -f '%B'` emits the birth-time epoch with a trailing newline per
    # file argument. xargs -0 is null-safe for filenames with spaces.
    find "$VAULT" -type f -name '*.md' -print0 \
      | xargs -0 stat -f '%B' 2>/dev/null > "$TMP" || true
    ;;
  Linux)
    while IFS= read -r -d '' f; do
      BT=$(stat -c '%W' "$f" 2>/dev/null || echo 0)
      if [ "$BT" = "0" ]; then
        # ext4 may not store crtime — fall back to mtime, which on a freshly
        # cloned vault is usually also clone-time. Same convention as
        # recipe-(a).
        BT=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
      fi
      printf -- '%s\n' "$BT" >> "$TMP"
    done < <(find "$VAULT" -type f -name '*.md' -print0)
    ;;
  *)
    # Unsupported OS (MINGW/CYGWIN run a separate code path via the
    # PowerShell preflight). Treat as no-cluster for safety.
    echo "CLUSTER_FOUND=no"
    exit 0
    ;;
esac

# No files in vault → no cluster
if [ ! -s "$TMP" ]; then
  echo "CLUSTER_FOUND=no"
  exit 0
fi

# Bucketize into 1-hour bins; find max-populated bin; emit count + epoch
# list for that bin if it meets the floor. Single awk pass.
WINNER=$(awk '
  BEGIN { max_count = 0; max_bin = "" }
  /^[0-9]+$/ {
    epoch = $1
    bin = int(epoch / 3600)
    count[bin]++
    if (bin in epochs) {
      epochs[bin] = epochs[bin] " " epoch
    } else {
      epochs[bin] = epoch
    }
    if (count[bin] > max_count) {
      max_count = count[bin]
      max_bin = bin
    }
  }
  END {
    if (max_count >= 10) {
      print max_count
      print epochs[max_bin]
    }
  }
' "$TMP")

if [ -z "$WINNER" ]; then
  echo "CLUSTER_FOUND=no"
  exit 0
fi

# Line 1 = count; line 2 = space-separated epoch list
COUNT=$(printf -- '%s\n' "$WINNER" | sed -n '1p')
EPOCHS=$(printf -- '%s\n' "$WINNER" | sed -n '2p')

# Compute median epoch (sort, pick middle; even-N → mean of two middles
# rounded toward zero by integer arithmetic, which is what we want for ±30min
# window placement — sub-second precision is meaningless here).
# shellcheck disable=SC2086  # word-splitting on $EPOCHS is intentional
MEDIAN=$(printf -- '%s\n' $EPOCHS | sort -n | awk '
  { a[NR] = $1 }
  END {
    if (NR % 2 == 1) {
      print a[(NR + 1) / 2]
    } else {
      print int((a[NR / 2] + a[NR / 2 + 1]) / 2)
    }
  }
')

START_EPOCH=$((MEDIAN - 1800))
END_EPOCH=$((MEDIAN + 1800))

case "$(uname)" in
  Darwin)
    START_ISO=$(date -u -r "$START_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
    END_ISO=$(date -u -r "$END_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
    ;;
  Linux)
    START_ISO=$(date -u -d "@$START_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
    END_ISO=$(date -u -d "@$END_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')
    ;;
esac

cat <<EOF
CLUSTER_FOUND=yes
CLONE_CLUSTER_WINDOW_START=$START_ISO
CLONE_CLUSTER_WINDOW_END=$END_ISO
CLUSTER_FILE_COUNT=$COUNT
EOF
