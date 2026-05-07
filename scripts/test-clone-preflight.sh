#!/usr/bin/env bash
# scripts/test-clone-preflight.sh
#
# W3 regression test for the clone-cluster preflight (F3 — robocopy preflight).
#
# What it asserts (in order, fail-fast):
#   1. scripts/detect-clone-cluster.sh exists and is executable.
#   2. Detector against W2 fixture (tests/fixtures/clone-cluster/notes/) emits
#      CLUSTER_FOUND=yes with a window enclosing the fixture's center_utc and
#      a CLUSTER_FILE_COUNT >= 10 (the configured cluster floor).
#   3. Detector against a synthetic no-cluster directory (5 files, all touched
#      now — under the 10-file floor) emits CLUSTER_FOUND=no.
#   4. Detector against an empty directory emits CLUSTER_FOUND=no.
#   5. references/windows-preflight.md has a clone-cluster preflight section
#      that emits WARN (not STOP), references the detector script, and
#      references clone-cluster-detection.md for the runtime SKIP-gate.
#   6. references/clone-cluster-detection.md cross-references the detector
#      script so the Cluster Window Detection prose has a runnable
#      implementation pointer (W3 fills the W2 gap).
#   7. docs/windows-considerations.md + docs/cloning-guide.md no longer claim
#      robocopy /COPY:DAT preserves CreationTime unconditionally — they must
#      reflect empirical reality (clone-cluster observed 2026-05-01).
#   8. logs/changelog.md has a v0.1.4 W3 entry.
#
# Exit 0 on PASS. Exit 1 on first failure with a contextual message.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DETECTOR="scripts/detect-clone-cluster.sh"
W2_FIXTURE="tests/fixtures/clone-cluster"
PREFLIGHT_DOC="references/windows-preflight.md"
RECIPE_DOC="references/clone-cluster-detection.md"
WINDOWS_CONSIDERATIONS="docs/windows-considerations.md"
CLONING_GUIDE="docs/cloning-guide.md"
CHANGELOG="logs/changelog.md"

assert_path() {
  local path="$1"; local kind="$2"
  case "$kind" in
    file) [ -f "$path" ] || { echo "FAIL: missing file: $path" >&2; exit 1; } ;;
    exec) [ -x "$path" ] || { echo "FAIL: not executable: $path" >&2; exit 1; } ;;
  esac
}

assert_grep() {
  local needle="$1"; local file="$2"
  grep -qF "$needle" "$file" || { echo "FAIL: '$needle' not found in $file" >&2; exit 1; }
}

assert_grep_re() {
  local re="$1"; local file="$2"
  grep -qE "$re" "$file" || { echo "FAIL: pattern '$re' not found in $file" >&2; exit 1; }
}

refute_grep() {
  local needle="$1"; local file="$2"
  if grep -qF "$needle" "$file"; then
    echo "FAIL: '$needle' should NOT appear in $file (was an empirically-false claim)" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# 1. Detector exists + executable
# ---------------------------------------------------------------------------
echo "[1/8] Detector script presence + perms..."
assert_path "$DETECTOR" file
assert_path "$DETECTOR" exec

# ---------------------------------------------------------------------------
# 2. Detector against W2 cluster fixture → CLUSTER_FOUND=yes
# ---------------------------------------------------------------------------
echo "[2/8] Detector against W2 cluster fixture..."

# Regenerate the W2 fixture so birthtimes are deterministic
bash "$W2_FIXTURE/generate.sh" >/dev/null

# Capture detector output, eval into env
OUT=$("$DETECTOR" "$W2_FIXTURE/notes")
eval "$OUT"

if [ "${CLUSTER_FOUND:-}" != "yes" ]; then
  echo "FAIL: expected CLUSTER_FOUND=yes against W2 fixture, got '${CLUSTER_FOUND:-<unset>}'" >&2
  echo "  Detector output: $OUT" >&2
  exit 1
fi

if [ -z "${CLONE_CLUSTER_WINDOW_START:-}" ] || [ -z "${CLONE_CLUSTER_WINDOW_END:-}" ]; then
  echo "FAIL: detector did not emit window bounds" >&2
  echo "  Detector output: $OUT" >&2
  exit 1
fi

# CLUSTER_FILE_COUNT must be >= 10 (the configured floor)
if [ "${CLUSTER_FILE_COUNT:-0}" -lt 10 ]; then
  echo "FAIL: CLUSTER_FILE_COUNT=$CLUSTER_FILE_COUNT below floor (10) on W2 fixture" >&2
  exit 1
fi

# Window must be sane ISO 8601 ending in Z
if ! printf -- "%s" "$CLONE_CLUSTER_WINDOW_START" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  echo "FAIL: window start is not ISO 8601 UTC: $CLONE_CLUSTER_WINDOW_START" >&2
  exit 1
fi
if ! printf -- "%s" "$CLONE_CLUSTER_WINDOW_END" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  echo "FAIL: window end is not ISO 8601 UTC: $CLONE_CLUSTER_WINDOW_END" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Detector against synthetic no-cluster dir → CLUSTER_FOUND=no
# ---------------------------------------------------------------------------
echo "[3/8] Detector against synthetic no-cluster dir..."

NO_CLUSTER_DIR=$(mktemp -d -t ova-w3-XXXXXX)
trap 'rm -rf "$NO_CLUSTER_DIR"' EXIT

# Create 5 .md files (under the 10-file cluster floor — even if all share
# birthtime, the floor blocks the cluster verdict).
for i in 1 2 3 4 5; do
  printf -- "# note %d\n" "$i" > "$NO_CLUSTER_DIR/note-$i.md"
done

OUT=$("$DETECTOR" "$NO_CLUSTER_DIR")
# Reset captured vars from previous block
unset CLUSTER_FOUND CLONE_CLUSTER_WINDOW_START CLONE_CLUSTER_WINDOW_END CLUSTER_FILE_COUNT
eval "$OUT"
if [ "${CLUSTER_FOUND:-}" != "no" ]; then
  echo "FAIL: expected CLUSTER_FOUND=no for 5-file dir (under floor), got '${CLUSTER_FOUND:-<unset>}'" >&2
  echo "  Detector output: $OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Detector against empty dir → CLUSTER_FOUND=no
# ---------------------------------------------------------------------------
echo "[4/8] Detector against empty dir..."

EMPTY_DIR=$(mktemp -d -t ova-w3-empty-XXXXXX)
OUT=$("$DETECTOR" "$EMPTY_DIR")
unset CLUSTER_FOUND CLONE_CLUSTER_WINDOW_START CLONE_CLUSTER_WINDOW_END CLUSTER_FILE_COUNT
eval "$OUT"
if [ "${CLUSTER_FOUND:-}" != "no" ]; then
  echo "FAIL: expected CLUSTER_FOUND=no for empty dir, got '${CLUSTER_FOUND:-<unset>}'" >&2
  exit 1
fi
rm -rf "$EMPTY_DIR"

# ---------------------------------------------------------------------------
# 5. windows-preflight.md has WARN-flow preflight section for clone-cluster
# ---------------------------------------------------------------------------
echo "[5/8] windows-preflight.md WARN-flow section..."
assert_path "$PREFLIGHT_DOC" file
assert_grep "detect-clone-cluster.sh" "$PREFLIGHT_DOC"
# Must mention WARN (not STOP) for the clone-cluster path
assert_grep_re "WARN" "$PREFLIGHT_DOC"
assert_grep "clone-cluster-detection.md" "$PREFLIGHT_DOC"
# Must explicitly say the preflight does NOT stop on cluster (proceed semantics)
assert_grep_re "(proceed|continue)" "$PREFLIGHT_DOC"

# ---------------------------------------------------------------------------
# 6. clone-cluster-detection.md points at the runnable detector
# ---------------------------------------------------------------------------
echo "[6/8] clone-cluster-detection.md cross-ref to detector..."
assert_grep "scripts/detect-clone-cluster.sh" "$RECIPE_DOC"

# ---------------------------------------------------------------------------
# 7. False robocopy-preserves-CreationTime claims removed
# ---------------------------------------------------------------------------
echo "[7/8] Cross-doc false-claim retraction..."
# Old false claim line in windows-considerations.md table row 3
refute_grep "Yes — preserved from source" "$WINDOWS_CONSIDERATIONS"
# Old false claim line in cloning-guide.md table — same exact phrase
refute_grep "Yes — preserved from source" "$CLONING_GUIDE"
# Both files must reference the empirical reality + clone-cluster mitigation
assert_grep "clone-cluster-detection.md" "$WINDOWS_CONSIDERATIONS"
assert_grep "clone-cluster-detection.md" "$CLONING_GUIDE"

# ---------------------------------------------------------------------------
# 8. Changelog has v0.1.4 W3 entry
# ---------------------------------------------------------------------------
echo "[8/8] Changelog v0.1.4 W3 entry..."
assert_grep_re "v0\.1\.4 W3" "$CHANGELOG"

echo "PASS: detect-clone-cluster.sh + windows-preflight.md WARN-flow + clone-cluster-detection.md cross-ref + cross-doc retractions + changelog"
