#!/usr/bin/env bash
# scripts/smoke-test.sh
#
# Manual harness for v0.1.x test fixtures. Sets up a temp vault, walks the
# launch-scope skills in declared order, and diffs the temp-vault state against
# golden expected files in test-data/expected/<skill>/.
#
# This is a CONTRACT validator, not an LLM executor. The runner does NOT invoke
# Claude Code automatically — the developer runs each skill manually against
# $TEMP_VAULT and presses Enter when done. The runner then diffs and reports.
#
# Exit 0 on full PASS. Exit 1 on first diff. Exit 2 on missing fixture/expected.
#
# Limitations (acceptable for v0.1.3):
# - Skill-log callout includes timestamps. Golden files use {{TIMESTAMP}}
#   placeholder; the diff filters timestamps before comparing (see normalize_for_diff).
# - Filesystem birthtime preservation tests are NOT performed here — separate
#   stat-based check needed (out of scope for v0.1.3).
# - Bash-only, macOS-tested (Linux should work; Windows untested in v0.1.3).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_VAULT="$(mktemp -d /tmp/vault-autopilot-smoke.XXXXXX)"
trap 'rm -rf "$TEMP_VAULT"' EXIT

echo "=== smoke-test ==="
echo "Repo root:  $REPO_ROOT"
echo "Temp vault: $TEMP_VAULT"
echo

# Set up temp vault: Inbox/ holds all fixtures
mkdir -p "$TEMP_VAULT/Inbox"
FIXTURE_COUNT=0
for FIXTURE in "$REPO_ROOT/test-data"/*.md; do
  [[ -f "$FIXTURE" ]] || continue
  cp "$FIXTURE" "$TEMP_VAULT/Inbox/"
  FIXTURE_COUNT=$((FIXTURE_COUNT + 1))
done
echo "Copied $FIXTURE_COUNT fixtures to $TEMP_VAULT/Inbox/"
echo
echo "Set OBSIDIAN_VAULT_PATH=\"$TEMP_VAULT\" before running each skill."
echo

# Normalize a file for diff: replace timestamps + dates with placeholders so
# golden files using {{TIMESTAMP}}/{{ISO_DATE}} can match real run output.
normalize_for_diff() {
  local FILE="$1"
  # ISO date-time YYYY-MM-DD HH:MM
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/{{TIMESTAMP}}/g' "$FILE" \
    | sed -E 's/^modified: [0-9]{4}-[0-9]{2}-[0-9]{2}.*$/modified: {{ISO_DATE}}/'
}

# Walk skills in declared order
SKILLS=(property-enrich note-rename inbox-sort property-describe)

for SKILL in "${SKILLS[@]}"; do
  echo "--- Step: $SKILL ---"
  echo "Run \`$SKILL\` against $TEMP_VAULT (scope=inbox-tree, cooldown_days=0)."
  echo "Press Enter when done (or Ctrl-C to abort)..."
  read -r _

  EXPECTED_DIR="$REPO_ROOT/test-data/expected/$SKILL"
  if [[ ! -d "$EXPECTED_DIR" ]]; then
    echo "  No expected/ directory for $SKILL — skipping diff"
    echo
    continue
  fi

  shopt -s nullglob
  EXPECTED_FILES=("$EXPECTED_DIR"/*.md)
  shopt -u nullglob

  if [[ ${#EXPECTED_FILES[@]} -eq 0 ]]; then
    echo "  No expected fixtures for $SKILL — skipping diff"
    echo
    continue
  fi

  for EXPECTED in "${EXPECTED_FILES[@]}"; do
    FIXTURE="$(basename "$EXPECTED")"
    # File may have been moved by inbox-sort — search recursively
    ACTUAL="$(find "$TEMP_VAULT" -name "$FIXTURE" -type f -print -quit 2>/dev/null || true)"
    if [[ -z "$ACTUAL" || ! -f "$ACTUAL" ]]; then
      echo "  FAIL: $FIXTURE not found in temp vault after $SKILL"
      exit 2
    fi

    NORMALIZED_EXPECTED="$(mktemp)"
    NORMALIZED_ACTUAL="$(mktemp)"
    normalize_for_diff "$EXPECTED" > "$NORMALIZED_EXPECTED"
    normalize_for_diff "$ACTUAL" > "$NORMALIZED_ACTUAL"

    if ! diff -u "$NORMALIZED_EXPECTED" "$NORMALIZED_ACTUAL" > /tmp/smoke-diff.txt; then
      echo "  FAIL: $FIXTURE differs from expected"
      echo
      echo "  --- diff (expected vs actual, normalized) ---"
      cat /tmp/smoke-diff.txt
      echo "  --- end diff ---"
      rm -f "$NORMALIZED_EXPECTED" "$NORMALIZED_ACTUAL"
      exit 1
    fi
    rm -f "$NORMALIZED_EXPECTED" "$NORMALIZED_ACTUAL"
    echo "  PASS: $FIXTURE matches expected (timestamps normalized)"
  done
  echo
done

echo "=== smoke-test PASS ==="
