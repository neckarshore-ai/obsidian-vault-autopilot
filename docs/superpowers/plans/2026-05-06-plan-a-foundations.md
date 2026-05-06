# Plan A — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared foundation for tag-manage (v0.2.0) and tag-suggest (v0.2.x): extended tag-convention.md schema, vault-config.md schema doc, yaml-edits.md recipes (g) tag-rename + (h) tag-remove with tests, synthetic vault generator, and a tag-manage SKILL.md skeleton to validate recipe shapes against actual call sites.

**Architecture:** Foundations land in `references/` (markdown reference files with optional YAML frontmatter for machine-parseable schemas) and `scripts/` (bash utilities + tests with `set -euo pipefail`). The synthetic-vault generator in `scripts/test-fixtures/` is reusable across skills. All work follows the repo's no-multi-line-regex rule for YAML edits — line-by-line, full-line equality matching.

**Tech Stack:** Bash 4+, GNU coreutils, Python 3 (for synthetic generator only — easier YAML/text generation). No external test framework — bash test scripts with `set -euo pipefail` matching the existing `scripts/test-windows-trailing-dot.sh` pattern.

**Sequencing:** This plan can begin only after v0.1.4 ships and public-flip is complete (per spec §13.1).

**Source spec:** `docs/superpowers/specs/2026-05-06-tag-manage-design.md` §13.2 Stage 1 (T1–T4.5)

---

## Task 1: Extend `references/tag-convention.md` with YAML schema

**Files:**
- Modify: `references/tag-convention.md` (replace entire file)

**Goal:** Add YAML frontmatter carrying machine-parseable schema. Keep existing markdown body as human-readable rules. Drop legacy "Common brand names" section content (now expressed as `pins`).

- [ ] **Step 1: Read the current file**

```bash
cat references/tag-convention.md
```

Expected: existing markdown without YAML frontmatter (~36 lines).

- [ ] **Step 2: Write the new file with YAML schema + body**

Write to `references/tag-convention.md`:

```markdown
---
schema: 1

# Casing rule for concept tags
casing: PascalCase

# Hierarchy structure
hierarchy_separator: "/"

# Forbidden patterns (regex, applied during Tier-3 detection)
forbidden_patterns:
  - "^#"
  - "^[0-9]+$"
  - "^(created|modified|last_updated|updated|aliases|type):"

# Canonical-mapping pins. Plugin ships universally-applicable pins.
# Brand handling: a brand pin is one where from == to.lower() and to preserves
# the official casing. No separate brands field — pins is the single source.
pins:
  - {from: github,        to: GitHub}
  - {from: chatgpt,       to: ChatGPT}
  - {from: linkedin,      to: LinkedIn}
  - {from: youtube,       to: YouTube}
  - {from: wordpress,     to: WordPress}
  - {from: figma,         to: Figma}
  - {from: telegram,      to: Telegram}
  - {from: perplexity,    to: Perplexity}
  - {from: tesla,         to: Tesla}
  - {from: docker,        to: Docker}
  - {from: kubernetes,    to: Kubernetes}
  - {from: n8n,           to: n8n}
  - {from: saas,          to: SaaS}
  - {from: mqtt,          to: MQTT}
  - {from: api,           to: API}
  - {from: etf,           to: ETF}
  - {from: bsi,           to: BSI}
  - {from: opensource,    to: OpenSource}
  - {from: lowcode,       to: LowCode}
  - {from: devtools,      to: DevTools}

# Hierarchy prefixes (informational + Tier-3 detection hints)
hierarchy_prefixes:
  - {prefix: "Software/",   purpose: "Commercial SaaS and software"}
  - {prefix: "OpenSource/", purpose: "Open-source projects"}
  - {prefix: "Protocol/",   purpose: "Standards and protocols"}
  - {prefix: "Meta/",       purpose: "Vault management"}

# Folder-exclusive tag rules. RESERVED for v0.3.0+. MVP does not enforce.
folder_exclusive: []
---

# Obsidian Vault Tag Convention (Plugin Default)

This file is the plugin-shipped default for tag-manage and tag-suggest. The YAML frontmatter above is the machine-parseable schema. The markdown below is human-readable guidance.

A vault may override individual fields by creating `[VAULT]/_vault-autopilot/config/tag-convention.md` with the same YAML schema. Merge semantics are defined in `references/vault-config.md`.

## Rules

| # | Rule | Convention | Examples |
| ---: | :--- | :--- | :--- |
| 1 | Standard tags | PascalCase (configurable) | `DevTools`, `OpenSource`, `DayTrading` |
| 2 | Hierarchical tags | PascalCase with `/` | `Software/DevTools`, `OpenSource/AI-ML` |
| 3 | Compound terms | Hyphen between parts when natural | `AI-ML`, `AI-Coding`, `Low-Code` |
| 4 | Brand names | Preserve official casing via `pins` | `n8n`, `SaaS`, `GitHub`, `MQTT` |
| 5 | No `#` prefix | Caught by `forbidden_patterns` | `Research` not `#Research` |
| 6 | No lowercase concept tags | PascalCase rule | `Research` not `research` |

## How to apply

1. Check `pins` first — if the lowercase form maps to a canonical, use that.
2. Otherwise apply the casing rule (default PascalCase).
3. For hierarchical tags, use `hierarchy_separator`.
4. Never produce a tag matching a `forbidden_patterns` regex.

## Vault override

Create `[VAULT]/_vault-autopilot/config/tag-convention.md` with the same YAML schema. Vault values override or extend plugin defaults per `references/vault-config.md`.
```

- [ ] **Step 3: Verify YAML frontmatter parses cleanly**

Run:

```bash
python3 -c "
import yaml
with open('references/tag-convention.md') as f:
    content = f.read()
parts = content.split('---', 2)
schema = yaml.safe_load(parts[1])
print('schema:', schema['schema'])
print('casing:', schema['casing'])
print('pins count:', len(schema['pins']))
assert schema['schema'] == 1
assert schema['casing'] == 'PascalCase'
assert all('from' in p and 'to' in p for p in schema['pins'])
print('OK')
"
```

Expected output:
```
schema: 1
casing: PascalCase
pins count: 20
OK
```

- [ ] **Step 4: Commit**

```bash
git add references/tag-convention.md
git commit -m "spec(v0.2.0): extend tag-convention.md with YAML schema (T1)

Add machine-parseable YAML frontmatter carrying the schema (casing,
hierarchy_separator, forbidden_patterns, pins, hierarchy_prefixes,
folder_exclusive). Drop separate 'brands' concept — pins handles
brand casing as {from: lowercase, to: official}. Markdown body
retained as human-readable guidance.

Foundation for tag-manage v0.2.0 and tag-suggest v0.2.x per
docs/superpowers/specs/2026-05-06-tag-manage-design.md §6.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Create `references/vault-config.md`

**Files:**
- Create: `references/vault-config.md`

**Goal:** Document the vault-config schema, file location, and merge semantics. Skills reference this file for behavior.

- [ ] **Step 1: Write the file**

Create `references/vault-config.md`:

```markdown
# Vault Configuration

Skills in obsidian-vault-autopilot may read per-vault configuration to override or extend plugin defaults. This file defines the location, schema, and merge rules.

## Location

Vault-config files live at:

```
[VAULT]/_vault-autopilot/config/<config-file>.md
```

The `_vault-autopilot/` namespace is the plugin's existing footprint inside the vault (see `references/findings-file.md`). The `config/` subfolder holds machine-parseable configuration.

> **Why not `[VAULT]/.claude/`?** `.claude/` is reserved for Claude Code's own project-config namespace (settings.json, agents/, commands/). If a user runs `claude` from inside the vault directory, `[VAULT]/.claude/` becomes Claude Code's project config and would silently shadow or conflict with vault-config files.

## File format

Each config file has YAML frontmatter (the schema) plus optional markdown body (human-readable docs). Skills parse only the YAML frontmatter.

```markdown
---
schema: 1
# field-specific config
---

# Optional human notes
```

## Skills using vault-config

| Config file | Used by | Plugin default | Schema doc |
| :--- | :--- | :--- | :--- |
| `tag-convention.md` | tag-manage, tag-suggest | `references/tag-convention.md` | This file §"tag-convention schema" |

(More config files added as future skills require per-vault settings.)

## Merge semantics (general)

When a skill loads config:
1. Parse plugin default (e.g., `references/tag-convention.md`). If invalid → ship-blocker.
2. If `[VAULT]/_vault-autopilot/config/<file>.md` exists, parse it. If invalid → halt with file path + line. **No silent fallback to plugin-only.**
3. Merge per per-field rules (see schema doc).

Common merge rules:

| Field type | Merge rule |
| :--- | :--- |
| Scalar (string, int, bool) | Vault wins if defined |
| List of values | Concatenate plugin + vault, dedupe |
| List of objects (with key field) | Concatenate. Vault wins on key collision. |
| `schema` version | Must match plugin (else error). |

The merged result lives in skill memory only — never written back to disk.

## Validation

After merge, skills validate:
- Required fields present
- Cross-field consistency (e.g., for tag-convention: `pins.to` values conform to `casing`)

Inconsistencies trigger warnings (don't halt). Hard schema violations halt loud with file path + line.

## tag-convention schema

The full tag-convention schema is documented in the YAML frontmatter of `references/tag-convention.md`. Fields:

| Field | Type | Plugin? | Vault override? | Merge rule |
| :--- | :--- | :--- | :--- | :--- |
| `schema` | int | required | required | must match |
| `casing` | enum | required | optional | vault wins |
| `hierarchy_separator` | enum | required | optional | vault wins |
| `forbidden_patterns` | list[regex] | required | optional | concat |
| `pins` | list[{from, to}] | required | optional | concat, vault wins on `from` |
| `hierarchy_prefixes` | list[{prefix, purpose}] | required | optional | concat, vault wins on `prefix` |
| `folder_exclusive` | list[{tag, folder}] | always `[]` | optional | vault-only |

### Allowed casing values

| Value | Behavior |
| :--- | :--- |
| `PascalCase` | `Research`, `DayTrading`, `OpenSource` |
| `kebab-case` | `research`, `day-trading`, `open-source` |
| `lowercase` | `research`, `daytrading`, `opensource` |
| `snake_case` | `research`, `day_trading`, `open_source` |

Brand pins always preserve their explicit casing regardless of `casing` value.

### Allowed hierarchy_separator values

| Value | Behavior |
| :--- | :--- |
| `"/"` | `Software/DevTools` |
| `"-"` | `Software-DevTools` |
| `"none"` | flat tags only; hierarchy disabled |

## Bootstrap

If a skill detects vault-specific tags (brands or compounds not in plugin pins) but no vault-override file exists, the skill SHOULD suggest scaffolding one. Skills implement this UX themselves.

## Related references

- `references/tag-convention.md` — plugin default for tag-skills
- `references/findings-file.md` — `_vault-autopilot/findings/` ledger pattern
- `docs/philosophy.md` — "opinionated defaults, configurable everything"
```

- [ ] **Step 2: Verify file is well-formed markdown**

```bash
test -f references/vault-config.md && wc -l references/vault-config.md
```

Expected: file exists, line count ~80.

- [ ] **Step 3: Commit**

```bash
git add references/vault-config.md
git commit -m "spec(v0.2.0): add references/vault-config.md (T2)

Documents the vault-config schema, file location ([VAULT]/_vault-
autopilot/config/), and merge semantics. Sets the precedent for
per-vault configuration across all skills.

Foundation for tag-manage v0.2.0 and tag-suggest v0.2.x.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Add yaml-edits.md recipe (g) tag-rename

**Files:**
- Modify: `references/yaml-edits.md` (append section)
- Create: `scripts/test-recipe-g-tag-rename.sh`
- Create: `tests/fixtures/recipe-g/before/standard.md` and `golden.md`

**Goal:** Define recipe (g) tag-rename as a line-by-line procedure (per repo's anti-multi-line-regex rule). Provide a self-contained bash test script that asserts the recipe behavior against fixture files.

- [ ] **Step 1: Append recipe (g) to yaml-edits.md**

Open `references/yaml-edits.md` and append at end (after existing recipes a–f):

```markdown
## Recipe (g) — tag-rename

**Purpose:** Rename a single tag in YAML frontmatter from `OLD_TAG` to `NEW_TAG`, line-by-line, preserving indentation, marker (`-` or `*`), and quoting style.

**Caller contract:**
- File MUST already pass `references/yaml-sanity.md` (verdict `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER`).
- `OLD_TAG` and `NEW_TAG` are bare tag values without the marker or quotes (e.g., `devtools`, not `  - devtools`).
- Caller decides which file's tag-block to mutate; recipe operates on one file at a time.

**Procedure:**

1. Read the file. Detect line ending (CRLF vs LF) once at the top — preserve the same on write.
2. Split into lines (preserve original line endings during split).
3. Find the frontmatter open: the FIRST line equal to `---` after `rstrip('\r\n')`.
4. Find the frontmatter close: the NEXT line equal to `---` after the open.
5. Within `[open+1 .. close-1]`, find the `tags:` line. Match by exact line-prefix `tags:` followed by either nothing, whitespace, `[]`, or `[`.
   - If `tags:` line has flow-style `[a, b, c]` → SKIP recipe, return verdict `flow_style_skipped`. Log a finding.
   - If `tags:` line has block style (no `[` on same line) → continue.
6. Walk subsequent lines. For each line, check if it matches one of these four list-item shapes (using full-line regex, single-line only):
   - Shape 1 (unquoted dash):    `^  - <TAG>$`
   - Shape 2 (quoted dash):      `^  - "<TAG>"$`  or  `^  - '<TAG>'$`
   - Shape 3 (unquoted star):    `^  \* <TAG>$`
   - Shape 4 (quoted star):      `^  \* "<TAG>"$`  or  `^  \* '<TAG>'$`
   Where `<TAG>` is the bare tag value.
7. If a list-item line is found whose `<TAG>` equals `OLD_TAG` (after stripping trailing comma):
   - Replace just the `<TAG>` portion with `NEW_TAG`. Preserve marker, indentation, and quoting.
   - If the original had a trailing comma (`  - business,`), strip the comma in the rewrite.
   - Continue scanning — there may be duplicate entries (caller dedupes if needed).
8. If the list-item walk hits a line that does NOT match any of Shapes 1–4 (or is the closing `---`), stop the tag-list scan.
9. Write the file back with detected line ending.

**Idempotent:** Running twice with same OLD_TAG/NEW_TAG produces identical output the second time.

**Edge cases:**
- Trailing colon (`  - publictags:`) and trailing quote (`  - #smartbroker"`) are NOT handled by recipe (g) — those tags should be removed via recipe (h), not renamed. Caller decides.
- `tags:` on its own line with no list items → no-op for rename. Verdict `no_match`.
- Multiple `tags:` entries in frontmatter → invalid YAML, should have been caught by yaml-sanity. Recipe operates on FIRST `tags:` only.
- Tag with internal hyphen, slash, or special chars (e.g., `Software/DevTools`) → matched literally, no special escaping needed within the line-shape regex (regex engines treat `/` literally).

**Reference implementation (bash):** see `scripts/test-recipe-g-tag-rename.sh` for the canonical test script that exercises recipe (g) against fixtures. Skills implementing the recipe should mirror this logic.
```

- [ ] **Step 2: Create the test fixtures — `before/standard.md`**

Create `tests/fixtures/recipe-g/before/standard.md`:

```markdown
---
title: Sample Note
created: 2026-04-01
tags:
  - devtools
  - Research
  - "#Websites"
  - * mixed-marker
modified: 2026-05-01
---

# Sample Note

Body text here.
```

(Note: line 7 has `  * mixed-marker` deliberately, to test Shape 3.)

- [ ] **Step 3: Create the test fixtures — `golden/standard-after-rename.md`**

Create `tests/fixtures/recipe-g/golden/standard-after-rename.md` (expected result of renaming `devtools` to `DevTools`):

```markdown
---
title: Sample Note
created: 2026-04-01
tags:
  - DevTools
  - Research
  - "#Websites"
  - * mixed-marker
modified: 2026-05-01
---

# Sample Note

Body text here.
```

- [ ] **Step 4: Write the test script**

Create `scripts/test-recipe-g-tag-rename.sh`:

```bash
#!/usr/bin/env bash
# scripts/test-recipe-g-tag-rename.sh
#
# Test driver for yaml-edits.md recipe (g) tag-rename.
# Implements the recipe in pure bash + sed (single-line, full-line equality
# only — NO multi-line regex per repo's yaml-edits.md rule).
#
# Asserts:
#   1. Renaming devtools -> DevTools produces golden/standard-after-rename.md
#   2. Idempotent: running again produces identical output
#   3. flow-style tags (tags: [a, b]) are skipped with verdict flow_style_skipped
#
# Exit 0 on PASS. Exit 1 on first failure with diff.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURES="tests/fixtures/recipe-g"

# ---------------------------------------------------------------------------
# Recipe (g) implementation in bash
# ---------------------------------------------------------------------------

# Usage: recipe_g_tag_rename <file> <old_tag> <new_tag>
# Returns: prints "OK", "no_match", or "flow_style_skipped" to stdout
recipe_g_tag_rename() {
  local file="$1"
  local old_tag="$2"
  local new_tag="$3"

  # Detect line ending
  local has_crlf
  if grep -q $'\r' "$file"; then has_crlf=1; else has_crlf=0; fi

  local in_frontmatter=0
  local in_tags=0
  local found_match=0
  local flow_skipped=0
  local tmp
  tmp=$(mktemp)

  while IFS= read -r line || [ -n "$line" ]; do
    local stripped="${line%$'\r'}"

    if [ "$in_frontmatter" -eq 0 ] && [ "$stripped" = "---" ]; then
      in_frontmatter=1
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi

    if [ "$in_frontmatter" -eq 1 ] && [ "$stripped" = "---" ]; then
      in_frontmatter=2
      in_tags=0
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi

    if [ "$in_frontmatter" -eq 1 ]; then
      # Detect tags: line
      if [[ "$stripped" =~ ^tags:\ *\[ ]]; then
        flow_skipped=1
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi
      if [[ "$stripped" =~ ^tags:\ *$ ]]; then
        in_tags=1
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi
      if [ "$in_tags" -eq 1 ]; then
        # Try to match list-item shapes for the old_tag
        local rewritten="$stripped"
        # Shape 1: unquoted dash
        if [[ "$stripped" =~ ^"  - ${old_tag},?"$ ]]; then
          rewritten="  - ${new_tag}"
          found_match=1
        # Shape 2: dash + double quote
        elif [[ "$stripped" =~ ^"  - \"${old_tag}\"" ]]; then
          rewritten="  - \"${new_tag}\""
          found_match=1
        # Shape 2': dash + single quote
        elif [[ "$stripped" =~ ^"  - '${old_tag}'" ]]; then
          rewritten="  - '${new_tag}'"
          found_match=1
        # Shape 3: unquoted star
        elif [[ "$stripped" =~ ^"  \\* ${old_tag},?"$ ]]; then
          rewritten="  * ${new_tag}"
          found_match=1
        # Shape 4: star + double quote
        elif [[ "$stripped" =~ ^"  \\* \"${old_tag}\"" ]]; then
          rewritten="  * \"${new_tag}\""
          found_match=1
        # Shape 4': star + single quote
        elif [[ "$stripped" =~ ^"  \\* '${old_tag}'" ]]; then
          rewritten="  * '${new_tag}'"
          found_match=1
        else
          # If line doesn't match a list-item shape, exit tags scan
          if ! [[ "$stripped" =~ ^"  - " ]] && ! [[ "$stripped" =~ ^"  \\* " ]]; then
            in_tags=0
          fi
        fi
        if [ "$has_crlf" -eq 1 ]; then
          printf '%s\r\n' "$rewritten" >> "$tmp"
        else
          printf '%s\n' "$rewritten" >> "$tmp"
        fi
        continue
      fi
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$file"

  mv "$tmp" "$file"

  if [ "$flow_skipped" -eq 1 ]; then
    echo "flow_style_skipped"
  elif [ "$found_match" -eq 1 ]; then
    echo "OK"
  else
    echo "no_match"
  fi
}

# ---------------------------------------------------------------------------
# Test 1: rename devtools -> DevTools, compare to golden
# ---------------------------------------------------------------------------

echo "Test 1: rename devtools -> DevTools"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$FIXTURES/before/standard.md" "$WORK/standard.md"

verdict=$(recipe_g_tag_rename "$WORK/standard.md" "devtools" "DevTools")
if [ "$verdict" != "OK" ]; then
  echo "FAIL: expected verdict OK, got $verdict"
  exit 1
fi
if ! diff -u "$FIXTURES/golden/standard-after-rename.md" "$WORK/standard.md"; then
  echo "FAIL: result differs from golden"
  exit 1
fi
echo "  PASS"

# ---------------------------------------------------------------------------
# Test 2: idempotency
# ---------------------------------------------------------------------------

echo "Test 2: idempotency (rename DevTools -> DevTools again)"
verdict=$(recipe_g_tag_rename "$WORK/standard.md" "DevTools" "DevTools")
# Either no_match or OK — both acceptable for idempotency
if ! diff -u "$FIXTURES/golden/standard-after-rename.md" "$WORK/standard.md"; then
  echo "FAIL: idempotent rename changed file"
  exit 1
fi
echo "  PASS"

echo
echo "All recipe (g) tests PASS."
exit 0
```

- [ ] **Step 5: Make the test executable and run it — expect FAIL first time**

```bash
chmod +x scripts/test-recipe-g-tag-rename.sh
./scripts/test-recipe-g-tag-rename.sh || true
```

Expected: First run will likely show test passes for Test 1+2 because the script is self-contained (recipe + tests in same file). If a regex bug exists, fix it inline before commit.

- [ ] **Step 6: Iterate on regex shape until tests pass**

Common failure: Bash `[[ =~ ]]` regex syntax with quotes is finicky. Inspect the diff output carefully — the test script writes the actual file in-place to `$WORK`, so reading `$WORK/standard.md` after a failed run shows the actual mutation.

- [ ] **Step 7: Commit recipe + tests + fixtures**

```bash
git add references/yaml-edits.md \
        scripts/test-recipe-g-tag-rename.sh \
        tests/fixtures/recipe-g/
git commit -m "spec(v0.2.0): add yaml-edits.md recipe (g) tag-rename + tests (T3a)

Recipe (g) handles tag-rename across the 4 YAML list-item formats
(  - tag,   - \"tag\",   * tag,   * \"tag\"). Line-by-line per
repo's anti-multi-line-regex rule. Idempotent.

Includes:
- references/yaml-edits.md: appended recipe (g) doc + procedure
- scripts/test-recipe-g-tag-rename.sh: self-contained test driver
- tests/fixtures/recipe-g/: before + golden fixtures

Test pass criterion: both Test 1 (rename) and Test 2 (idempotency)
exit 0.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Add yaml-edits.md recipe (h) tag-remove

**Files:**
- Modify: `references/yaml-edits.md` (append after recipe g)
- Create: `scripts/test-recipe-h-tag-remove.sh`
- Create: `tests/fixtures/recipe-h/before/`, `golden/`

**Goal:** Recipe (h) deletes a tag-list-item line entirely. Empty tags-block stays as `tags: []` (do not remove the `tags:` key).

- [ ] **Step 1: Append recipe (h) to yaml-edits.md**

Append at end of `references/yaml-edits.md`:

```markdown
## Recipe (h) — tag-remove

**Purpose:** Remove a single tag entry from YAML frontmatter, line-by-line. Used for convention-violating tags that have no canonical (hash-prefix artifacts, YAML-leak artifacts, numeric-only tags).

**Caller contract:** Same as recipe (g). File passes yaml-sanity. `TAG_TO_REMOVE` is the bare tag value.

**Procedure:**

1–6. Same as recipe (g) Steps 1–6 (read, find frontmatter, find `tags:`, walk list items).
7. If a list-item line matches `TAG_TO_REMOVE` (any of the 4 shapes, with optional trailing comma): DELETE the line from the line list.
8. Continue scanning. Multiple matches may exist; remove all.
9. After tag-list scan: if the tags-block is now empty (no list items between `tags:` line and the next non-list-item line), replace `tags:` line with `tags: []` to keep the key present (other tools may rely on it).
10. Write file back with detected line ending.

**Idempotent:** Running twice removes the tag once; second run finds no match → `no_match`.

**Edge cases:**
- Tag-list with only the removed tag → results in `tags: []`.
- Same tag appears multiple times in tags-block (rare but possible) → all instances removed.
- Tag with trailing artifacts (`  - #smartbroker"`, `  - public-sectortags:`) → matched if `TAG_TO_REMOVE` is the literal string with the artifact (caller passes the bare line-content). Recipe is literal-match only.

**Verdict values:** `OK` (one or more removals), `no_match`, `flow_style_skipped`.
```

- [ ] **Step 2: Create fixtures**

Create `tests/fixtures/recipe-h/before/with-numeric.md`:

```markdown
---
title: Sample
tags:
  - "1"
  - Research
  - "1"
  - "#Websites"
---

Body.
```

Create `tests/fixtures/recipe-h/golden/after-remove-numeric.md` (after removing tag `1`):

```markdown
---
title: Sample
tags:
  - Research
  - "#Websites"
---

Body.
```

Create `tests/fixtures/recipe-h/before/all-removed.md`:

```markdown
---
title: All Junk
tags:
  - "1"
---

Body.
```

Create `tests/fixtures/recipe-h/golden/all-removed-result.md`:

```markdown
---
title: All Junk
tags: []
---

Body.
```

- [ ] **Step 3: Write `scripts/test-recipe-h-tag-remove.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-recipe-h-tag-remove.sh
#
# Test driver for yaml-edits.md recipe (h) tag-remove.
# Pure bash, line-by-line, full-line equality matching only.
#
# Asserts:
#   1. Removing "1" from with-numeric.md (2 instances) produces golden
#   2. Removing the only tag from all-removed.md produces tags: []
#   3. Idempotent: removing already-absent tag returns no_match
#
# Exit 0 on PASS.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURES="tests/fixtures/recipe-h"

# Implementation: same line-by-line walk as recipe (g) but DELETE matched lines.
# After tag-list scan, if no list items remain, replace `tags:` line with `tags: []`.

recipe_h_tag_remove() {
  local file="$1"
  local tag="$2"
  local has_crlf
  if grep -q $'\r' "$file"; then has_crlf=1; else has_crlf=0; fi

  local tmp
  tmp=$(mktemp)
  local in_fm=0 in_tags=0 tags_line_index=-1 list_count=0 removed=0
  local lines=() i=0
  while IFS= read -r line || [ -n "$line" ]; do
    lines+=("$line")
  done < "$file"

  local out=()
  for ((i=0; i<${#lines[@]}; i++)); do
    local line="${lines[i]}"
    local stripped="${line%$'\r'}"

    if [ "$in_fm" -eq 0 ] && [ "$stripped" = "---" ]; then
      in_fm=1
      out+=("$line")
      continue
    fi
    if [ "$in_fm" -eq 1 ] && [ "$stripped" = "---" ]; then
      in_fm=2
      in_tags=0
      out+=("$line")
      continue
    fi
    if [ "$in_fm" -eq 1 ]; then
      if [[ "$stripped" =~ ^tags:\ *$ ]]; then
        in_tags=1
        tags_line_index=${#out[@]}
        list_count=0
        out+=("$line")
        continue
      fi
      if [ "$in_tags" -eq 1 ]; then
        # Match any of 4 list-item shapes for `tag`
        local match=0
        if [[ "$stripped" =~ ^"  - ${tag},?"$ ]]; then match=1; fi
        if [[ "$stripped" =~ ^"  - \"${tag}\"",?$ ]]; then match=1; fi
        if [[ "$stripped" =~ ^"  - '${tag}'",?$ ]]; then match=1; fi
        if [[ "$stripped" =~ ^"  \\* ${tag},?"$ ]]; then match=1; fi
        if [[ "$stripped" =~ ^"  \\* \"${tag}\"",?$ ]]; then match=1; fi
        if [[ "$stripped" =~ ^"  \\* '${tag}'",?$ ]]; then match=1; fi

        if [ "$match" -eq 1 ]; then
          removed=$((removed + 1))
          continue   # skip this line (removed)
        fi
        # Other list-item shapes: count as kept
        if [[ "$stripped" =~ ^"  - " ]] || [[ "$stripped" =~ ^"  \\* " ]]; then
          list_count=$((list_count + 1))
          out+=("$line")
          continue
        fi
        # Non-list-item line → end of tags-block
        in_tags=0
      fi
    fi
    out+=("$line")
  done

  # If we removed all list items, rewrite the tags: line to tags: []
  if [ "$tags_line_index" -ge 0 ] && [ "$list_count" -eq 0 ] && [ "$removed" -gt 0 ]; then
    if [ "$has_crlf" -eq 1 ]; then
      out[$tags_line_index]=$'tags: []\r'
    else
      out[$tags_line_index]="tags: []"
    fi
  fi

  printf '%s\n' "${out[@]}" > "$tmp"
  mv "$tmp" "$file"

  if [ "$removed" -eq 0 ]; then
    echo "no_match"
  else
    echo "OK"
  fi
}

# ---------------------------------------------------------------------------
# Test 1: remove "1" from with-numeric (2 occurrences)
# ---------------------------------------------------------------------------

echo "Test 1: remove '1' from with-numeric.md"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cp "$FIXTURES/before/with-numeric.md" "$WORK/wn.md"
verdict=$(recipe_h_tag_remove "$WORK/wn.md" "1")
[ "$verdict" = "OK" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
diff -u "$FIXTURES/golden/after-remove-numeric.md" "$WORK/wn.md" || { echo "FAIL: diff"; exit 1; }
echo "  PASS"

# ---------------------------------------------------------------------------
# Test 2: remove sole tag, expect tags: []
# ---------------------------------------------------------------------------

echo "Test 2: remove sole tag from all-removed.md"
cp "$FIXTURES/before/all-removed.md" "$WORK/ar.md"
verdict=$(recipe_h_tag_remove "$WORK/ar.md" "1")
[ "$verdict" = "OK" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
diff -u "$FIXTURES/golden/all-removed-result.md" "$WORK/ar.md" || { echo "FAIL: diff"; exit 1; }
echo "  PASS"

# ---------------------------------------------------------------------------
# Test 3: idempotency — remove a tag that's not there
# ---------------------------------------------------------------------------

echo "Test 3: idempotency (remove already-absent tag)"
verdict=$(recipe_h_tag_remove "$WORK/wn.md" "1")
[ "$verdict" = "no_match" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
echo "  PASS"

echo
echo "All recipe (h) tests PASS."
exit 0
```

- [ ] **Step 4: Run the test, iterate until green**

```bash
chmod +x scripts/test-recipe-h-tag-remove.sh
./scripts/test-recipe-h-tag-remove.sh
```

Expected: all three tests pass. If they don't, inspect the actual `$WORK` files (the script's temp dir gets deleted on exit — comment out the `trap` line during debug).

- [ ] **Step 5: Commit**

```bash
git add references/yaml-edits.md \
        scripts/test-recipe-h-tag-remove.sh \
        tests/fixtures/recipe-h/
git commit -m "spec(v0.2.0): add yaml-edits.md recipe (h) tag-remove + tests (T3b)

Recipe (h) handles tag-remove across the 4 YAML list-item formats.
Empty tags-block becomes \`tags: []\` (key preserved). Line-by-line.

Test pass criterion: rename + sole-tag + idempotency tests all green.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Synthetic vault generator — base scaffold

**Files:**
- Create: `scripts/test-fixtures/generate-synthetic-vault.sh`
- Create: `scripts/test-fixtures/data/tag-vocabulary.txt`
- Create: `scripts/test-fixtures/data/body-templates/work.txt`
- Create: `scripts/test-fixtures/data/body-templates/research.txt`
- Create: `scripts/test-fixtures/data/body-templates/personal.txt`
- Create: `scripts/test-fixtures/README.md`

**Goal:** A reusable bash + Python generator that produces an Obsidian-shaped synthetic vault with deterministic chaos injection. Used by Plan B and Plan C cycle tests.

- [ ] **Step 1: Create vocabulary file**

Create `scripts/test-fixtures/data/tag-vocabulary.txt` (~80 lines, one tag per line):

```
Research
DayTrading
DevTools
OpenSource
Meeting
Project
SaaS
GitHub
ChatGPT
LinkedIn
Trading
ETF
Investing
Health
Fitness
Cooking
Travel
Finance
Personal
Family
Strategy
Marketing
Sales
Product
Engineering
DevOps
Cloud
Database
Frontend
Backend
Mobile
API
MQTT
Kubernetes
Docker
Python
JavaScript
TypeScript
React
NextJS
Tailwind
Design
UX
UI
Branding
Content
Writing
Reading
Books
Podcasts
Music
Photography
Video
Education
Learning
Skill
Certification
Compliance
Security
Privacy
Networking
Hardware
Software/AI-ML
Software/DevTools
Software/FinTech
OpenSource/AI-ML
OpenSource/CLI
OpenSource/DevTools
Protocol/Payments
Protocol/Identity
Protocol/AI
Meta/Inbox
Meta/Daily
Meta/Weekly
Performance
Optimization
Refactoring
Architecture
Patterns
Testing
Documentation
```

- [ ] **Step 2: Create body templates**

Create `scripts/test-fixtures/data/body-templates/work.txt` (one body per blank-line-separated block):

```
Met with the OGC team today to align on Q2 marketing strategy. Key decisions: focus on member acquisition through content channels, retire underperforming Facebook ads, double down on LinkedIn organic. Next steps: brief Linus on landing page redesign.

Sprint planning notes for the next two weeks. Stories: API rate limiting (P0), Stripe webhook hardening (P0), database migration to Postgres 16 (P1). Capacity: 32 points across 4 engineers. Risks: holidays week 2.

Customer interview with the CFO of Acme Corp. They use SaaS for finance, Salesforce for CRM, but pain point is reconciliation between systems. Open to a Plaid integration if it reduces manual work. Action: send proposal Friday.

Notes from the all-hands. Q1 numbers came in 8% above plan. Hiring freeze lifted for engineering. New OKR cycle starts Monday. CFO presentation deck shared in #leadership.
```

Create `scripts/test-fixtures/data/body-templates/research.txt`:

```
Read the new paper on retrieval-augmented generation. Key insight: re-ranking with cross-encoders meaningfully improves answer quality on long-context QA. Implications for our agent stack — switch from naive vector retrieval to hybrid bm25 + dense + rerank.

Dive into Kubernetes operators. The reconciliation loop pattern is elegant — declare desired state, controller drives current state toward it. Going to prototype an operator for our internal cron-job-management problem.

Notes on Bitcoin's UTXO model versus Ethereum's account model. UTXO is more parallelizable but harder to reason about for stateful contracts. Account model is simpler but creates serialization bottlenecks. Trade-offs everywhere.

Comparison of VPS providers for our staging environment: Hetzner is cheapest, Contabo has more RAM per dollar, Hostinger is easiest UI. Decision: Hetzner for base, scale up via API as load grows.
```

Create `scripts/test-fixtures/data/body-templates/personal.txt`:

```
Cycling route from Tübingen to Stuttgart via the Neckar trail. 47 km, mostly flat after the first climb out of Reutlingen. Bring extra water — the gas stations between Plochingen and Esslingen close on Sundays.

Recipe: pumpkin curry with red lentils. Soak the lentils for an hour, sauté onions and garlic, add curry paste and pumpkin chunks, simmer 25 minutes. Serve with rice or naan. Family loved it.

Booked the family vacation to Bavaria. House in Berchtesgaden, week of Aug 14. Activities: salt mine tour for the kids, Königssee boat ride, Eagle's Nest hike for me and Anna.

Visited the Schickhardt-GMS open day. The school's STEM program is impressive — robotics lab, 3D printers, partnership with local engineering firms. Worth considering for the kids next year.
```

- [ ] **Step 3: Create the generator script**

Create `scripts/test-fixtures/generate-synthetic-vault.sh`:

```bash
#!/usr/bin/env bash
# scripts/test-fixtures/generate-synthetic-vault.sh
#
# Generates a synthetic Obsidian vault for testing tag-skills.
#
# Usage: generate-synthetic-vault.sh \
#          --output <path> \
#          [--notes <int>] \
#          [--unique-tags <int>] \
#          [--chaos-ratio <0..1>] \
#          [--seed <int>] \
#          [--vault-config <none|sample>]
#
# Defaults: --notes 500 --unique-tags 80 --chaos-ratio 0.3 --seed 42
#
# Output:
#   <path>/.obsidian/                 (empty marker dir)
#   <path>/001_Inbox/...              (notes)
#   <path>/010_Outcomes/...
#   <path>/020_Processes/...
#   <path>/030_Reference/...
#   <path>/_truth.json                (chaos baseline for assertions)
#
# Determinism: same seed + flags = byte-identical output (excluding root path).

set -euo pipefail

OUTPUT=""
NOTES=500
UNIQUE_TAGS=80
CHAOS_RATIO=0.3
SEED=42
VAULT_CONFIG=none

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)        OUTPUT="$2"; shift 2 ;;
    --notes)         NOTES="$2"; shift 2 ;;
    --unique-tags)   UNIQUE_TAGS="$2"; shift 2 ;;
    --chaos-ratio)   CHAOS_RATIO="$2"; shift 2 ;;
    --seed)          SEED="$2"; shift 2 ;;
    --vault-config)  VAULT_CONFIG="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  echo "ERROR: --output required"
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DATA_DIR="$REPO_ROOT/scripts/test-fixtures/data"

mkdir -p "$OUTPUT/.obsidian"
mkdir -p "$OUTPUT/001_Inbox"
mkdir -p "$OUTPUT/010_Outcomes"
mkdir -p "$OUTPUT/020_Processes"
mkdir -p "$OUTPUT/030_Reference"

# Delegate to Python for randomization + YAML/JSON output (cleaner than bash for that).
python3 "$REPO_ROOT/scripts/test-fixtures/generate.py" \
  --output "$OUTPUT" \
  --notes "$NOTES" \
  --unique-tags "$UNIQUE_TAGS" \
  --chaos-ratio "$CHAOS_RATIO" \
  --seed "$SEED" \
  --vault-config "$VAULT_CONFIG" \
  --vocab-file "$DATA_DIR/tag-vocabulary.txt" \
  --body-templates-dir "$DATA_DIR/body-templates"

echo "Synthetic vault generated at: $OUTPUT"
echo "Notes: $NOTES, unique tags base: $UNIQUE_TAGS, chaos ratio: $CHAOS_RATIO, seed: $SEED"
```

- [ ] **Step 4: Create the Python helper**

Create `scripts/test-fixtures/generate.py`:

```python
#!/usr/bin/env python3
"""
generate.py — randomized synthetic-vault generator delegated from
generate-synthetic-vault.sh. Deterministic via --seed.
"""
import argparse
import json
import os
import random
import re
from datetime import datetime, timedelta

CHAOS_VARIANTS = [
    ("lowercase",  lambda t: t.lower()),
    ("Devtoolsy",  lambda t: t.capitalize()),  # Devtools instead of DevTools
    ("hyphenated", lambda t: t.lower().replace("/", "-")),
    ("spaced",     lambda t: t.lower().replace("/", " ")),
    ("snake",      lambda t: t.lower().replace("/", "_")),
]

VIOLATIONS = [
    ("hash_prefix", lambda t: f"#{t}"),
    ("yaml_leak",  lambda t: f"created: 2026-{(hash(t)%12)+1:02d}-{(hash(t[:1])%28)+1:02d}"),
    ("numeric",    lambda t: str(hash(t) % 100)),
    ("upper_kebab", lambda t: t.replace("/", "-") if "/" not in t else t),
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", required=True)
    ap.add_argument("--notes", type=int, required=True)
    ap.add_argument("--unique-tags", type=int, required=True)
    ap.add_argument("--chaos-ratio", type=float, required=True)
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--vault-config", choices=["none", "sample"], required=True)
    ap.add_argument("--vocab-file", required=True)
    ap.add_argument("--body-templates-dir", required=True)
    args = ap.parse_args()

    random.seed(args.seed)

    with open(args.vocab_file) as f:
        full_vocab = [line.strip() for line in f if line.strip()]
    base_tags = full_vocab[:args.unique_tags] if len(full_vocab) >= args.unique_tags else full_vocab

    # Body templates per domain
    domains = {}
    for fname in os.listdir(args.body_templates_dir):
        domain = os.path.splitext(fname)[0]
        with open(os.path.join(args.body_templates_dir, fname)) as f:
            content = f.read()
        domains[domain] = [b.strip() for b in content.split("\n\n") if b.strip()]

    folders = ["001_Inbox", "010_Outcomes", "020_Processes", "030_Reference"]
    truth = []

    # Zipfian frequency: top 20% of tags carry ~80% of usage
    weights = [1.0 / (i + 1) for i in range(len(base_tags))]
    weight_sum = sum(weights)
    weights = [w / weight_sum for w in weights]

    for note_idx in range(args.notes):
        folder = random.choice(folders)
        domain = random.choice(list(domains.keys()))
        body = random.choice(domains[domain])
        title = f"Note {note_idx:04d}"
        created = (datetime(2024, 1, 1) + timedelta(days=note_idx % 700)).strftime("%Y-%m-%d")

        # Pick 1-4 tags weighted toward head
        n_tags = random.choices([1, 2, 3, 4], weights=[1, 3, 4, 2])[0]
        chosen = random.choices(base_tags, weights=weights, k=n_tags)
        chosen = list(dict.fromkeys(chosen))  # dedupe

        # Apply chaos to a fraction of chosen tags
        final_tags = []
        for tag in chosen:
            if random.random() < args.chaos_ratio:
                if random.random() < 0.6:
                    # case-variant chaos (Tier 1/2)
                    name, fn = random.choice(CHAOS_VARIANTS)
                    chaos_tag = fn(tag)
                    truth.append({
                        "file": f"{folder}/{title}.md",
                        "original_tag": chaos_tag,
                        "expected_canonical": tag,
                        "tier": 1 if name == "lowercase" else 2,
                        "kind": name,
                    })
                    final_tags.append(chaos_tag)
                else:
                    # convention violation (Tier 3)
                    name, fn = random.choice(VIOLATIONS)
                    chaos_tag = fn(tag)
                    truth.append({
                        "file": f"{folder}/{title}.md",
                        "original_tag": chaos_tag,
                        "expected_canonical": None if name in ("yaml_leak", "numeric") else tag,
                        "tier": 3,
                        "kind": name,
                    })
                    final_tags.append(chaos_tag)
            else:
                final_tags.append(tag)

        path = os.path.join(args.output, folder, f"{title}.md")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("---\n")
            f.write(f"title: {title}\n")
            f.write(f"created: {created}\n")
            f.write("tags:\n")
            for t in final_tags:
                # Quote tags with special chars (#, :, leading digit)
                if re.match(r'^[#0-9]', t) or ':' in t or '/' in t:
                    f.write(f'  - "{t}"\n')
                else:
                    f.write(f"  - {t}\n")
            f.write("---\n\n")
            f.write(f"# {title}\n\n")
            f.write(body + "\n")

    # Write _truth.json
    with open(os.path.join(args.output, "_truth.json"), "w") as f:
        json.dump(truth, f, indent=2, sort_keys=True)

    # Optional vault-config
    if args.vault_config == "sample":
        cfg_dir = os.path.join(args.output, "_vault-autopilot", "config")
        os.makedirs(cfg_dir, exist_ok=True)
        with open(os.path.join(cfg_dir, "tag-convention.md"), "w") as f:
            f.write("---\nschema: 1\npins:\n")
            f.write("  - {from: smartbroker, to: Smartbroker}\n")
            f.write("  - {from: tibber, to: Tibber}\n")
            f.write("---\n\n# Sample vault override\n")

    print(f"Generated {args.notes} notes, {len(truth)} chaos entries.")

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Make scripts executable, smoke-test the generator**

```bash
chmod +x scripts/test-fixtures/generate-synthetic-vault.sh
chmod +x scripts/test-fixtures/generate.py

# Generate a tiny vault to verify
./scripts/test-fixtures/generate-synthetic-vault.sh \
  --output /tmp/synthetic-smoke \
  --notes 20 --unique-tags 15 --chaos-ratio 0.5 --seed 42

# Inspect
ls /tmp/synthetic-smoke/
cat /tmp/synthetic-smoke/_truth.json | python3 -c "import json,sys; print(len(json.load(sys.stdin)), 'chaos entries')"
ls /tmp/synthetic-smoke/001_Inbox/ | head -3
cat /tmp/synthetic-smoke/001_Inbox/Note\ 0000.md
```

Expected: 20 notes distributed across 4 folders, _truth.json has ~10 entries (50% chaos × ~20 notes × ~1.5 tags/note × dedupe).

- [ ] **Step 6: Verify determinism — run twice with same seed**

```bash
rm -rf /tmp/synthetic-a /tmp/synthetic-b
./scripts/test-fixtures/generate-synthetic-vault.sh --output /tmp/synthetic-a --notes 20 --seed 42
./scripts/test-fixtures/generate-synthetic-vault.sh --output /tmp/synthetic-b --notes 20 --seed 42
diff -r /tmp/synthetic-a /tmp/synthetic-b && echo "DETERMINISTIC"
```

Expected: `DETERMINISTIC` (no diff output).

- [ ] **Step 7: Create README**

Create `scripts/test-fixtures/README.md`:

```markdown
# Synthetic Vault Generator

Deterministic generator for Obsidian-shaped test vaults with controlled tag-chaos injection.

## Usage

```bash
./generate-synthetic-vault.sh \
  --output /tmp/test-vault \
  --notes 500 \
  --unique-tags 80 \
  --chaos-ratio 0.3 \
  --seed 42
```

## Output

- `<output>/.obsidian/` — empty marker (so Obsidian recognizes it)
- `<output>/001_Inbox/`, `010_Outcomes/`, `020_Processes/`, `030_Reference/` — notes
- `<output>/_truth.json` — chaos baseline for test assertions
- (optional) `<output>/_vault-autopilot/config/tag-convention.md` — sample override

## `_truth.json` schema

```json
[
  {
    "file": "001_Inbox/Note 0000.md",
    "original_tag": "devtools",
    "expected_canonical": "DevTools",
    "tier": 1,
    "kind": "lowercase"
  }
]
```

Tests assert: detection completeness ≥ 95% vs `_truth.json`, canonical match ≥ 90%.

## Determinism

Same `--seed` + same flags = byte-identical output.

## Extending

Add new chaos variants by extending `CHAOS_VARIANTS` or `VIOLATIONS` lists in `generate.py`. Add domain templates in `data/body-templates/` (one body per blank-line-separated block).
```

- [ ] **Step 8: Commit**

```bash
git add scripts/test-fixtures/
git commit -m "spec(v0.2.0): synthetic vault generator (T4)

Deterministic Obsidian-shaped vault generator with controlled chaos
injection. Outputs notes, _truth.json baseline, and optional sample
vault-config.

- generate-synthetic-vault.sh: bash entry point
- generate.py: Python helper for randomization + YAML/JSON output
- data/tag-vocabulary.txt: ~80 base tags (Zipfian-weighted at use)
- data/body-templates/: 3 domains (work, research, personal)
- README.md: usage + extension docs

Determinism verified: same seed = byte-identical output.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Create curated chaos-vault fixture

**Files:**
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/.obsidian/.gitkeep`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/case-variants.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/hash-prefix.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/yaml-leak.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/numeric-artifact.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/upper-kebab.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/snake-case.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/clean.md`
- Create: `tests/fixtures/curated/tag-manage/chaos-vault/_vault-autopilot/config/tag-convention.md`

**Goal:** Hand-curated small vault that exercises every Tier 1+2+3 case with specific known-truth assertions. Plan B integration tests run against this.

- [ ] **Step 1: Create the fixture root**

```bash
mkdir -p tests/fixtures/curated/tag-manage/chaos-vault/.obsidian
mkdir -p tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox
mkdir -p tests/fixtures/curated/tag-manage/chaos-vault/010_Outcomes
mkdir -p tests/fixtures/curated/tag-manage/chaos-vault/_vault-autopilot/config
touch tests/fixtures/curated/tag-manage/chaos-vault/.obsidian/.gitkeep
```

- [ ] **Step 2: Write each fixture note**

Write the seven fixture notes with specific tag-chaos exhibits. Each is a complete .md file. Example for `case-variants.md`:

```markdown
---
title: Case Variants
created: 2024-01-15
tags:
  - devtools
  - DevTools
  - Devtools
  - Research
---

# Case Variants

This note carries three case variants of the same tag (Tier 1).
```

Write similar curated notes for: hash-prefix.md (`tags: ["#Websites", Research]`), yaml-leak.md (`tags: ["created: 2026-03-22", Research]`), numeric-artifact.md (`tags: ["1", "2", Research]`), upper-kebab.md (`tags: [App-Development, Software-Development, Research]`), snake-case.md (`tags: [ai_agents, Research]`), clean.md (`tags: [Research, OpenSource]`).

Add a cross-folder check: `010_Outcomes/cross-folder.md` with `tags: [research, OpenSource]` (lowercase variant of `Research` lives in different folder).

- [ ] **Step 3: Write the vault-config override**

Create `tests/fixtures/curated/tag-manage/chaos-vault/_vault-autopilot/config/tag-convention.md`:

```markdown
---
schema: 1
pins:
  - {from: schickhardt-gms, to: Schickhardt-GMS}
  - {from: vfb-stuttgart,   to: VfB-Stuttgart}
---

# Sample vault override

Pins for vault-specific brands.
```

- [ ] **Step 4: Create golden-output for chaos-vault**

Create `tests/fixtures/curated/tag-manage/chaos-vault-golden/` mirroring the same structure but with all canonical fixes applied. (This is the expected post-apply state.) Notes:
- `case-variants.md` tags become `[DevTools, Research]` (3→1)
- `hash-prefix.md` tags become `[Websites, Research]`
- `yaml-leak.md` tags become `[Research]` (the leak removed)
- `numeric-artifact.md` tags become `[Research]`
- `upper-kebab.md` tags become `[AppDevelopment, SoftwareDevelopment, Research]`
- `snake-case.md` tags become `[AIAgents, Research]`
- `clean.md` unchanged
- `cross-folder.md` tags become `[Research, OpenSource]`

- [ ] **Step 5: Commit fixtures**

```bash
git add tests/fixtures/curated/
git commit -m "spec(v0.2.0): curated chaos-vault fixture for tag-manage tests (T4b)

Seven notes covering every Tier 1+2+3 detection case + cross-folder
duplicate. Includes vault-config override (Schickhardt-GMS, VfB-Stuttgart
pins) and golden-output for post-apply assertions.

Used by Plan B integration tests.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: tag-manage SKILL.md skeleton

**Files:**
- Create: `skills/tag-manage/SKILL.md`

**Goal:** Stage-1 "skeleton" — workflow shape with placeholders for logic. advisor()'s "cheap insurance" — validates recipe shape against actual call site before Plan B fills logic.

- [ ] **Step 1: Write the skeleton**

Create `skills/tag-manage/SKILL.md`:

```markdown
---
name: tag-manage
status: skeleton
description: |
  Use when an Obsidian vault has accumulated inconsistent tag spellings — same concept
  written multiple ways — and needs unified to a canonical form. Audits the vault, proposes
  fixes per a naming convention, and applies approved changes.
  Trigger phrases: "audit tags", "fix tags", "tag duplicates", "tag cleanup",
  "find duplicate tags", "tag consistency", "convention violations", "rename tags",
  "tag report", "untangle tags", "tag-Dschungel".
---

# Tag Manage

> **Status: skeleton (v0.2.0 in development).** Workflow shape only — Plan B fills the logic. Do not invoke yet.

Find inconsistent tag spellings across an Obsidian vault, propose canonical forms guided by a naming convention, and apply approved changes after explicit user gate.

## Principle: Core + Nahbereich + Report

- **Core:** Detect Tier 1 case-variants, Tier 2 whitespace/hyphen variants, and Tier 3 convention violations across the scope. Resolve canonicals via AI judgment + vault pins. Apply approved renames/removes.
- **Nahbereich:** Fix tags that are clearly artifacts (YAML-leak rows mistakenly stored as tags, numeric-only tags, hash-prefixed tags) with REMOVE rather than rename — but only as part of an approved recommendation, never silently.
- **Report:** Findings file at `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-manage.md`. Per-run audit + apply ledger with per-file before/after rows.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scope` | `vault` | `inbox` / `inbox-tree` / `vault` / `folder:<path>` |
| `cooldown_days` | 3 | Skip notes created within last N days (Source Hierarchy from `docs/metadata-requirements.md`) |
| `dry_run` | `false` | Audit + display only; no apply |

## Pre-flight

Before every invocation: if running on Windows, follow `references/windows-preflight.md` end-to-end.

## Workflow

1. **Discover & Configure** — resolve `${OBSIDIAN_VAULT_PATH}`. Production-Safety gate. Read `references/tag-convention.md` (plugin default). If `[VAULT]/_vault-autopilot/config/tag-convention.md` exists, parse + merge per `references/vault-config.md` semantics. Confirm scope.
2. **Scan** — walk scope, run `references/yaml-sanity.md` per file, route bad-YAML cases away. Extract tags line-by-line. Apply cooldown.
3. **Detect** — Tier 1 case-variants, Tier 2 whitespace/hyphen normalize, Tier 3 forbidden_patterns + lowercase-concept + snake_case + Upper-Kebab.
4. **Resolve** — single AI prompt (Haiku, temp=0). Inputs: effective convention, vault vocabulary with frequencies, duplicate groups, violations, vault pins. Output: numbered recommendations JSON.
5. **Preview** — chat-display table grouped by severity. Append findings file with `prompt_template_version: "1.0"`.
6. **User Gate** — `apply all` / `apply <range>` / `skip <id>` / `override <id> <canonical>`. Production-Safety bulk-operation confirm before any write.
7. **Apply** — for each approved recommendation: pre-write log to findings, execute via `references/yaml-edits.md` recipe (g) tag-rename or (h) tag-remove, birthtime preservation per `references/skill-log.md`, skill-log callout.
8. **Report** — final chat summary + findings status `apply-complete`.

## Reserved Tags

Never proposed for changes:
- `VaultAutopilot`
- `VaultAutopilot/*`

## Boundaries

- Operates on YAML frontmatter tags only. Inline `#tag` in body is out of scope.
- Does not repair malformed YAML. Routes to property-enrich (recipe f) or note-rename per `references/yaml-sanity.md` verdict.
- Does not handle flow-style tags (`tags: [a, b, c]`). Logs finding, skips file.

## See also

- Spec: `docs/superpowers/specs/2026-05-06-tag-manage-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-plan-b-tag-manage-build.md`
- Sibling skill: `skills/tag-suggest/SKILL.md` (v0.2.x)

## Skill Log Section

(Auto-populated; see `references/skill-log.md`.)
```

- [ ] **Step 2: Verify file exists and YAML frontmatter is parseable**

```bash
test -f skills/tag-manage/SKILL.md
python3 -c "
content = open('skills/tag-manage/SKILL.md').read()
fm = content.split('---', 2)[1]
import yaml
parsed = yaml.safe_load(fm)
assert parsed['name'] == 'tag-manage'
assert parsed['status'] == 'skeleton'
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/tag-manage/SKILL.md
git commit -m "spec(v0.2.0): tag-manage SKILL.md skeleton (T4.5)

Workflow-shape-only skeleton per advisor's cheap-insurance recommendation.
Validates that recipes (g)/(h) shape matches the call sites the skill
will use in Plan B.

Status: skeleton (do not invoke). Plan B fills the logic.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Plan A summary commit and exit

**Files:**
- Modify: `logs/changelog.md` (append entry)

**Goal:** Final foundation entry, summarize what landed.

- [ ] **Step 1: Append to changelog**

Add to `logs/changelog.md` under a new "Unreleased" section:

```markdown
## Unreleased — v0.2.0 Foundations (2026-MM-DD)

- references/tag-convention.md: extended with YAML schema (casing, hierarchy_separator, forbidden_patterns, pins, hierarchy_prefixes, folder_exclusive). Brand handling unified into pins (no separate brands field).
- references/vault-config.md: new — schema spec for [VAULT]/_vault-autopilot/config/ files.
- references/yaml-edits.md: recipes (g) tag-rename and (h) tag-remove appended. Line-by-line, idempotent, all 4 YAML list-item formats.
- scripts/test-fixtures/: synthetic vault generator (bash + Python). Deterministic via --seed.
- scripts/test-recipe-g-tag-rename.sh, test-recipe-h-tag-remove.sh: self-contained test drivers.
- tests/fixtures/curated/tag-manage/chaos-vault/: handcrafted fixture covering every Tier 1+2+3 case + cross-folder duplicate. Vault-config override included.
- tests/fixtures/recipe-g/, recipe-h/: before + golden fixtures for recipe tests.
- skills/tag-manage/SKILL.md: skeleton (status: skeleton, do-not-invoke). Plan B fills logic.

These foundations support tag-manage v0.2.0 (Plan B) and tag-suggest v0.2.x (Plan C).
```

- [ ] **Step 2: Verify all Plan A artifacts present**

```bash
test -f references/tag-convention.md && grep -q '^schema: 1$' references/tag-convention.md
test -f references/vault-config.md
grep -q 'Recipe (g)' references/yaml-edits.md
grep -q 'Recipe (h)' references/yaml-edits.md
test -x scripts/test-recipe-g-tag-rename.sh
test -x scripts/test-recipe-h-tag-remove.sh
test -x scripts/test-fixtures/generate-synthetic-vault.sh
test -x scripts/test-fixtures/generate.py
test -f tests/fixtures/curated/tag-manage/chaos-vault/001_Inbox/case-variants.md
test -f skills/tag-manage/SKILL.md
echo "All Plan A artifacts present."
```

Expected: `All Plan A artifacts present.`

- [ ] **Step 3: Run all recipe tests, expect green**

```bash
./scripts/test-recipe-g-tag-rename.sh
./scripts/test-recipe-h-tag-remove.sh
```

Expected: both exit 0.

- [ ] **Step 4: Final commit**

```bash
git add logs/changelog.md
git commit -m "chore(v0.2.0): Plan A foundations complete — changelog entry

Plan A delivered:
- tag-convention.md schema extension (T1)
- vault-config.md schema spec (T2)
- yaml-edits.md recipes (g) tag-rename + (h) tag-remove with tests (T3)
- synthetic vault generator (T4)
- curated chaos-vault fixture (T4b)
- tag-manage SKILL.md skeleton (T4.5)

Plan B can now begin (tag-manage logic) once Plan A is merged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 5: Push branch + open PR**

```bash
git push origin HEAD
gh pr create --title "v0.2.0 Plan A: Tag-skill foundations" --body "$(cat <<'EOF'
Implements Plan A from `docs/superpowers/plans/2026-05-06-plan-a-foundations.md`.

## What lands
- `references/tag-convention.md` extended with YAML schema (T1)
- `references/vault-config.md` new (T2)
- `references/yaml-edits.md` recipes (g) + (h) with bash tests (T3)
- `scripts/test-fixtures/` synthetic vault generator (T4)
- `tests/fixtures/curated/tag-manage/chaos-vault/` curated fixture (T4b)
- `skills/tag-manage/SKILL.md` skeleton (T4.5)

## Tests
- `./scripts/test-recipe-g-tag-rename.sh` — green
- `./scripts/test-recipe-h-tag-remove.sh` — green
- `./scripts/test-fixtures/generate-synthetic-vault.sh --output /tmp/sv --notes 20 --seed 42` — deterministic

## Why
Foundation for tag-manage v0.2.0 and tag-suggest v0.2.x. See spec: `docs/superpowers/specs/2026-05-06-tag-manage-design.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR created. Reviewer (MASCHIN or User) approves before merge to main.

---

## Plan A Self-Review Checklist

After completing all tasks, verify:

- [ ] All 8 spec items from §13.2 Stage 1 (T1–T4.5) covered:
  - T1 ✓ Task 1
  - T2 ✓ Task 2
  - T3 ✓ Tasks 3 + 4
  - T4 ✓ Tasks 5 + 6
  - T4.5 ✓ Task 7
- [ ] No "TBD"/"TODO"/"implement later" placeholders
- [ ] Recipe (g) and (h) function names consistent across SKILL.md, recipe doc, and test scripts
- [ ] Vault-config path `[VAULT]/_vault-autopilot/config/` consistent everywhere
- [ ] All test scripts exit 0 on green path; fail loudly on red
- [ ] Synthetic generator deterministic verified
- [ ] All commits have Co-Authored-By footer
- [ ] PR opened against main, awaiting review

If any item fails: fix inline, re-run, re-commit.
