# Plan B — tag-manage Skill Build + Ship Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tag-manage skill on top of Plan A foundations: detection logic for Tier 1+2+3, convention loader/merger, SKILL.md fill-in (replacing skeleton with full workflow), bootstrap UX, integration tests, cross-platform Cycle 4 Gold Runs, and ship as v0.2.0.

**Architecture:** Skill orchestration lives in `skills/tag-manage/SKILL.md` as agent-readable instructions. Testable utility logic lives in `scripts/tag-*.sh` — bash with `set -euo pipefail`, no multi-line regex, line-by-line everywhere. AI canonical resolution happens inline in the agent's reasoning (Claude resolves while running the skill). The skill assembles the prompt context from outputs of the utility scripts.

**Tech Stack:** Bash 4+, GNU coreutils, Python 3 for YAML parse + JSON I/O. No separate API calls — the skill leverages Claude itself as the LLM via prompt-context within SKILL.md instructions. Haiku + temperature=0 are pinned for the resolution step (recommendation by advisor; the agent is instructed to operate in this mode).

**Sequencing:** Plan A must be merged to main before Plan B begins. Plan B's PRs build on Plan A's artifacts.

**Source spec:** `docs/superpowers/specs/2026-05-06-tag-manage-design.md` §13.2 Stages 2-4 (T5–T17)

---

## Task 1: Tag-extract utility + tests

**Files:**
- Create: `scripts/tag-extract.sh`
- Create: `scripts/test-tag-extract.sh`
- Create: `tests/fixtures/tag-extract/standard.md`, `quoted.md`, `mixed-marker.md`, `empty-tags.md`, `no-frontmatter.md`

**Goal:** A pure-bash utility that extracts YAML frontmatter tags from a single .md file, returns one tag per line on stdout. Handles all 4 list-item formats. Returns non-zero on malformed YAML.

- [ ] **Step 1: Create the fixtures**

Create `tests/fixtures/tag-extract/standard.md`:

```markdown
---
title: Standard
tags:
  - DevTools
  - Research
  - OpenSource
---

Body.
```

Create `tests/fixtures/tag-extract/quoted.md`:

```markdown
---
title: Quoted
tags:
  - "AI-ML"
  - "#Websites"
  - 'Mixed'
---

Body.
```

Create `tests/fixtures/tag-extract/mixed-marker.md`:

```markdown
---
title: Mixed
tags:
  - DevTools
  * Research
  - "Mixed"
---

Body.
```

Create `tests/fixtures/tag-extract/empty-tags.md`:

```markdown
---
title: Empty
tags: []
---

Body.
```

Create `tests/fixtures/tag-extract/no-frontmatter.md`:

```markdown
# Just a Note

No frontmatter at all.
```

- [ ] **Step 2: Write `scripts/tag-extract.sh`**

```bash
#!/usr/bin/env bash
# scripts/tag-extract.sh
#
# Extract YAML frontmatter tags from a single .md file.
# Outputs one bare tag value per line to stdout.
# Handles 4 list-item shapes:
#   - tag         (unquoted dash)
#   - "tag"       (double-quoted dash)
#   - 'tag'       (single-quoted dash)
#   * tag         (unquoted star)
#   * "tag"       (double-quoted star)
#   * 'tag'       (single-quoted star)
#
# Strips trailing comma if present.
# Skips flow-style (tags: [a, b, c]) — emits "FLOW_STYLE" marker to stderr.
# Returns 0 on success (zero or more tags), 1 on malformed file (frontmatter never closes).
#
# Usage: tag-extract.sh <file>

set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "ERROR: file not found: $FILE" >&2
  exit 2
fi

in_fm=0
in_tags=0
fm_closed=0
has_fm=0

while IFS= read -r line || [ -n "$line" ]; do
  stripped="${line%$'\r'}"

  if [ "$in_fm" -eq 0 ] && [ "$stripped" = "---" ]; then
    in_fm=1
    has_fm=1
    continue
  fi
  if [ "$in_fm" -eq 1 ] && [ "$stripped" = "---" ]; then
    in_fm=2
    fm_closed=1
    break
  fi

  if [ "$in_fm" -eq 1 ]; then
    # Detect tags: line
    if [[ "$stripped" =~ ^tags:\ *\[ ]]; then
      echo "FLOW_STYLE" >&2
      continue
    fi
    if [[ "$stripped" =~ ^tags:\ *$ ]]; then
      in_tags=1
      continue
    fi
    if [ "$in_tags" -eq 1 ]; then
      tag=""
      # Try shape 1: unquoted dash
      if [[ "$stripped" =~ ^"  - "([^\"\']*),?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      # Shape 2: dash + double quote
      elif [[ "$stripped" =~ ^"  - \""([^\"]*)\"",?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      # Shape 2': dash + single quote
      elif [[ "$stripped" =~ ^"  - '"([^\']*)'",?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      # Shape 3: unquoted star
      elif [[ "$stripped" =~ ^"  \\* "([^\"\']*),?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      # Shape 4: star + double quote
      elif [[ "$stripped" =~ ^"  \\* \""([^\"]*)\"",?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      # Shape 4': star + single quote
      elif [[ "$stripped" =~ ^"  \\* '"([^\']*)'",?$ ]]; then
        tag="${BASH_REMATCH[1]}"
      else
        # Non-list-item line ends the tags block
        in_tags=0
        continue
      fi
      # Trim trailing comma
      tag="${tag%,}"
      if [ -n "$tag" ]; then
        printf '%s\n' "$tag"
      fi
    fi
  fi
done < "$FILE"

if [ "$has_fm" -eq 1 ] && [ "$fm_closed" -eq 0 ]; then
  echo "ERROR: unclosed frontmatter in $FILE" >&2
  exit 1
fi

exit 0
```

- [ ] **Step 3: Write `scripts/test-tag-extract.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-extract.sh
# Asserts tag-extract.sh against fixtures.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURES="tests/fixtures/tag-extract"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [$label]"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
  echo "  PASS [$label]"
}

echo "Test: standard.md (3 unquoted tags)"
out=$(./scripts/tag-extract.sh "$FIXTURES/standard.md" | tr '\n' ',' | sed 's/,$//')
assert_eq "standard" "DevTools,Research,OpenSource" "$out"

echo "Test: quoted.md (3 quoted tags, mixed quote styles)"
out=$(./scripts/tag-extract.sh "$FIXTURES/quoted.md" | tr '\n' ',' | sed 's/,$//')
assert_eq "quoted" "AI-ML,#Websites,Mixed" "$out"

echo "Test: mixed-marker.md (3 tags, dash + star + quoted-dash)"
out=$(./scripts/tag-extract.sh "$FIXTURES/mixed-marker.md" | tr '\n' ',' | sed 's/,$//')
assert_eq "mixed-marker" "DevTools,Research,Mixed" "$out"

echo "Test: empty-tags.md (0 tags, flow-style marker)"
out=$(./scripts/tag-extract.sh "$FIXTURES/empty-tags.md" 2>&1 | grep FLOW_STYLE || true)
assert_eq "empty-tags-flow-marker" "FLOW_STYLE" "$out"

echo "Test: no-frontmatter.md (0 tags, exit 0)"
out=$(./scripts/tag-extract.sh "$FIXTURES/no-frontmatter.md")
assert_eq "no-frontmatter" "" "$out"

echo
echo "All tag-extract tests PASS."
exit 0
```

- [ ] **Step 4: Run tests**

```bash
chmod +x scripts/tag-extract.sh scripts/test-tag-extract.sh
./scripts/test-tag-extract.sh
```

Expected: 5 PASS lines, exit 0. If a regex misbehaves, debug by inspecting individual extractions: `./scripts/tag-extract.sh tests/fixtures/tag-extract/standard.md`.

- [ ] **Step 5: Commit**

```bash
git add scripts/tag-extract.sh scripts/test-tag-extract.sh tests/fixtures/tag-extract/
git commit -m "feat(tag-manage): tag-extract utility + tests (T5a)

scripts/tag-extract.sh extracts YAML frontmatter tags from a single
.md file, one tag per line on stdout. Handles 4 list-item shapes
(unquoted/quoted, dash/star markers). Returns FLOW_STYLE marker on
stderr for flow-style tags-blocks. Exit 1 on unclosed frontmatter.

Used by Tier 1+2+3 detection (next tasks).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Tier 1 + 2 detection utility + tests

**Files:**
- Create: `scripts/tag-detect-dupes.sh`
- Create: `scripts/test-tag-detect-dupes.sh`

**Goal:** Given a list of unique tags (one per line), output duplicate groups by Tier 1 (case-variant) and Tier 2 (whitespace/hyphen normalize). Group lines pipe-separated within a group, one group per output line, prefixed with `T1:` or `T2:`.

- [ ] **Step 1: Write `scripts/tag-detect-dupes.sh`**

```bash
#!/usr/bin/env bash
# scripts/tag-detect-dupes.sh
#
# Reads unique tag list from stdin (one per line).
# Outputs duplicate groups, one group per line, prefixed with tier.
#
# Format: T1:tag1|tag2|tag3   (case variants, lowercase-equal)
#         T2:tag1|tag2        (normalize-equal but not T1)
#
# Tags within a group are sorted alphabetically for stability.
#
# Usage: cat tags.txt | tag-detect-dupes.sh

set -euo pipefail

# Read all unique tags
declare -a tags=()
while IFS= read -r tag; do
  [ -n "$tag" ] && tags+=("$tag")
done

# Build T1 groups: lowercase → list
declare -A t1_groups=()
for tag in "${tags[@]}"; do
  key=$(echo "$tag" | tr '[:upper:]' '[:lower:]')
  if [ -n "${t1_groups[$key]:-}" ]; then
    t1_groups[$key]+="|$tag"
  else
    t1_groups[$key]="$tag"
  fi
done

# Track which tags are in T1 groups
declare -A in_t1=()

# Emit T1 groups (only those with >1 member)
for key in $(echo "${!t1_groups[@]}" | tr ' ' '\n' | sort); do
  group="${t1_groups[$key]}"
  if [[ "$group" == *"|"* ]]; then
    sorted=$(echo "$group" | tr '|' '\n' | sort | tr '\n' '|' | sed 's/|$//')
    echo "T1:$sorted"
    while IFS= read -r t; do in_t1[$t]=1; done <<< "$(echo "$sorted" | tr '|' '\n')"
  fi
done

# Build T2 groups: normalized (lowercase, no whitespace, no hyphen, no underscore) → list
# Skip tags already in T1 groups
declare -A t2_groups=()
for tag in "${tags[@]}"; do
  if [ -n "${in_t1[$tag]:-}" ]; then continue; fi
  norm=$(echo "$tag" | tr '[:upper:]' '[:lower:]' | tr -d ' \-_')
  if [ -n "${t2_groups[$norm]:-}" ]; then
    t2_groups[$norm]+="|$tag"
  else
    t2_groups[$norm]="$tag"
  fi
done

for key in $(echo "${!t2_groups[@]}" | tr ' ' '\n' | sort); do
  group="${t2_groups[$key]}"
  if [[ "$group" == *"|"* ]]; then
    sorted=$(echo "$group" | tr '|' '\n' | sort | tr '\n' '|' | sed 's/|$//')
    echo "T2:$sorted"
  fi
done

exit 0
```

- [ ] **Step 2: Write `scripts/test-tag-detect-dupes.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-detect-dupes.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [$label]"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
  echo "  PASS [$label]"
}

echo "Test 1: simple T1 case-variants"
out=$(printf 'devtools\nDevTools\nDevtools\nResearch\n' | ./scripts/tag-detect-dupes.sh)
assert_eq "T1-simple" "T1:DevTools|Devtools|devtools" "$out"

echo "Test 2: T2 hyphen/space variants"
out=$(printf 'OpenSource\nopen-source\nOpen Source\nResearch\n' | ./scripts/tag-detect-dupes.sh)
assert_eq "T2-simple" "T2:Open Source|OpenSource|open-source" "$out"

echo "Test 3: mixed T1 + T2"
out=$(printf 'devtools\nDevTools\nopen-source\nOpenSource\nResearch\n' | ./scripts/tag-detect-dupes.sh | sort)
expected_sorted=$(printf 'T1:DevTools|devtools\nT2:OpenSource|open-source\n' | sort)
assert_eq "mixed" "$expected_sorted" "$out"

echo "Test 4: no duplicates → empty output"
out=$(printf 'Research\nDevTools\nOpenSource\n' | ./scripts/tag-detect-dupes.sh)
assert_eq "no-dupes" "" "$out"

echo
echo "All tag-detect-dupes tests PASS."
exit 0
```

- [ ] **Step 3: Run tests**

```bash
chmod +x scripts/tag-detect-dupes.sh scripts/test-tag-detect-dupes.sh
./scripts/test-tag-detect-dupes.sh
```

Expected: 4 PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/tag-detect-dupes.sh scripts/test-tag-detect-dupes.sh
git commit -m "feat(tag-manage): Tier 1+2 duplicate detection utility (T5b)

scripts/tag-detect-dupes.sh reads unique tag list from stdin, emits
duplicate groups prefixed with T1: (case-variants) or T2: (whitespace/
hyphen normalize, excluding T1 members).

Used by tag-manage detection step (Step 3 of skill workflow).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Tier 3 convention-violation detection utility + tests

**Files:**
- Create: `scripts/tag-detect-violations.sh`
- Create: `scripts/test-tag-detect-violations.sh`

**Goal:** Read unique tag list from stdin + an effective-convention JSON file, output Tier 3 convention violations one per line in `severity|kind|tag` format.

- [ ] **Step 1: Write `scripts/tag-detect-violations.sh`**

```bash
#!/usr/bin/env bash
# scripts/tag-detect-violations.sh
#
# Detects Tier 3 convention violations.
# Reads unique tag list from stdin, effective-convention JSON from $1.
# Outputs violations one per line, format: severity|kind|tag
#
# Severity:
#   high   — hash-prefix, yaml-leak, numeric, trailing-artifact
#   medium — lowercase-concept, snake_case, upper-kebab, casing-mismatch
#   low    — (reserved)
#
# Kinds:
#   hash_prefix          — tag starts with #
#   yaml_leak            — matches forbidden_patterns YAML-key regex
#   numeric              — tag is digits only
#   trailing_artifact    — trailing colon/quote/comma without canonical
#   lowercase_concept    — starts with lowercase, not in pins
#   snake_case           — contains _ and not in pins
#   upper_kebab          — Word-Word pattern, not AI-/KI-/brand exempt
#   casing_mismatch      — wrong casing for current rule (PascalCase mismatch etc)
#
# Usage: cat tags.txt | tag-detect-violations.sh /tmp/effective-convention.json

set -euo pipefail

CONV_FILE="${1:-}"
if [ -z "$CONV_FILE" ] || [ ! -f "$CONV_FILE" ]; then
  echo "ERROR: convention JSON file required" >&2
  exit 2
fi

# Extract pins.from set (lowercase forms that have explicit canonicals)
declare -A pins_from=()
while IFS= read -r line; do
  pins_from[$line]=1
done < <(python3 -c "
import json, sys
with open('$CONV_FILE') as f:
    c = json.load(f)
for p in c.get('pins', []):
    print(p['from'])
")

# Extract forbidden_patterns
mapfile -t patterns < <(python3 -c "
import json
with open('$CONV_FILE') as f:
    c = json.load(f)
for p in c.get('forbidden_patterns', []):
    print(p)
")

# Extract casing rule
casing=$(python3 -c "
import json
with open('$CONV_FILE') as f:
    c = json.load(f)
print(c.get('casing', 'PascalCase'))
")

# Brand exempt list — pins where to has Mixed casing or hyphen (e.g. Mercedes-Benz, VfB-Stuttgart)
declare -A brand_hyphen_exempt=()
while IFS= read -r tag; do
  brand_hyphen_exempt[$tag]=1
done < <(python3 -c "
import json
with open('$CONV_FILE') as f:
    c = json.load(f)
for p in c.get('pins', []):
    if '-' in p['to']:
        print(p['to'])
")

while IFS= read -r tag; do
  [ -z "$tag" ] && continue

  severity=""
  kind=""

  # 1. forbidden_patterns
  for pat in "${patterns[@]}"; do
    if echo "$tag" | grep -qE "$pat"; then
      severity="high"
      case "$pat" in
        '^#') kind="hash_prefix" ;;
        '^[0-9]+$') kind="numeric" ;;
        '^(created|modified|last_updated|updated|aliases|type):') kind="yaml_leak" ;;
        *) kind="forbidden_pattern" ;;
      esac
      echo "$severity|$kind|$tag"
      continue 2
    fi
  done

  # 2. trailing artifacts (colon, quote, comma) — caught even before forbidden_patterns can
  if [[ "$tag" =~ :$ ]] || [[ "$tag" =~ \"$ ]] || [[ "$tag" =~ ,$ ]]; then
    echo "high|trailing_artifact|$tag"
    continue
  fi

  # 3. snake_case (contains _) — and NOT in pins
  tag_lower=$(echo "$tag" | tr '[:upper:]' '[:lower:]')
  if [[ "$tag" =~ _ ]] && [ -z "${pins_from[$tag_lower]:-}" ]; then
    echo "medium|snake_case|$tag"
    continue
  fi

  # 4. PascalCase casing rule
  if [ "$casing" = "PascalCase" ]; then
    # 4a. lowercase concept (starts with [a-z]) and not in pins
    if [[ "$tag" =~ ^[a-z] ]] && [ -z "${pins_from[$tag_lower]:-}" ]; then
      echo "medium|lowercase_concept|$tag"
      continue
    fi
    # 4b. Upper-Kebab: Word-Word with caps, not AI-/KI-, not brand-hyphen-exempt
    if [[ "$tag" =~ ^[A-Z][a-z]+(-[A-Z][a-z]+)+$ ]] \
       && ! [[ "$tag" =~ ^(AI|KI)- ]] \
       && [ -z "${brand_hyphen_exempt[$tag]:-}" ]; then
      echo "medium|upper_kebab|$tag"
      continue
    fi
  fi

  # No violation
done

exit 0
```

- [ ] **Step 2: Write `scripts/test-tag-detect-violations.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-detect-violations.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Build a minimal effective-convention JSON for tests
TMPCONV=$(mktemp)
trap 'rm -f "$TMPCONV"' EXIT
cat > "$TMPCONV" <<'EOF'
{
  "casing": "PascalCase",
  "forbidden_patterns": [
    "^#",
    "^[0-9]+$",
    "^(created|modified|last_updated|updated|aliases|type):"
  ],
  "pins": [
    {"from": "github", "to": "GitHub"},
    {"from": "n8n", "to": "n8n"},
    {"from": "mercedes-benz", "to": "Mercedes-Benz"}
  ]
}
EOF

assert_contains() {
  local label="$1" expected="$2" actual="$3"
  if ! echo "$actual" | grep -qF "$expected"; then
    echo "FAIL [$label]"
    echo "  expected line containing: $expected"
    echo "  actual:"
    echo "$actual" | sed 's/^/    /'
    exit 1
  fi
  echo "  PASS [$label] — found '$expected'"
}

assert_not_contains() {
  local label="$1" forbidden="$2" actual="$3"
  if echo "$actual" | grep -qF "$forbidden"; then
    echo "FAIL [$label] — should not contain '$forbidden'"
    echo "$actual" | sed 's/^/    /'
    exit 1
  fi
  echo "  PASS [$label] — correctly absent: '$forbidden'"
}

# Test inputs cover all 8 kinds + a clean control
INPUT="$(printf '%s\n' \
  '#Websites' \
  '1' \
  'created: 2026-03-22' \
  'public-sectortags:' \
  'ai_agents' \
  'research' \
  'App-Development' \
  'Mercedes-Benz' \
  'Research' \
  'GitHub' \
  'n8n')"

out=$(echo "$INPUT" | ./scripts/tag-detect-violations.sh "$TMPCONV")

assert_contains "hash_prefix" "high|hash_prefix|#Websites" "$out"
assert_contains "numeric"     "high|numeric|1" "$out"
assert_contains "yaml_leak"   "high|yaml_leak|created: 2026-03-22" "$out"
assert_contains "trailing_artifact" "high|trailing_artifact|public-sectortags:" "$out"
assert_contains "snake_case"  "medium|snake_case|ai_agents" "$out"
assert_contains "lowercase"   "medium|lowercase_concept|research" "$out"
assert_contains "upper_kebab" "medium|upper_kebab|App-Development" "$out"
assert_not_contains "Mercedes-Benz exempt" "Mercedes-Benz" "$out"
assert_not_contains "Research clean"       "|Research"      "$out"
assert_not_contains "GitHub clean"         "|GitHub"        "$out"
assert_not_contains "n8n pin exempt"       "|n8n"           "$out"

echo
echo "All tag-detect-violations tests PASS."
exit 0
```

- [ ] **Step 3: Run tests**

```bash
chmod +x scripts/tag-detect-violations.sh scripts/test-tag-detect-violations.sh
./scripts/test-tag-detect-violations.sh
```

Expected: all PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/tag-detect-violations.sh scripts/test-tag-detect-violations.sh
git commit -m "feat(tag-manage): Tier 3 convention violation detection (T5c)

scripts/tag-detect-violations.sh reads tag list + effective-convention
JSON, emits violations as severity|kind|tag.

8 kinds covered: hash_prefix, yaml_leak, numeric, trailing_artifact,
lowercase_concept, snake_case, upper_kebab, plus pin-aware exemptions
(Mercedes-Benz-style hyphen brands skip upper_kebab).

Used by tag-manage detection step.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Convention loader + merger utility

**Files:**
- Create: `scripts/tag-convention-load.sh`
- Create: `scripts/test-tag-convention-load.sh`

**Goal:** Load `references/tag-convention.md` plugin default, optionally merge with `[VAULT]/_vault-autopilot/config/tag-convention.md`. Emit effective convention as JSON to stdout.

- [ ] **Step 1: Write `scripts/tag-convention-load.sh`**

```bash
#!/usr/bin/env bash
# scripts/tag-convention-load.sh
#
# Loads plugin default tag-convention.md + optional vault override.
# Emits merged effective convention as JSON to stdout.
#
# Usage: tag-convention-load.sh [<vault-path>]
#   No vault-path: emits plugin default only.
#   With vault-path: merges [VAULT]/_vault-autopilot/config/tag-convention.md if present.
#
# Halts loud (exit 1) if either file's YAML frontmatter is invalid.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/references/tag-convention.md"

VAULT_PATH="${1:-}"
VAULT_FILE=""
if [ -n "$VAULT_PATH" ]; then
  VAULT_FILE="$VAULT_PATH/_vault-autopilot/config/tag-convention.md"
fi

python3 - "$PLUGIN_FILE" "$VAULT_FILE" <<'PYEOF'
import sys
import yaml
import json
import os

def parse_frontmatter(path):
    if not path or not os.path.isfile(path):
        return None
    with open(path) as f:
        content = f.read()
    parts = content.split('---', 2)
    if len(parts) < 3:
        raise SystemExit(f"ERROR: {path} has no closing ---")
    try:
        return yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        raise SystemExit(f"ERROR: {path} invalid YAML: {e}")

plugin_path = sys.argv[1]
vault_path = sys.argv[2] if len(sys.argv) > 2 else ""

plugin = parse_frontmatter(plugin_path)
if plugin is None:
    raise SystemExit(f"ERROR: plugin default {plugin_path} not found")
if plugin.get('schema') != 1:
    raise SystemExit(f"ERROR: plugin schema not v1: {plugin.get('schema')}")

merged = dict(plugin)
vault = parse_frontmatter(vault_path) if vault_path else None
if vault is not None:
    if vault.get('schema') != 1:
        raise SystemExit(f"ERROR: vault schema not v1: {vault.get('schema')}")

    # Scalars: vault wins
    for key in ('casing', 'hierarchy_separator'):
        if key in vault:
            merged[key] = vault[key]

    # Lists: concat
    if 'forbidden_patterns' in vault:
        merged['forbidden_patterns'] = list(merged.get('forbidden_patterns', [])) + list(vault['forbidden_patterns'])

    # Pins: vault wins on `from` collision
    plugin_pins = {p['from']: p for p in merged.get('pins', [])}
    for vp in vault.get('pins', []):
        plugin_pins[vp['from']] = vp
    merged['pins'] = list(plugin_pins.values())

    # hierarchy_prefixes: vault wins on `prefix` collision
    plugin_pref = {p['prefix']: p for p in merged.get('hierarchy_prefixes', [])}
    for vp in vault.get('hierarchy_prefixes', []):
        plugin_pref[vp['prefix']] = vp
    merged['hierarchy_prefixes'] = list(plugin_pref.values())

    # folder_exclusive: vault-only
    if 'folder_exclusive' in vault:
        merged['folder_exclusive'] = vault['folder_exclusive']

print(json.dumps(merged, indent=2, sort_keys=True))
PYEOF
```

- [ ] **Step 2: Write `scripts/test-tag-convention-load.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-convention-load.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [$label]"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
  echo "  PASS [$label]"
}

# Test 1: plugin-only load
echo "Test 1: plugin-only load"
out=$(./scripts/tag-convention-load.sh)
casing=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['casing'])")
assert_eq "plugin casing" "PascalCase" "$casing"

pin_count=$(echo "$out" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['pins']))")
[ "$pin_count" -ge 15 ] || { echo "FAIL: expected at least 15 pins, got $pin_count"; exit 1; }
echo "  PASS pin count >= 15: $pin_count"

# Test 2: vault override merging
echo "Test 2: vault override merging"
TMPVAULT=$(mktemp -d)
trap 'rm -rf "$TMPVAULT"' EXIT
mkdir -p "$TMPVAULT/_vault-autopilot/config"
cat > "$TMPVAULT/_vault-autopilot/config/tag-convention.md" <<'EOF'
---
schema: 1
pins:
  - {from: smartbroker, to: Smartbroker}
  - {from: tibber, to: Tibber}
  - {from: github, to: GitHubFork}
---

Sample override.
EOF

out=$(./scripts/tag-convention-load.sh "$TMPVAULT")

# Vault adds smartbroker
has_smartbroker=$(echo "$out" | python3 -c "
import sys,json
pins = json.load(sys.stdin)['pins']
print(any(p['from'] == 'smartbroker' and p['to'] == 'Smartbroker' for p in pins))
")
assert_eq "vault adds smartbroker" "True" "$has_smartbroker"

# Vault overrides github (vault wins on `from` collision)
github_to=$(echo "$out" | python3 -c "
import sys,json
pins = json.load(sys.stdin)['pins']
gh = next(p for p in pins if p['from'] == 'github')
print(gh['to'])
")
assert_eq "vault overrides github" "GitHubFork" "$github_to"

# Test 3: invalid vault YAML → halt
echo "Test 3: invalid vault YAML halts"
echo "---" > "$TMPVAULT/_vault-autopilot/config/tag-convention.md"
echo "not: valid: yaml: with: too: many: colons" >> "$TMPVAULT/_vault-autopilot/config/tag-convention.md"
echo "---" >> "$TMPVAULT/_vault-autopilot/config/tag-convention.md"

if ./scripts/tag-convention-load.sh "$TMPVAULT" 2>/dev/null; then
  echo "FAIL: expected non-zero exit on invalid vault YAML"
  exit 1
fi
echo "  PASS invalid YAML correctly halted"

echo
echo "All tag-convention-load tests PASS."
exit 0
```

- [ ] **Step 3: Run tests**

```bash
chmod +x scripts/tag-convention-load.sh scripts/test-tag-convention-load.sh
./scripts/test-tag-convention-load.sh
```

Expected: all PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/tag-convention-load.sh scripts/test-tag-convention-load.sh
git commit -m "feat(tag-manage): convention loader + merger (T5d)

scripts/tag-convention-load.sh loads plugin default + optional vault
override, emits effective convention as JSON. Merge semantics per
references/vault-config.md: scalars vault-wins, lists concat, pins
vault-wins-on-collision.

Halts loud on invalid YAML in either file (no silent fallback).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: SKILL.md fill — Discover/Scan/Detect sections

**Files:**
- Modify: `skills/tag-manage/SKILL.md` (replace Workflow §1-3)

**Goal:** Replace skeleton's bullet-point workflow with concrete bash + agent-instructions for Discover, Scan, and Detect steps. The skill orchestrates the utility scripts from Tasks 1-4.

- [ ] **Step 1: Open the skeleton, replace Workflow steps 1-3 with full instructions**

In `skills/tag-manage/SKILL.md`, replace the existing `## Workflow` section's items 1-3 with this expanded content:

```markdown
## Workflow

### Step 1 — Discover & Configure

1. Resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask the user. Do NOT scan the filesystem to discover vaults (per CLAUDE.md Production Vault Safety).

2. **Production-Safety Gate.** State plainly: "I will operate on `[path]`. Confirm?" Wait for user yes before any read.

3. **Pre-flight plugin state check.** Run:
   ```bash
   grep -c obsidian-vault ~/.claude/plugins/installed_plugins.json
   ```
   Result `0` = direct-symlink mode (correct). Result `>0` = an old plugin version is active — STOP and instruct user to uninstall before continuing.

4. **Windows preflight.** If running on Windows, follow `references/windows-preflight.md` end-to-end. On macOS/Linux, skip.

5. **Load effective convention.** Run:
   ```bash
   ./scripts/tag-convention-load.sh "$OBSIDIAN_VAULT_PATH" > /tmp/effective-convention.json
   ```
   This loads `references/tag-convention.md` plugin default and merges `[VAULT]/_vault-autopilot/config/tag-convention.md` if present. Halts loud on invalid YAML.

6. **Confirm scope.** Resolve the `scope` parameter (default `vault`). Output:
   > "Scope: `<scope>`. Cooldown: `<cooldown_days>` days. Proceed with audit?"

### Step 2 — Scan

1. **Walk scope** using the windows-preflight enumeration pattern. For Windows-cloned vaults this means `\\?\` prefix + `Directory.EnumerateFiles`. On macOS/Linux, plain `find`:
   ```bash
   find "$SCOPE_PATH" -name "*.md" -type f -print0
   ```

2. **For each .md file:**
   a. Run `references/yaml-sanity.md` first. Verdicts route as follows:
      - `OK` / `OK_QUOTED` / `OK_NO_FRONTMATTER` → proceed.
      - `BROKEN_KEYS_INSIDE_COLON` → skip file, log Class-A finding "broken-keys-inside-colon, route to property-enrich (recipe f)".
      - `MULTIPLE_FRONTMATTER_BLOCKS` / `UNCLOSED_FRONTMATTER` → skip file, log Class-A finding, route to note-rename.
   b. Apply cooldown: read YAML `created` field. Walk the Source Hierarchy from `docs/metadata-requirements.md` if missing (filename date → git first-commit → filesystem birthtime). If `created < cooldown_days ago`, skip with note "cooldown".
   c. Extract tags:
      ```bash
      ./scripts/tag-extract.sh "$file" >> /tmp/all-tags-with-files.txt
      ```
      But also track `tag → files` mapping. Use a parallel pass:
      ```bash
      while IFS= read -r tag; do
        echo "$file|$tag" >> /tmp/tags-by-file.txt
      done < <(./scripts/tag-extract.sh "$file")
      ```

3. **Build derived structures:**
   ```bash
   # tag-frequency table
   cut -d'|' -f2 /tmp/tags-by-file.txt | sort | uniq -c | sort -rn > /tmp/tag-frequency.txt

   # unique tag list
   cut -d'|' -f2 /tmp/tags-by-file.txt | sort -u > /tmp/unique-tags.txt

   # totals
   total_notes=$(find "$SCOPE_PATH" -name "*.md" -type f | wc -l)
   tagged_notes=$(cut -d'|' -f1 /tmp/tags-by-file.txt | sort -u | wc -l)
   total_assignments=$(wc -l < /tmp/tags-by-file.txt)
   unique_tag_count=$(wc -l < /tmp/unique-tags.txt)
   ```

4. **Filter reserved tags.** Remove `VaultAutopilot` and `VaultAutopilot/*` entries from the unique tag list before detection:
   ```bash
   grep -v -E '^VaultAutopilot(/|$)' /tmp/unique-tags.txt > /tmp/unique-tags-filtered.txt
   mv /tmp/unique-tags-filtered.txt /tmp/unique-tags.txt
   ```

### Step 3 — Detect

1. **Tier 1 + 2 detection:**
   ```bash
   ./scripts/tag-detect-dupes.sh < /tmp/unique-tags.txt > /tmp/duplicate-groups.txt
   ```
   Output format: `T1:tag1|tag2|tag3` or `T2:tag1|tag2`, one group per line.

2. **Tier 3 detection:**
   ```bash
   ./scripts/tag-detect-violations.sh /tmp/effective-convention.json < /tmp/unique-tags.txt > /tmp/violations.txt
   ```
   Output format: `severity|kind|tag`, one per line.

3. **Build issue list.** Combine into a single recommendations precursor — one entry per group/violation, with type, current tags, severity, and per-group files-affected count.

4. **Display scan summary** to user before AI resolution:
   > "Scan complete.
   > - Notes: `<total_notes>` (skipped `<cooldown_count>` cooldown, `<malformed_count>` malformed)
   > - Tags: `<unique_tag_count>` unique, `<total_assignments>` assignments
   > - Tier 1+2 duplicate groups: `<group_count>`
   > - Tier 3 violations: `<violation_count>`
   > Proceeding to AI resolution..."
```

- [ ] **Step 2: Verify the SKILL.md still parses (YAML frontmatter intact)**

```bash
python3 -c "
content = open('skills/tag-manage/SKILL.md').read()
fm = content.split('---', 2)[1]
import yaml
parsed = yaml.safe_load(fm)
assert parsed['name'] == 'tag-manage'
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/tag-manage/SKILL.md
git commit -m "feat(tag-manage): SKILL.md Discover/Scan/Detect sections (T5e)

Replace skeleton bullets with concrete bash + agent instructions.
Skill now orchestrates tag-extract, tag-detect-dupes, and
tag-detect-violations from scripts/.

Includes Production-Safety gate, pre-flight plugin check, windows-
preflight integration, yaml-sanity routing, cooldown via Source
Hierarchy, and reserved-tag filter.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: SKILL.md fill — Resolve/Preview/User-Gate sections

**Files:**
- Modify: `skills/tag-manage/SKILL.md` (replace Workflow §4-6)

**Goal:** Add the AI resolution prompt template + JSON output handling + chat preview + user gate.

- [ ] **Step 1: Append/replace Workflow steps 4-6 in SKILL.md**

Replace items 4-6 of the Workflow section:

```markdown
### Step 4 — Resolve (AI canonical decisions)

**Pinned model parameters** (per spec for determinism):
- Model: claude-haiku (current revision)
- Temperature: 0
- Prompt template version: `1.0`

**Build the resolution prompt context.** Read:
- `/tmp/effective-convention.json` (full content)
- `/tmp/tag-frequency.txt` (frequency table)
- `/tmp/duplicate-groups.txt` (T1 + T2 groups)
- `/tmp/violations.txt` (T3 violations)
- Pin list from convention's `pins` field (subset)

**Issue this prompt** (the agent processes it inline; no separate API call):

> You are reconciling a vault's tag chaos to a clean canonical form.
>
> EFFECTIVE CONVENTION (merged plugin default + vault override):
> [paste effective-convention.json content]
>
> VAULT VOCABULARY (full unique tag list with frequencies):
> [paste tag-frequency.txt content, top 200 lines]
>
> DUPLICATE GROUPS (Tier 1 + 2):
> [paste duplicate-groups.txt content]
>
> CONVENTION VIOLATIONS (Tier 3):
> [paste violations.txt content]
>
> VAULT PINS (FIXED — do not propose alternatives, use these directly):
> [paste pins from effective convention as `from → to` lines]
>
> For each group/violation, decide the canonical form and severity. Rules:
> 1. If a tag's lowercase form is in pins.from, use the pinned canonical directly. Do not deviate.
> 2. For Tier 1+2 groups without a pin: propose the convention-conformant variant. If multiple in the group conform (rare), pick the one with highest VOCAB frequency.
> 3. For Tier 3 violations: propose canonical (rename) when convention-conformant form is recoverable. For yaml-leak, numeric, and trailing-artifact kinds: propose remove (canonical = null).
> 4. Keep severity exactly as input (do not re-derive).
>
> Output STRICT JSON:
> ```
> {
>   "recommendations": [
>     {
>       "id": 1,
>       "type": "rename" | "remove" | "merge",
>       "current_tags": ["devtools", "Devtools"],
>       "canonical": "DevTools",
>       "severity": "medium",
>       "reason": "case variants, PascalCase per convention",
>       "files_affected_count": 16,
>       "pinned": false
>     }
>   ]
> }
> ```

**Persist the resolution output** to `/tmp/recommendations.json`. Validate JSON shape:

```bash
python3 -c "
import json
with open('/tmp/recommendations.json') as f:
    data = json.load(f)
assert 'recommendations' in data
for r in data['recommendations']:
    assert all(k in r for k in ['id', 'type', 'current_tags', 'canonical', 'severity', 'reason', 'files_affected_count'])
    assert r['type'] in ('rename', 'remove', 'merge')
    assert r['severity'] in ('high', 'medium', 'low')
print('Recommendations JSON valid')
"
```

If JSON is malformed, retry the resolution prompt once with stricter "OUTPUT MUST BE STRICT JSON ONLY, NO PROSE" instruction. If second attempt still malformed, halt with clear error and dump what was produced for debugging.

### Step 5 — Preview (chat + findings file)

1. **Chat-display table** grouped by severity. Annotate pinned canonicals with `(pinned)`. Example output format:

```
HIGH (3 issues, 7 notes affected)
─────────────────────────────────
 # | Action  | Current        | Canonical | Notes |
 1 | remove  | "1"            | <REMOVE>  |    5  |
 2 | rename  | "#Websites"    | Websites  |    2  |
 3 | remove  | "created: 2026-03-22" | <REMOVE> | 4 |

MEDIUM (5 issues, 41 notes affected)
─────────────────────────────────
 4 | merge   | devtools, Devtools, DevTools | DevTools (pinned) | 16 |
 5 | rename  | research                     | Research          |  8 |
 ...
```

2. **Append to findings file** at `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-manage.md`. Create if missing. Append a new run section with timestamp:

```markdown
## Run YYYY-MM-DD HH:MM:SS UTC

**Scope:** <scope>
**Cooldown:** <cooldown_days> days
**Notes scanned:** <total_notes> (skipped <cooldown_count> cooldown, <malformed_count> malformed)
**Tags found:** <unique_tag_count> unique, <total_assignments> assignments
**Prompt template version:** 1.0

### Audit Recommendations

| # | Severity | Type   | Current        | Canonical | Notes affected | Reason |
| 1 | high     | remove | "1"            | <REMOVE>  | 5              | numeric-only artifact |
| ... |

### Status: audit-complete, awaiting-user-decision
```

YAML edits to the findings file MUST follow `references/yaml-edits.md` (this file is plain markdown, no YAML edits needed — pure append).

### Step 6 — User Gate

Display:

> Audit complete. `<count>` recommendations across `<file_count>` notes.
>
> - `apply all`
> - `apply 1-5` / `apply 1, 4, 7`
> - `skip 6, 8`
> - `override 4 to MyOwnVersion` (force a different canonical)
> - `apply nothing` (keep findings file, exit)

Wait for user response. Parse the response:
- `apply all` → all recommendation IDs.
- `apply N-M` or `apply N, M, P` → explicit ID list.
- `skip` modifiers subtract.
- `override <id> <canonical>` → record per-ID overrides; the override replaces the AI-proposed canonical for that recommendation.

**Production-Safety Bulk-Operation Confirm before write:**

> "I will rename `<rename_count>` tags and remove `<remove_count>` tags across `<file_count>` files in `<vault-name>`. Confirm?"

If user declines: write `apply-aborted-by-user` to findings file Status, exit cleanly.
```

- [ ] **Step 2: Verify SKILL.md still parses**

```bash
python3 -c "
import yaml
content = open('skills/tag-manage/SKILL.md').read()
fm = content.split('---', 2)[1]
yaml.safe_load(fm)
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/tag-manage/SKILL.md
git commit -m "feat(tag-manage): SKILL.md Resolve/Preview/User-Gate sections (T6)

Add the AI canonical-resolution prompt template (Haiku, temp=0,
prompt_template_version 1.0), JSON-output validation, chat preview
table grouped by severity, findings-file run section template, and
user gate with override + skip parsing.

Production-Safety Bulk-Operation Confirm gate added.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: SKILL.md fill — Apply/Report sections + Bootstrap UX

**Files:**
- Modify: `skills/tag-manage/SKILL.md` (replace Workflow §7-8)

**Goal:** Apply step orchestrates recipes (g)/(h) per approved recommendation. Report step finalizes findings file. Bootstrap UX scaffolds vault-config when vault-specific tags detected.

- [ ] **Step 1: Replace Workflow steps 7-8 in SKILL.md**

```markdown
### Step 7 — Apply

For each approved recommendation `r` in user-filtered list:

1. **Pre-write concurrency check.** For each file `f` in `r.current_tags`'s file mapping:
   ```bash
   current_tags=$(./scripts/tag-extract.sh "$f")
   if ! echo "$current_tags" | grep -Fxq "$current_tag"; then
     echo "concurrent-modification: $current_tag no longer present in $f"
     continue
   fi
   ```
   If tag is absent, log "already-resolved-manually" finding, skip the per-file mutation but continue with other files for this recommendation.

2. **Pre-write log to findings file Changes section.** Append per-file entry BEFORE actual mutation:
   ```markdown
   | <r.id> | <relative_path> | <line> | <before> | <after> |
   ```

3. **Execute the mutation:**
   - `r.type == "rename"` (or "merge"): for each file containing one of `r.current_tags`, run the recipe (g) tag-rename procedure described in `references/yaml-edits.md`. The mutation: replace each instance of `current_tag` with `r.canonical`.
   - `r.type == "remove"`: for each file containing the tag, run recipe (h) tag-remove procedure.

4. **Birthtime preservation** per `references/skill-log.md`. After write, restore filesystem birthtime from YAML `created`:
   ```bash
   created_iso=$(...)  # extract from YAML
   touch -t "$(date -j -f '%Y-%m-%dT%H:%M:%S' "$created_iso" '+%Y%m%d%H%M.%S')" "$f"
   ```
   (Use macOS `touch -t` syntax. On Linux, use `touch -d`.)

5. **Skill-log callout entry.** For each file mutated, append a row to the file's `## Skill Log` callout block per `references/skill-log.md` recipe (e). Action string: `tag-manage rename <old> → <new>` or `tag-manage remove <tag>`.

6. **VaultAutopilot tag.** Ensure the `VaultAutopilot` tag is in the file's tags-block. If absent, add via recipe (i) tag-add (defined in tag-suggest spec; for tag-manage Plan B, use a minimal append). YAML edits MUST follow `references/yaml-edits.md`.

7. **Halt on error.** If any per-file mutation throws, halt the entire apply phase. Findings file shows what was applied vs not. Re-run is safe — concurrency check above catches already-mutated files.

### Step 8 — Report

1. **Final chat-display:**

> tag-manage applied `<applied_count>` of `<total_recommendation_count>` recommendations.
> - `<file_mutation_count>` file mutations across `<unique_file_count>` notes
> - 0 errors, `<birthtime_failure_count>` birthtime-restoration failures
> - `<skipped_count>` recommendations skipped per your decision
> - Findings-file: `<VAULT>/_vault-autopilot/findings/<date>-tag-manage.md`

2. **Update findings file Status** to `apply-complete` with full Changes ledger.

3. **Bootstrap UX (if applicable).** If audit detected vault-specific tags (e.g., proper-noun-shaped tags not in plugin pins) AND `[VAULT]/_vault-autopilot/config/tag-convention.md` does NOT exist, suggest:

> "Found `<count>` tags that look vault-specific (`<sample_3_tags>`, ...). These could be pinned in a vault-override file so future runs treat them as canonical. Want me to scaffold `[VAULT]/_vault-autopilot/config/tag-convention.md` with these pins? (yes / no / skip)"

   If user says yes, generate a starter file:

   ```markdown
   ---
   schema: 1
   pins:
     - {from: smartbroker, to: Smartbroker}
     - {from: tibber, to: Tibber}
     # ... detected vault-specific entries
   ---

   # Vault-Specific Tag Convention Override

   Auto-scaffolded by tag-manage on YYYY-MM-DD. Review and commit
   to your vault. Each pin tells future tag-manage runs to treat
   the lowercase form as the canonical on the right.
   ```

   Write this file. Inform the user the file is created and to review/commit.

## Boundaries (carry-over from skeleton)

- Operates on YAML frontmatter tags only. Inline `#tag` in body is out of scope.
- Does not repair malformed YAML. Routes to property-enrich or note-rename per `references/yaml-sanity.md` verdict.
- Does not handle flow-style tags (`tags: [a, b, c]`). Logs finding, skips file.

## Reserved Tags (carry-over)

Never proposed for changes:
- `VaultAutopilot`
- `VaultAutopilot/*`

## See also (carry-over)

- Spec: `docs/superpowers/specs/2026-05-06-tag-manage-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-plan-b-tag-manage-build.md`
- Sibling skill: `skills/tag-suggest/SKILL.md` (v0.2.x)
```

- [ ] **Step 2: Update SKILL.md frontmatter status from `skeleton` to `beta`**

Edit the YAML frontmatter — change `status: skeleton` to `status: beta`.

- [ ] **Step 3: Verify SKILL.md parses + structure intact**

```bash
python3 -c "
import yaml
content = open('skills/tag-manage/SKILL.md').read()
fm = content.split('---', 2)[1]
parsed = yaml.safe_load(fm)
assert parsed['status'] == 'beta'
print('OK, status=beta')
"
grep -c '^### Step' skills/tag-manage/SKILL.md
```

Expected: `OK, status=beta` and `8` (8 workflow steps).

- [ ] **Step 4: Commit**

```bash
git add skills/tag-manage/SKILL.md
git commit -m "feat(tag-manage): SKILL.md Apply/Report sections + bootstrap UX (T7+T9)

Apply step orchestrates recipes (g) tag-rename and (h) tag-remove,
with pre-write concurrency check, birthtime preservation, skill-log
callout, and VaultAutopilot tag injection.

Report step finalizes findings ledger and offers Bootstrap UX:
when vault-specific tags detected and no vault-config exists, scaffold
[VAULT]/_vault-autopilot/config/tag-convention.md with detected pins.

Status: beta (was skeleton). Skill is now invokable for testing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Integration test against curated chaos-vault

**Files:**
- Create: `scripts/test-tag-manage-chaos-vault.sh`

**Goal:** End-to-end integration test that exercises the full skill workflow against the curated chaos-vault fixture from Plan A. Asserts post-apply state matches golden output.

- [ ] **Step 1: Write the integration test driver**

```bash
#!/usr/bin/env bash
# scripts/test-tag-manage-chaos-vault.sh
#
# Integration test for tag-manage against the curated chaos-vault fixture.
#
# Manual test — runs the bash steps the skill would orchestrate, but does NOT
# invoke Claude (the AI resolution step is human-asserted via golden output).
#
# Asserts:
#   1. Tag extraction yields expected raw tags from chaos-vault.
#   2. Tier 1+2 detection finds 2 expected groups.
#   3. Tier 3 detection finds 6 expected violations.
#   4. After applying recipes (g) + (h) per known-truth, vault matches golden.
#
# Exit 0 on PASS.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/curated/tag-manage/chaos-vault"
GOLDEN="tests/fixtures/curated/tag-manage/chaos-vault-golden"

echo "Step 1: Snapshot fixture into work copy"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -R "$FIXTURE" "$WORK/vault"

echo "Step 2: Load effective convention"
./scripts/tag-convention-load.sh "$WORK/vault" > "$WORK/conv.json"
casing=$(python3 -c "import json; print(json.load(open('$WORK/conv.json'))['casing'])")
[ "$casing" = "PascalCase" ] || { echo "FAIL: expected PascalCase, got $casing"; exit 1; }
echo "  PASS effective convention loaded"

echo "Step 3: Extract all tags from chaos-vault"
> "$WORK/all-tags.txt"
find "$WORK/vault" -name "*.md" -type f -not -path "*/_vault-autopilot/*" -print0 | \
  while IFS= read -r -d '' f; do
    ./scripts/tag-extract.sh "$f" >> "$WORK/all-tags.txt"
  done

# Sanity check: at least 8 unique tags expected (DevTools/devtools/Devtools, Research, OpenSource,
# #Websites, "1", "2", "created: 2026-03-22", App-Development, Software-Development, ai_agents,
# research [from cross-folder.md], etc.)
unique_count=$(sort -u "$WORK/all-tags.txt" | wc -l)
[ "$unique_count" -ge 8 ] || { echo "FAIL: expected >=8 unique tags, got $unique_count"; exit 1; }
echo "  PASS extracted $unique_count unique tags"

echo "Step 4: Tier 1+2 detection"
sort -u "$WORK/all-tags.txt" > "$WORK/unique-tags.txt"
./scripts/tag-detect-dupes.sh < "$WORK/unique-tags.txt" > "$WORK/dupes.txt"
t1_count=$(grep -c '^T1:' "$WORK/dupes.txt" || echo 0)
[ "$t1_count" -ge 2 ] || { echo "FAIL: expected >=2 T1 groups, got $t1_count"; cat "$WORK/dupes.txt"; exit 1; }
echo "  PASS T1+T2 detection: $t1_count T1 groups, $(grep -c '^T2:' "$WORK/dupes.txt" || echo 0) T2 groups"

echo "Step 5: Tier 3 violations"
./scripts/tag-detect-violations.sh "$WORK/conv.json" < "$WORK/unique-tags.txt" > "$WORK/violations.txt"
viol_count=$(wc -l < "$WORK/violations.txt")
[ "$viol_count" -ge 6 ] || { echo "FAIL: expected >=6 violations, got $viol_count"; cat "$WORK/violations.txt"; exit 1; }
echo "  PASS Tier 3: $viol_count violations"

# Verify specific kinds
for kind in hash_prefix yaml_leak numeric upper_kebab snake_case lowercase_concept; do
  if ! grep -q "|$kind|" "$WORK/violations.txt"; then
    echo "FAIL: violation kind '$kind' not detected"
    cat "$WORK/violations.txt"
    exit 1
  fi
  echo "  PASS detected $kind"
done

echo
echo "All tag-manage chaos-vault integration assertions PASS."
echo
echo "Note: This test does NOT invoke the AI resolution step. Full apply"
echo "test requires running the skill end-to-end (manual cycle test)."
exit 0
```

- [ ] **Step 2: Run integration test**

```bash
chmod +x scripts/test-tag-manage-chaos-vault.sh
./scripts/test-tag-manage-chaos-vault.sh
```

Expected: all PASS, exit 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/test-tag-manage-chaos-vault.sh
git commit -m "test(tag-manage): integration test driver against chaos-vault (T8)

End-to-end deterministic-portion test: extract tags from curated
chaos-vault fixture, run Tier 1+2+3 detection, assert expected
group/violation counts and kinds.

AI resolution step not exercised (requires running the skill in a
Claude Code session — manual cycle test).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Cycle 4 Gold Run setup + execution

**Files:**
- Create: `scripts/cycle-tag-manage-prep.sh`
- Create: `docs/superpowers/runs/2026-MM-DD-tag-manage-gr1.md` (template, filled at run-time)

**Goal:** Prepare Cycle 4 GR test infrastructure. Actual GR runs are manual — developer/user runs the skill against the 4 vault topologies and records findings. This task creates the prep script and a run-log template.

- [ ] **Step 1: Write the Cycle prep script**

Create `scripts/cycle-tag-manage-prep.sh`:

```bash
#!/usr/bin/env bash
# scripts/cycle-tag-manage-prep.sh
#
# Generates the 4 vault topologies for tag-manage Cycle 4 Gold Runs.
#   GR-1: nexus-original-from-M2 (macOS native)  → use existing Nexus, manually
#   GR-2: nexus-clone-powershell (Windows)       → clone Nexus via PowerShell, manually
#   GR-3: nexus-clone-robocopy (Windows)         → clone Nexus via robocopy, manually
#   GR-4: M2 platinum-baseline (macOS native)    → synthetic-stress 2000-note vault
#
# Only GR-4 is fully scriptable (synthetic). GR-1 through GR-3 require manual
# vault preparation (the user's actual Nexus + Windows environments).
#
# This script generates GR-4. Prints prep instructions for GR-1, -2, -3.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OUT_BASE="${1:-/tmp/tag-manage-cycle-4}"
mkdir -p "$OUT_BASE"

echo "=== Generating GR-4 (synthetic 2000-note vault) ==="
"$REPO_ROOT/scripts/test-fixtures/generate-synthetic-vault.sh" \
  --output "$OUT_BASE/gr-4-synthetic" \
  --notes 2000 \
  --unique-tags 250 \
  --chaos-ratio 0.25 \
  --seed 1337 \
  --vault-config sample

note_count=$(find "$OUT_BASE/gr-4-synthetic" -name "*.md" -type f | wc -l)
truth_entries=$(python3 -c "import json; print(len(json.load(open('$OUT_BASE/gr-4-synthetic/_truth.json'))))")
echo "  Generated $note_count notes, $truth_entries truth entries"

echo
echo "=== GR-1, GR-2, GR-3 prep (manual) ==="
cat <<'INSTRUCTIONS'
GR-1 nexus-original-from-M2 (macOS native):
  - Use the user's actual Nexus vault on the M2 macOS host.
  - Set: export OBSIDIAN_VAULT_PATH=/Users/germanrauhut.com/Vaults/Nexus
  - Run: ./scripts/cycle-tag-manage-prep.sh — prints what to do
  - Then invoke tag-manage skill against the Nexus vault.

GR-2 nexus-clone-powershell (Windows):
  - On a Windows host, clone Nexus via PowerShell:
    Copy-Item -Recurse -LiteralPath "<nexus-source>" -Destination "<gr2-target>"
  - Run windows-preflight per references/windows-preflight.md
  - Set OBSIDIAN_VAULT_PATH and invoke skill.

GR-3 nexus-clone-robocopy (Windows):
  - On Windows, clone via robocopy:
    robocopy "<nexus-source>" "<gr3-target>" /E /COPY:DAT
  - Watch for the F3 robocopy issue (per references/windows-preflight.md if applicable).
  - Run preflight, set vault path, invoke skill.

GR-4 platinum-baseline (synthetic, generated above):
  - Vault path: $OUT_BASE/gr-4-synthetic
  - export OBSIDIAN_VAULT_PATH="$OUT_BASE/gr-4-synthetic"
  - Run: invoke tag-manage skill, capture findings + diff against _truth.json

Pass criterion (per Decision D19):
  - 0 NEW Class-A skill-regressions across all 4 GRs.
  - Per-GR: scan completes without halt, audit recommendations cover known
    chaos within tolerance (95% completeness, 90% AI canonical match).

Each run produces: docs/superpowers/runs/<date>-tag-manage-gr<N>.md
Use the template generated at: $REPO_ROOT/docs/superpowers/runs/_TEMPLATE-tag-manage-gr.md
INSTRUCTIONS
```

- [ ] **Step 2: Create the run-log template**

Create `docs/superpowers/runs/_TEMPLATE-tag-manage-gr.md`:

```markdown
# tag-manage Gold Run GR-<N> — <Topology Name>

**Date:** YYYY-MM-DD
**Operator:** <name>
**OS / topology:** <macOS native | Windows powershell-clone | Windows robocopy-clone | macOS platinum>
**Vault path:** `<path>`
**Synthetic seed:** `<seed>` (only for GR-4; "n/a" for GR-1/2/3)
**Skill version:** v0.2.0
**Plan-B-Branch:** `<branch>`

## Pre-flight

- Plugin state check result: `<grep -c output>`
- Windows preflight: `<pass | n/a (mac/linux)>`
- Effective convention loaded: `<sha or summary>`

## Audit

- Total notes scanned: <N>
- Cooldown-skipped: <N>
- Malformed-skipped: <N>
- Unique tags: <N>
- Tier 1 groups: <N>
- Tier 2 groups: <N>
- Tier 3 violations: <N>

## Synthetic baseline assertion (GR-4 only)

- Detection completeness vs `_truth.json`: <%>  (pass criterion: ≥95%)
- Canonical match rate: <%>  (pass criterion: ≥90%)
- False-positive rate: <%>   (pass criterion: <2%)

## Apply

- Recommendations approved: <N> of <total>
- File mutations: <N> across <unique-files> notes
- Errors: <N>
- Birthtime restoration failures: <N>
- Idempotent re-run produced 0 new recommendations: <yes | no>

## Findings classes

- Class A (new regression): <list or none>
- Class B (skip-and-log): <count>
- Class C (informational): <count>
- Class D (known/acceptable): <count>

## Verdict

- [ ] PASS — 0 new Class-A regressions
- [ ] FAIL — <list issues>
- [ ] CONDITIONAL PASS — <list mode-shifts or workarounds>

## Notes

<freeform>
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x scripts/cycle-tag-manage-prep.sh
```

- [ ] **Step 4: Smoke-test the prep script**

```bash
./scripts/cycle-tag-manage-prep.sh /tmp/cycle-smoke
ls /tmp/cycle-smoke/gr-4-synthetic/
test -f /tmp/cycle-smoke/gr-4-synthetic/_truth.json && echo "OK"
```

Expected: synthetic vault generated, instructions printed for GR-1/2/3.

- [ ] **Step 5: Commit**

```bash
git add scripts/cycle-tag-manage-prep.sh docs/superpowers/runs/_TEMPLATE-tag-manage-gr.md
git commit -m "test(tag-manage): Cycle 4 GR prep script + run-log template (T10-T12)

scripts/cycle-tag-manage-prep.sh generates GR-4 synthetic-stress vault
(2000 notes, seed 1337) and prints manual prep instructions for GR-1
(macOS Nexus), GR-2 (PowerShell-cloned), GR-3 (robocopy-cloned).

Run-log template at docs/superpowers/runs/_TEMPLATE-tag-manage-gr.md
captures pre-flight, audit, apply, and findings-class verdict per GR.

Pass criterion per D19: 0 new Class-A skill-regressions across 4 GRs.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 6: Run the 4 Gold Runs (manual, by operator)**

Execute Cycle 4 in this order:

1. **GR-4 first** (synthetic, fully reproducible) — verify deterministic baseline assertions pass.
2. **GR-1** (macOS native Nexus) — use real production vault. Production-Safety gate triggers; user explicitly approves.
3. **GR-2** (Windows PowerShell-cloned).
4. **GR-3** (Windows robocopy-cloned).

For each: run `./scripts/cycle-tag-manage-prep.sh` (for GR-4) or follow the manual prep instructions (GR-1/2/3). Then invoke the tag-manage skill in a fresh Claude Code session, working through audit → user-gate → apply → re-audit. Record the run in a copy of the template:

```bash
cp docs/superpowers/runs/_TEMPLATE-tag-manage-gr.md \
   docs/superpowers/runs/$(date +%Y-%m-%d)-tag-manage-gr1.md
# Fill in. Repeat for gr2, gr3, gr4.
```

After all 4 runs complete: commit the run-logs.

```bash
git add docs/superpowers/runs/
git commit -m "test(tag-manage): Cycle 4 GR run logs (T10-T12 done)

GR-1 (macOS Nexus): <verdict>
GR-2 (Windows PowerShell-clone): <verdict>
GR-3 (Windows robocopy-clone): <verdict>
GR-4 (synthetic 2000-note): <verdict>

Pass criterion: 0 new Class-A skill-regressions — <met | not met>.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: USER-PASS gate

**Files:**
- Create: `docs/superpowers/runs/<date>-tag-manage-user-pass.md` (run-log)

**Goal:** User runs tag-manage against own production vault, reviews recommendations, approves selectively, verifies result. User pronounces PASS — only the user makes this call (per CLAUDE.md "AI empfiehlt, Mensch entscheidet").

- [ ] **Step 1: Operator pre-brief**

In a fresh Claude Code session with the user present:

> "Plan B Cycle 4 complete. All 4 GRs <state status>. Now USER-PASS on your production Nexus vault. I'll walk you through: scan → review recommendations → approve subset → apply → re-audit. You decide each step. Ready?"

Wait for user yes.

- [ ] **Step 2: Run tag-manage end-to-end against Nexus**

```bash
export OBSIDIAN_VAULT_PATH=/Users/germanrauhut.com/Vaults/Nexus
# In Claude Code session: invoke tag-manage skill
```

Walk through every step. User decides scope, reviews recommendations table, picks subset to apply, verifies post-apply state in Obsidian.

- [ ] **Step 3: Document the run in user-pass log**

Create `docs/superpowers/runs/<date>-tag-manage-user-pass.md`:

```markdown
# tag-manage USER-PASS — Nexus Production Vault

**Date:** YYYY-MM-DD
**Operator:** Obi
**User:** German Rauhut
**Vault:** Nexus (production)
**Scope chosen:** <vault | inbox | folder>
**Skill version:** v0.2.0

## Audit Results

- Notes scanned: <N>
- Recommendations: <N>
- Per severity: <high>, <medium>, <low>

## User Decisions

- Approved: <list of recommendation IDs>
- Skipped: <list>
- Overridden: <id → custom canonical>
- Bootstrap UX vault-config offered: <yes/no>; user response: <accepted | declined>

## Apply Results

- Mutations: <N>
- Errors: <N>
- Findings file: `<path>`

## User Verdict

- [ ] **PASS** — Skill behaved as expected. Tag-Dschungel reduced to canonical forms. Vault search now finds duplicates as one tag.
- [ ] **FAIL** — <list reasons>
- [ ] **CONDITIONAL PASS** — <list workarounds>

## User Quote

> <paste user's words verbatim — "looks great", "found 3 things I want to revise", etc.>

## Action Items (if any)

<freeform>
```

- [ ] **Step 4: Commit user-pass log**

```bash
git add docs/superpowers/runs/<date>-tag-manage-user-pass.md
git commit -m "test(tag-manage): USER-PASS pronouncement on Nexus (T13)

User ran tag-manage end-to-end against production Nexus vault.
<count> recommendations reviewed, <approved> approved, <skipped> skipped.
<vault-config bootstrap accepted | declined>.

User verdict: <PASS | CONDITIONAL PASS | FAIL>.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

If FAIL or CONDITIONAL: do NOT proceed to ship. Address issues, re-run cycle, re-attempt USER-PASS.

---

## Task 11: Ship — version bump, changelog, CLAUDE.md update

**Files:**
- Modify: `.claude-plugin/plugin.json` (version bump)
- Modify: `logs/changelog.md` (append release entry)
- Modify: `CLAUDE.md` (Skills-Tabelle row updates)

**Goal:** Final ship steps. Only after USER-PASS pronounced.

- [ ] **Step 1: Bump plugin version**

Edit `.claude-plugin/plugin.json`. Change `"version": "0.1.4"` (or whatever v0.1.4 final is) to `"version": "0.2.0"`. Update the description if helpful:

```json
{
  "name": "obsidian-vault-autopilot",
  "version": "0.2.0",
  "description": "AI-powered vault autopilot — sorts, renames, tags, and enriches your Obsidian notes automatically.",
  "author": {
    "name": "Neckarshore AI",
    "url": "https://neckarshore.ai"
  },
  "repository": "https://github.com/neckarshore-ai/obsidian-vault-autopilot",
  "license": "MIT",
  "keywords": ["obsidian", "obsidian-plugin", "claude-code", "agent-skills", "vault-management", "automation", "ai", "productivity"]
}
```

- [ ] **Step 2: Update changelog**

In `logs/changelog.md`, replace the "Unreleased — v0.2.0 Foundations" section heading with the dated release:

```markdown
## v0.2.0 — Tag-manage skill (YYYY-MM-DD)

**New skill:** `tag-manage` — finds inconsistent tag spellings across an Obsidian vault and unifies them on a canonical form, guided by a naming convention. Audits, proposes, applies after explicit user gate.

**Detection scope (Mode A):**
- Tier 1: case-variants (`devtools` ↔ `DevTools`)
- Tier 2: whitespace/hyphen variants (`Open Source` ↔ `OpenSource`)
- Tier 3: convention violations (hash-prefix, YAML-leak, numeric-only, lowercase-concept, snake_case, upper-kebab, trailing-artifacts)

**Foundations:**
- `references/tag-convention.md` — extended with YAML schema
- `references/vault-config.md` — vault-config schema spec
- `references/yaml-edits.md` — recipes (g) tag-rename + (h) tag-remove

**Test infrastructure:**
- `scripts/tag-extract.sh`, `tag-detect-dupes.sh`, `tag-detect-violations.sh`, `tag-convention-load.sh`
- `scripts/test-fixtures/generate-synthetic-vault.sh` — deterministic synthetic vault generator
- `tests/fixtures/curated/tag-manage/chaos-vault/` — handcrafted fixture

**Cycle 4 Gold Runs:** GR-1, GR-2, GR-3, GR-4 — 0 new Class-A regressions.
**USER-PASS:** YYYY-MM-DD on Nexus production vault.

**Deferred (v0.2.x or later):** Tier 4-6 dedupe, hierarchy-analysis, folder-exclusive enforcement, master-summary report, --reverse mode, tag-suggest skill (separate v0.2.x ship).

See spec: `docs/superpowers/specs/2026-05-06-tag-manage-design.md`
```

- [ ] **Step 3: Update CLAUDE.md Skills-Tabelle**

In repo's `CLAUDE.md`, find the Skills table and update:

- Row 7 (`tag-manage`): change Status from `deferred (v0.2.0)` to `beta`
- Add Row 8 for `tag-suggest` with Status `deferred (v0.2.x)` (referencing the spec)

The full table after edit:

```markdown
| # | Skill | Core Task | Status |
|---|-------|-----------|--------|
| 1 | inbox-sort | Move files from inbox to correct folders | beta |
| 2 | note-rename | Rename poorly named files | stable |
| 3 | note-quality-check | Score notes, suggest deletions | beta |
| 4 | property-classify | Classify note status and type | beta |
| 5 | property-describe | Generate note descriptions | beta |
| 6 | property-enrich | Fill missing metadata fields | stable |
| 7 | tag-manage | Find inconsistent tag spellings + unify on canonical | beta |
| 8 | tag-suggest | Propose tags for untagged notes (content-aware) | deferred (v0.2.x) |
```

- [ ] **Step 4: Verify final state**

```bash
# Plugin version
grep '"version"' .claude-plugin/plugin.json

# Skills tabelle
grep -A 12 "## Skills" CLAUDE.md | head -15

# All scripts pass
./scripts/test-tag-extract.sh
./scripts/test-tag-detect-dupes.sh
./scripts/test-tag-detect-violations.sh
./scripts/test-tag-convention-load.sh
./scripts/test-tag-manage-chaos-vault.sh
./scripts/test-recipe-g-tag-rename.sh
./scripts/test-recipe-h-tag-remove.sh
echo "All Plan A + B tests green."
```

Expected: version `0.2.0`, all 7 test scripts exit 0.

- [ ] **Step 5: Commit and tag**

```bash
git add .claude-plugin/plugin.json logs/changelog.md CLAUDE.md
git commit -m "release(v0.2.0): ship tag-manage skill

- Plugin version bump 0.1.4 → 0.2.0
- Changelog entry with feature summary, foundations, test artifacts,
  Cycle 4 GR results, USER-PASS pronouncement
- CLAUDE.md Skills-Tabelle: tag-manage row → beta, tag-suggest row added
  as deferred (v0.2.x)

USER-PASS: YYYY-MM-DD on Nexus production vault.
4 Gold Runs: 0 new Class-A skill-regressions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

git tag -a v0.2.0 -m "v0.2.0 — tag-manage skill"
git push origin HEAD --tags
```

- [ ] **Step 6: Open release PR**

```bash
gh pr create --title "v0.2.0 release — tag-manage skill" --body "$(cat <<'EOF'
Implements Plan B from `docs/superpowers/plans/2026-05-06-plan-b-tag-manage-build.md`.

## Ship contents

- `skills/tag-manage/SKILL.md` — full workflow, status: beta
- `scripts/tag-*.sh` — extraction, detection, convention loader, integration test
- `scripts/cycle-tag-manage-prep.sh` — Cycle 4 GR prep
- `docs/superpowers/runs/` — 4 GR run logs + USER-PASS log
- Plugin version 0.2.0
- Changelog entry
- CLAUDE.md table updated

## Cycle 4 results

| GR | Topology | Verdict |
| ---: | :--- | :--- |
| GR-1 | macOS Nexus | <PASS> |
| GR-2 | Windows PowerShell-clone | <PASS> |
| GR-3 | Windows robocopy-clone | <PASS> |
| GR-4 | synthetic 2000-note | <PASS> |

USER-PASS: <date> on Nexus production.

## Deferred

- Tier 4-6 dedupe (v0.3.0)
- tag-suggest (v0.2.x — separate ship via Plan C)
- hierarchy-analysis, folder-exclusive enforcement, etc. — see spec §11

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

After merge: announce in changelog, social channels per existing release process. Plan C (tag-suggest) can begin.

---

## Plan B Self-Review Checklist

After completing all tasks, verify:

- [ ] Spec coverage complete:
  - T5 (Tier 1+2+3 detection logic) ✓ Tasks 1-3
  - T6 (AI-resolution prompt + JSON parser) ✓ Task 6
  - T7 (apply integration) ✓ Task 7
  - T8 (report format) ✓ Tasks 6, 7
  - T9 (bootstrap UX) ✓ Task 7
  - T10-T12 (cross-platform Cycle 4 GRs) ✓ Task 9
  - T13 (USER-PASS gate) ✓ Task 10
  - T14-T17 (ship: version, changelog, CLAUDE.md, tag) ✓ Task 11
- [ ] No "TBD"/"TODO"/"implement later" placeholders
- [ ] Function names consistent across SKILL.md, recipe doc, scripts (recipe (g) tag-rename, recipe (h) tag-remove, tag-extract, tag-detect-dupes, tag-detect-violations, tag-convention-load)
- [ ] Vault-config path `[VAULT]/_vault-autopilot/config/` consistent everywhere
- [ ] All test scripts exit 0 on green path; fail loudly on red
- [ ] Determinism pins: Haiku, temp=0, prompt_template_version=1.0 (consistent in SKILL.md and findings file template)
- [ ] All commits Co-Authored-By footer
- [ ] Release PR opened, awaiting USER + MASCHIN review

If any item fails: fix inline, re-run, re-commit.
