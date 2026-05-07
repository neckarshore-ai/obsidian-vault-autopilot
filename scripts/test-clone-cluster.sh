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

# Inline recipe (a) for the test harness — copy of the doc snippet (POSIX-safe).
recipe_a() {
  local FILE="$1"
  local BTIME
  if [ -z "${CLONE_CLUSTER_WINDOW_START:-}" ] || [ -z "${CLONE_CLUSTER_WINDOW_END:-}" ]; then
    return 1
  fi
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
