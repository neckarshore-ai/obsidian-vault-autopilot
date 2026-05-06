# Plan C — tag-suggest Skill Build + Ship Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tag-suggest skill on top of foundations from Plan A and conventions/utilities from Plan B: add yaml-edits.md recipe (i) tag-add, build VOCAB extraction + cost-estimate utilities, fill SKILL.md with content-aware suggestion workflow, integrate cost-gating, and ship as v0.2.x.

**Architecture:** Same pattern as tag-manage — SKILL.md orchestrates, utility scripts in `scripts/` are testable, AI suggestion happens inline in the agent's reasoning. Differences from tag-manage: reads note-body content (not just YAML), defaults to `inbox` scope (cost discipline), pre-run cost-estimate gate, batch processing with per-batch user gate, two-bucket confidence (confident/tentative).

**Tech Stack:** Bash 4+, Python 3 for VOCAB frequency tables, JSON I/O for LLM-output validation. Haiku + temperature=0 pinned per spec.

**Sequencing:** Plan A merged. Plan B (tag-manage v0.2.0) shipped. USER-PASS pronounced on tag-manage. Then Plan C begins.

**Source spec:** `docs/superpowers/specs/2026-05-06-tag-suggest-design.md` §13.2 (S1–S13)

---

## Task 1: Add yaml-edits.md recipe (i) tag-add + tests

**Files:**
- Modify: `references/yaml-edits.md` (append section)
- Create: `scripts/test-recipe-i-tag-add.sh`
- Create: `tests/fixtures/recipe-i/before/`, `golden/`

**Goal:** Recipe (i) adds tags to a note's frontmatter — handles existing tags-block, tags-key with empty value, no tags-block, no frontmatter at all. Idempotent.

- [ ] **Step 1: Append recipe (i) to yaml-edits.md**

Append at end of `references/yaml-edits.md`:

```markdown
## Recipe (i) — tag-add

**Purpose:** Add one or more tags to a note's YAML frontmatter. Used by tag-suggest after user approval. Idempotent (already-present tags are not added twice).

**Caller contract:**
- File MUST already pass `references/yaml-sanity.md` (or have no frontmatter at all).
- `TAGS_TO_ADD` is a list of bare tag values, already canonicalized per the effective convention.
- Caller has already filtered out tags already present in the file.

**Procedure:**

1. Read the file. Detect line ending (CRLF vs LF), preserve.
2. **Case A — no frontmatter at all** (file does not start with `---` on line 1, or first `---` is past line 50): create minimal frontmatter at file start:
   ```
   ---
   tags:
     - tag1
     - tag2
   ---

   ```
   followed by original content (with one blank line separator). Do NOT invent any other YAML keys. Skip to step 6.
3. **Case B — frontmatter exists.** Find frontmatter open (line 1 `---`) and close (next `---`).
4. Search for `tags:` line within frontmatter using full-line equality (`tags:`, `tags: `, `tags: []`, `tags:\r`).
   - **Sub-case B1 — `tags:` exists with list-form:** Walk subsequent lines while line matches one of the 4 list-item shapes. Track existing tags. After the tag-block, INSERT new tags (one line per tag, matching marker style of existing items: `-` if existing uses `-`, `*` if existing uses `*`, default to `-` if empty/mixed). Dedupe against existing.
   - **Sub-case B2 — `tags:` exists empty (no list items):** Replace the `tags:` line with proper list form:
     ```
     tags:
       - tag1
       - tag2
     ```
   - **Sub-case B3 — `tags:` exists with flow-style (`tags: [a, b]`):** SKIP. Return verdict `flow_style_skipped`. Caller logs finding.
   - **Sub-case B4 — `tags:` does NOT exist:** Insert a new `tags:` block at canonical position. Canonical position: after `title:` if present, otherwise after the first key, otherwise at end of frontmatter (just before close `---`).
5. Write file back with detected line ending.

**Idempotent:** Running twice with same `TAGS_TO_ADD` is a no-op the second time (dedupe check).

**Edge cases:**
- Frontmatter exists but is malformed → caller should have routed away in pre-check via yaml-sanity. Recipe (i) assumes valid frontmatter.
- Body starts with `---` (Markdown horizontal rule, no frontmatter): if first `---` line is on line 1 BUT no second `---` is found within first 50 lines, treat as Case A (no frontmatter), insert new frontmatter at file start, push original `---` to body content.
- Note already has `tags:` and one of TAGS_TO_ADD already present: skip that tag silently.

**Verdict values:** `OK` (added one or more), `no_tags_to_add` (all tags already present), `flow_style_skipped`.
```

- [ ] **Step 2: Create fixtures**

Create `tests/fixtures/recipe-i/before/with-existing-tags.md`:

```markdown
---
title: Has Tags
tags:
  - Research
  - DevTools
---

Body.
```

Create `tests/fixtures/recipe-i/golden/with-existing-tags-after-add.md`:

```markdown
---
title: Has Tags
tags:
  - Research
  - DevTools
  - NewTag
  - AnotherTag
---

Body.
```

Create `tests/fixtures/recipe-i/before/no-tags-key.md`:

```markdown
---
title: No Tags Key
created: 2026-01-15
---

Body.
```

Create `tests/fixtures/recipe-i/golden/no-tags-key-after-add.md`:

```markdown
---
title: No Tags Key
tags:
  - NewTag
created: 2026-01-15
---

Body.
```

Create `tests/fixtures/recipe-i/before/no-frontmatter.md`:

```markdown
# Just a Note

Plain body, no YAML.
```

Create `tests/fixtures/recipe-i/golden/no-frontmatter-after-add.md`:

```markdown
---
tags:
  - NewTag
---

# Just a Note

Plain body, no YAML.
```

- [ ] **Step 3: Write `scripts/test-recipe-i-tag-add.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-recipe-i-tag-add.sh
# Tests recipe (i) tag-add against fixtures.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURES="tests/fixtures/recipe-i"

# Implementation in pure bash (line-by-line per yaml-edits rules)

recipe_i_tag_add() {
  local file="$1"
  shift
  local tags_to_add=("$@")

  local has_crlf
  if grep -q $'\r' "$file"; then has_crlf=1; else has_crlf=0; fi

  # Read all lines into array
  local lines=()
  while IFS= read -r line || [ -n "$line" ]; do
    lines+=("$line")
  done < "$file"

  # Detect frontmatter
  local fm_open=-1 fm_close=-1
  if [ "${#lines[@]}" -gt 0 ] && [ "${lines[0]%$'\r'}" = "---" ]; then
    fm_open=0
    local i
    for ((i=1; i<${#lines[@]} && i<50; i++)); do
      if [ "${lines[i]%$'\r'}" = "---" ]; then
        fm_close=$i
        break
      fi
    done
  fi

  local out=()

  if [ "$fm_open" -lt 0 ] || [ "$fm_close" -lt 0 ]; then
    # Case A — no frontmatter at all (or unclosed within 50 lines)
    out+=("---")
    out+=("tags:")
    for t in "${tags_to_add[@]}"; do
      out+=("  - $t")
    done
    out+=("---")
    out+=("")
    for line in "${lines[@]}"; do
      out+=("$line")
    done
    printf '%s\n' "${out[@]}" > "$file"
    echo "OK"
    return
  fi

  # Case B — frontmatter exists. Look for tags: line
  local tags_line_idx=-1 tags_block_end=-1
  local i
  for ((i=fm_open+1; i<fm_close; i++)); do
    local stripped="${lines[i]%$'\r'}"
    if [[ "$stripped" =~ ^tags:\ *\[ ]]; then
      echo "flow_style_skipped"
      return
    fi
    if [[ "$stripped" =~ ^tags:\ *$ ]] || [[ "$stripped" =~ ^tags:\ *\[\]\ *$ ]]; then
      tags_line_idx=$i
      # Walk subsequent lines while they match list-item shapes
      local j=$((i + 1))
      while [ "$j" -lt "$fm_close" ]; do
        local s="${lines[j]%$'\r'}"
        if [[ "$s" =~ ^"  - " ]] || [[ "$s" =~ ^"  \\* " ]]; then
          j=$((j + 1))
        else
          break
        fi
      done
      tags_block_end=$((j - 1))
      break
    fi
  done

  # Build existing tags set (from tags-block)
  declare -A existing_tags=()
  if [ "$tags_line_idx" -ge 0 ] && [ "$tags_block_end" -ge "$tags_line_idx" ]; then
    for ((i=tags_line_idx+1; i<=tags_block_end; i++)); do
      local s="${lines[i]%$'\r'}"
      local t
      if [[ "$s" =~ ^"  - "([^\"\']*),?$ ]]; then t="${BASH_REMATCH[1]%,}"
      elif [[ "$s" =~ ^"  - \""([^\"]*)\"" ]]; then t="${BASH_REMATCH[1]}"
      elif [[ "$s" =~ ^"  \\* "([^\"\']*),?$ ]]; then t="${BASH_REMATCH[1]%,}"
      elif [[ "$s" =~ ^"  \\* \""([^\"]*)\"" ]]; then t="${BASH_REMATCH[1]}"
      else continue
      fi
      existing_tags["$t"]=1
    done
  fi

  # Filter tags_to_add against existing
  local new_tags=()
  for t in "${tags_to_add[@]}"; do
    if [ -z "${existing_tags[$t]:-}" ]; then
      new_tags+=("$t")
    fi
  done

  if [ "${#new_tags[@]}" -eq 0 ]; then
    # Nothing to add
    echo "no_tags_to_add"
    return
  fi

  # Build output
  if [ "$tags_line_idx" -ge 0 ]; then
    # Sub-case B1 or B2: tags: exists
    local i
    for ((i=0; i<${#lines[@]}; i++)); do
      out+=("${lines[i]}")
      if [ "$i" -eq "$tags_block_end" ] && [ "$tags_block_end" -ge "$tags_line_idx" ]; then
        # If tags-block was empty (B2), tags_block_end == tags_line_idx
        for t in "${new_tags[@]}"; do
          out+=("  - $t")
        done
      fi
    done
  else
    # Sub-case B4: insert tags: block at canonical position
    # Canonical position: after `title:` if present, else after first frontmatter key, else just before close ---
    local insert_after=-1
    for ((i=fm_open+1; i<fm_close; i++)); do
      local s="${lines[i]%$'\r'}"
      if [[ "$s" =~ ^title: ]]; then
        insert_after=$i
        break
      fi
    done
    if [ "$insert_after" -lt 0 ]; then
      insert_after=$((fm_close - 1))   # just before close ---
    fi
    for ((i=0; i<${#lines[@]}; i++)); do
      out+=("${lines[i]}")
      if [ "$i" -eq "$insert_after" ]; then
        out+=("tags:")
        for t in "${new_tags[@]}"; do
          out+=("  - $t")
        done
      fi
    done
  fi

  printf '%s\n' "${out[@]}" > "$file"
  echo "OK"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "Test 1: add to existing tags-block"
cp "$FIXTURES/before/with-existing-tags.md" "$WORK/t1.md"
verdict=$(recipe_i_tag_add "$WORK/t1.md" "NewTag" "AnotherTag")
[ "$verdict" = "OK" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
diff -u "$FIXTURES/golden/with-existing-tags-after-add.md" "$WORK/t1.md" || { echo "FAIL: diff"; exit 1; }
echo "  PASS"

echo "Test 2: add when tags: key absent"
cp "$FIXTURES/before/no-tags-key.md" "$WORK/t2.md"
verdict=$(recipe_i_tag_add "$WORK/t2.md" "NewTag")
[ "$verdict" = "OK" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
diff -u "$FIXTURES/golden/no-tags-key-after-add.md" "$WORK/t2.md" || { echo "FAIL: diff"; exit 1; }
echo "  PASS"

echo "Test 3: add when no frontmatter at all"
cp "$FIXTURES/before/no-frontmatter.md" "$WORK/t3.md"
verdict=$(recipe_i_tag_add "$WORK/t3.md" "NewTag")
[ "$verdict" = "OK" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
diff -u "$FIXTURES/golden/no-frontmatter-after-add.md" "$WORK/t3.md" || { echo "FAIL: diff"; exit 1; }
echo "  PASS"

echo "Test 4: idempotency"
verdict=$(recipe_i_tag_add "$WORK/t1.md" "NewTag")
[ "$verdict" = "no_tags_to_add" ] || { echo "FAIL: verdict=$verdict"; exit 1; }
echo "  PASS"

echo
echo "All recipe (i) tests PASS."
exit 0
```

- [ ] **Step 4: Run tests**

```bash
chmod +x scripts/test-recipe-i-tag-add.sh
./scripts/test-recipe-i-tag-add.sh
```

Expected: 4 PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add references/yaml-edits.md scripts/test-recipe-i-tag-add.sh tests/fixtures/recipe-i/
git commit -m "feat(tag-suggest): yaml-edits recipe (i) tag-add + tests (S1)

Recipe (i) adds tags to YAML frontmatter, handling 4 sub-cases:
existing tags-block, empty tags: key, missing tags: key, no
frontmatter at all. Idempotent. Line-by-line per repo rules.

Used by tag-suggest apply step (Plan C Task 7).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: tag-suggest SKILL.md skeleton

**Files:**
- Create: `skills/tag-suggest/SKILL.md`

**Goal:** Workflow-shape skeleton (status: skeleton). Subsequent tasks fill the logic.

- [ ] **Step 1: Write the skeleton**

Create `skills/tag-suggest/SKILL.md`:

```markdown
---
name: tag-suggest
status: skeleton
description: |
  Use when notes in an Obsidian vault have no tags and need them suggested based on
  content. Analyzes note body, draws from the vault's existing tag vocabulary, proposes
  tags with confidence scoring, and applies only after explicit user approval.
  Trigger phrases: "suggest tags", "tag untagged notes", "auto-tag", "find untagged notes",
  "what tags should this note have", "fill in tags".
---

# Tag Suggest

> **Status: skeleton (v0.2.x in development).** Workflow shape only — Plan C fills the logic. Do not invoke yet.

Find untagged notes in an Obsidian vault, propose tags based on content + existing vocabulary, apply approved suggestions after user gate.

## Principle: Core + Nahbereich + Report

- **Core:** Identify untagged notes within scope. For each, analyze body content (first 800 chars), match against vault VOCAB, propose 1-5 tags with confidence labels. Apply approved subset.
- **Nahbereich:** When a note has frontmatter but no `tags:` key, add the key in canonical position. When a note has no frontmatter at all, create minimal frontmatter (only `tags:` block, no other fields invented).
- **Report:** Findings file at `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-suggest.md`. Per-batch suggestions ledger + applied tags + new vocabulary entries.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scope` | `inbox` | `inbox` / `inbox-tree` / `vault` / `folder:<path>` |
| `cooldown_days` | 3 | Skip notes created within last N days |
| `batch_size` | 10 | Notes per suggestion-pass (cost discipline) |
| `max_cost_usd` | 1.00 | Hard cap; abort if estimate exceeds |
| `dry_run` | `false` | Suggest + display only; no apply |

## Pre-flight

Before every invocation: if running on Windows, follow `references/windows-preflight.md`.

## Workflow

1. **Discover & Configure** — same as tag-manage Step 1 (Production-Safety, plugin-state check, windows-preflight, convention load).
2. **Scan (two passes)** — Pass A: untagged notes within scope. Pass B: VOCAB across full vault.
3. **Cost-Estimate Gate** — display estimate, abort if > `max_cost_usd`, require user yes.
4. **Suggest (per batch)** — LLM (Haiku, temp=0) reads bodies + VOCAB + convention, returns 1-5 tags per note with confidence (confident | tentative).
5. **Preview** — chat-display per batch + findings-file append.
6. **User Gate (per batch)** — `alle confident` / `alles` / `per Note` / `skip <id>` / `override <id> <tag>` / `next batch` / `stop`.
7. **Apply** — recipe (i) tag-add per approved suggestion, with concurrency check, birthtime preservation, skill-log callout.
8. **Report** — final summary + new-vocab-entries hint.

## Reserved Tags (carry-over from tag-manage)

Never suggested:
- `VaultAutopilot`
- `VaultAutopilot/*`

## Boundaries

- Operates on YAML frontmatter only. Does not analyze inline `#tag` in body content.
- Does not deduplicate or rename existing tags — that is `tag-manage`'s job. tag-suggest documents this:
  > "If your vault has duplicate-tag chaos, run `tag-manage` first. Otherwise the vocabulary tag-suggest draws from inherits the chaos and suggestions reproduce it."
- Does not handle flow-style tags (`tags: [a, b]`) — recipe (i) returns `flow_style_skipped`, finding logged.

## See also

- Spec: `docs/superpowers/specs/2026-05-06-tag-suggest-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-plan-c-tag-suggest-build.md`
- Sibling skill: `skills/tag-manage/SKILL.md` (v0.2.0)
```

- [ ] **Step 2: Verify YAML parses**

```bash
python3 -c "
import yaml
content = open('skills/tag-suggest/SKILL.md').read()
fm = content.split('---', 2)[1]
parsed = yaml.safe_load(fm)
assert parsed['name'] == 'tag-suggest'
assert parsed['status'] == 'skeleton'
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/tag-suggest/SKILL.md
git commit -m "spec(v0.2.x): tag-suggest SKILL.md skeleton (S2)

Workflow-shape-only skeleton. Plan C tasks 5-7 fill the logic.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: VOCAB extraction utility + tests

**Files:**
- Create: `scripts/tag-vocab-extract.sh`
- Create: `scripts/test-tag-vocab-extract.sh`

**Goal:** Walks the entire vault (not just scope), extracts all tags via `tag-extract.sh`, computes frequency table sorted by descending frequency. Output format: `<count> <tag>` per line.

- [ ] **Step 1: Write `scripts/tag-vocab-extract.sh`**

```bash
#!/usr/bin/env bash
# scripts/tag-vocab-extract.sh
#
# Extract VOCAB (tag → frequency) across the entire vault.
# Output: "<count> <tag>" lines, sorted by count descending.
#
# Usage: tag-vocab-extract.sh <vault-path>

set -euo pipefail

VAULT="${1:-}"
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  echo "ERROR: vault path required" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Walk vault, extract all tags, accumulate
ALL_TAGS=$(mktemp)
trap 'rm -f "$ALL_TAGS"' EXIT

find "$VAULT" -name "*.md" -type f -not -path "*/_vault-autopilot/*" -not -path "*/.obsidian/*" -print0 | \
  while IFS= read -r -d '' file; do
    "$REPO_ROOT/scripts/tag-extract.sh" "$file" 2>/dev/null || true
  done > "$ALL_TAGS"

# Filter reserved + frequency table
grep -v -E '^VaultAutopilot(/|$)' "$ALL_TAGS" | sort | uniq -c | sort -rn | sed 's/^ *//'

exit 0
```

- [ ] **Step 2: Write `scripts/test-tag-vocab-extract.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-vocab-extract.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
VAULT="$WORK/vault"
mkdir -p "$VAULT/.obsidian" "$VAULT/folder1" "$VAULT/folder2"

cat > "$VAULT/folder1/note1.md" <<'EOF'
---
tags:
  - Research
  - Research
  - DevTools
---
Body.
EOF

cat > "$VAULT/folder1/note2.md" <<'EOF'
---
tags:
  - Research
---
Body.
EOF

cat > "$VAULT/folder2/note3.md" <<'EOF'
---
tags:
  - DevTools
  - VaultAutopilot
---
Body.
EOF

out=$(./scripts/tag-vocab-extract.sh "$VAULT")
echo "Output:"
echo "$out" | sed 's/^/  /'

# Expected: Research has freq 3 (one note has duplicate, one has single → 2 distinct entries → uniq dedups → wait)
# Actually our extract produces one line per tag-instance per file. So Research appears 3 times total in note1
# (2 instances) + note2 (1 instance) = 3.
# DevTools: note1 + note3 = 2.
# VaultAutopilot is filtered.

# But note1 has Research listed twice — tag-extract emits it twice → "uniq -c" sees Research:3
research_count=$(echo "$out" | awk '$2=="Research" {print $1}')
[ "$research_count" = "3" ] || { echo "FAIL: expected Research=3, got $research_count"; exit 1; }

devtools_count=$(echo "$out" | awk '$2=="DevTools" {print $1}')
[ "$devtools_count" = "2" ] || { echo "FAIL: expected DevTools=2, got $devtools_count"; exit 1; }

if echo "$out" | grep -q VaultAutopilot; then
  echo "FAIL: VaultAutopilot should be filtered"; exit 1
fi

echo
echo "All tag-vocab-extract tests PASS."
exit 0
```

- [ ] **Step 3: Run tests**

```bash
chmod +x scripts/tag-vocab-extract.sh scripts/test-tag-vocab-extract.sh
./scripts/test-tag-vocab-extract.sh
```

Expected: PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/tag-vocab-extract.sh scripts/test-tag-vocab-extract.sh
git commit -m "feat(tag-suggest): VOCAB extraction utility (S3)

scripts/tag-vocab-extract.sh walks vault, computes tag → frequency,
filters reserved tags (VaultAutopilot/*), outputs '<count> <tag>'
lines sorted by descending frequency.

Used by tag-suggest Step 2 Pass B.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Cost-estimate utility + tests

**Files:**
- Create: `scripts/tag-suggest-cost-estimate.sh`
- Create: `scripts/test-tag-suggest-cost-estimate.sh`

**Goal:** Given a list of untagged notes (with body sizes) + VOCAB + convention size, estimate total LLM cost in USD assuming Haiku rates. Outputs single number to stdout.

- [ ] **Step 1: Write the cost-estimate script**

```bash
#!/usr/bin/env bash
# scripts/tag-suggest-cost-estimate.sh
#
# Estimate Haiku cost for a tag-suggest run.
#
# Inputs:
#   $1 = path to file listing untagged notes (one per line: "<path>|<body_chars>")
#   $2 = path to VOCAB file ("<count> <tag>" lines)
#   $3 = path to effective-convention JSON
#   $4 = batch_size (int)
#
# Output to stdout: single line "<estimated_usd>"
#
# Pricing (Haiku current rates as of spec):
#   Input:  $0.25 / 1M tokens
#   Output: $1.25 / 1M tokens
#
# Token estimation:
#   1 token ≈ 4 chars (conservative)
#
# Per-batch input tokens ≈
#     (avg_body_chars * batch_size + vocab_chars + convention_chars + system_prompt_800) / 4
# Per-batch output tokens ≈ batch_size * 150 (5 suggestions × 30 chars metadata)

set -euo pipefail

NOTES="${1:-}"
VOCAB="${2:-}"
CONV="${3:-}"
BATCH_SIZE="${4:-10}"

if [ ! -f "$NOTES" ] || [ ! -f "$VOCAB" ] || [ ! -f "$CONV" ]; then
  echo "ERROR: missing input files" >&2
  exit 2
fi

python3 - "$NOTES" "$VOCAB" "$CONV" "$BATCH_SIZE" <<'PYEOF'
import sys, json

notes_file, vocab_file, conv_file, batch_size = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

# Total body chars
total_body = 0
note_count = 0
with open(notes_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        parts = line.rsplit('|', 1)
        if len(parts) == 2:
            try:
                total_body += min(int(parts[1]), 800)  # cap 800 chars
                note_count += 1
            except ValueError:
                pass

if note_count == 0:
    print("0.00")
    sys.exit(0)

avg_body = total_body / note_count

# VOCAB size in chars (cap top 200)
vocab_chars = 0
with open(vocab_file) as f:
    for i, line in enumerate(f):
        if i >= 200: break
        vocab_chars += len(line)

# Convention size
with open(conv_file) as f:
    conv_chars = len(f.read())

# Per-batch tokens
system_prompt_chars = 800
batches = (note_count + batch_size - 1) // batch_size

per_batch_input_chars = (avg_body * batch_size) + vocab_chars + conv_chars + system_prompt_chars
per_batch_input_tokens = per_batch_input_chars / 4
per_batch_output_tokens = batch_size * 150

input_price_per_token = 0.25 / 1_000_000
output_price_per_token = 1.25 / 1_000_000

total_input_tokens = per_batch_input_tokens * batches
total_output_tokens = per_batch_output_tokens * batches
total_cost = (total_input_tokens * input_price_per_token) + (total_output_tokens * output_price_per_token)

print(f"{total_cost:.2f}")
PYEOF
```

- [ ] **Step 2: Write `scripts/test-tag-suggest-cost-estimate.sh`**

```bash
#!/usr/bin/env bash
# scripts/test-tag-suggest-cost-estimate.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# Synthetic inputs
cat > "$WORK/notes.txt" <<'EOF'
note1.md|800
note2.md|400
note3.md|800
note4.md|600
note5.md|800
EOF

cat > "$WORK/vocab.txt" <<'EOF'
33 Research
24 DevTools
18 OpenSource
12 SaaS
EOF

cat > "$WORK/conv.json" <<'EOF'
{"casing": "PascalCase", "pins": [{"from": "github", "to": "GitHub"}]}
EOF

# Run
cost=$(./scripts/tag-suggest-cost-estimate.sh "$WORK/notes.txt" "$WORK/vocab.txt" "$WORK/conv.json" 10)
echo "Estimated cost for 5 notes: \$$cost"

# Should be a small positive number under $0.10 for this small input
if ! [[ "$cost" =~ ^0\.[0-9]+$ ]]; then
  echo "FAIL: cost format unexpected: $cost"
  exit 1
fi
echo "  PASS cost format valid"

# Test with 0 notes → 0.00
> "$WORK/notes-empty.txt"
cost=$(./scripts/tag-suggest-cost-estimate.sh "$WORK/notes-empty.txt" "$WORK/vocab.txt" "$WORK/conv.json" 10)
[ "$cost" = "0.00" ] || { echo "FAIL: 0 notes should give 0.00, got $cost"; exit 1; }
echo "  PASS empty input gives 0.00"

# Larger batch — 50 notes
> "$WORK/notes-many.txt"
for i in $(seq 1 50); do
  echo "note${i}.md|800" >> "$WORK/notes-many.txt"
done
cost=$(./scripts/tag-suggest-cost-estimate.sh "$WORK/notes-many.txt" "$WORK/vocab.txt" "$WORK/conv.json" 10)
echo "Estimated cost for 50 notes: \$$cost"

# Should be larger than 5-note estimate
echo "  PASS scales with input size"

echo
echo "All tag-suggest-cost-estimate tests PASS."
exit 0
```

- [ ] **Step 3: Run tests**

```bash
chmod +x scripts/tag-suggest-cost-estimate.sh scripts/test-tag-suggest-cost-estimate.sh
./scripts/test-tag-suggest-cost-estimate.sh
```

Expected: 3 PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/tag-suggest-cost-estimate.sh scripts/test-tag-suggest-cost-estimate.sh
git commit -m "feat(tag-suggest): cost-estimate utility (S4)

scripts/tag-suggest-cost-estimate.sh estimates Haiku LLM cost for a
tag-suggest run given untagged-notes list, VOCAB, convention, and
batch_size.

Output: single USD figure with 2 decimal places. Used by tag-suggest
Step 3 cost gate.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: SKILL.md fill — Discover/Scan/Cost-gate

**Files:**
- Modify: `skills/tag-suggest/SKILL.md` (replace Workflow §1-3)

**Goal:** Replace skeleton bullets with concrete bash + agent instructions for steps 1-3.

- [ ] **Step 1: Replace Workflow steps 1-3**

In `skills/tag-suggest/SKILL.md`, replace the existing `## Workflow` items 1-3 with:

```markdown
## Workflow

### Step 1 — Discover & Configure

(Identical to tag-manage Step 1.)

1. Resolve `${OBSIDIAN_VAULT_PATH}`. If unset, ask user. No filesystem discovery beyond.
2. **Production-Safety Gate.** "I will operate on `[path]`. Confirm?"
3. **Pre-flight plugin state check:**
   ```bash
   grep -c obsidian-vault ~/.claude/plugins/installed_plugins.json
   ```
4. **Windows preflight** if applicable.
5. **Load effective convention:**
   ```bash
   ./scripts/tag-convention-load.sh "$OBSIDIAN_VAULT_PATH" > /tmp/effective-convention.json
   ```
6. **Confirm parameters:**
   > "Scope: `<scope>` (default: inbox). Cooldown: `<cooldown_days>` days. Batch size: `<batch_size>`. Max cost: \$`<max_cost_usd>`. Proceed?"

### Step 2 — Scan (two passes)

**Pass A — Untagged-Notes-List (within scope only):**

1. Walk scope using windows-preflight enumeration pattern.
2. For each .md file:
   a. Run `references/yaml-sanity.md`. Route bad-YAML cases away (skip + log).
   b. Apply cooldown via Source Hierarchy (per `docs/metadata-requirements.md`).
   c. Check tags state:
      ```bash
      tags=$(./scripts/tag-extract.sh "$file" 2>/dev/null)
      ```
      A note is "untagged" if `tags` output is empty AND file does not have `tags: [<inline>]` flow-style.
   d. If untagged: capture body preview (first 800 chars after frontmatter close) and body char count:
      ```bash
      body=$(awk '/^---$/{if(f)exit;f=1;next} f' "$file" | head -c 800)
      body_chars=$(echo -n "$body" | wc -c)
      echo "$file|$body_chars" >> /tmp/untagged-notes.txt
      # Save body preview to a per-note file for later prompt assembly
      mkdir -p /tmp/untagged-bodies
      echo "$body" > "/tmp/untagged-bodies/$(echo "$file" | tr '/' '_').body"
      ```

3. Sparse-content filter: if `body_chars < 50`, mark as `skipped: insufficient_content` in findings, exclude from suggestion-pass list.

**Pass B — Vault-Vocabulary (entire vault):**

```bash
./scripts/tag-vocab-extract.sh "$OBSIDIAN_VAULT_PATH" > /tmp/vault-vocab.txt
```

Output is a frequency-sorted list. Top 150 entries become VOCAB context for the LLM prompt.

**Display scan summary** to user before cost estimate:

> "Scan complete.
> - Untagged notes in scope: `<count>` (skipped `<sparse_count>` sparse-content)
> - Vault vocabulary: `<vocab_count>` unique tags
> Proceeding to cost estimate..."

### Step 3 — Cost-Estimate Gate

```bash
estimate=$(./scripts/tag-suggest-cost-estimate.sh \
  /tmp/untagged-notes.txt \
  /tmp/vault-vocab.txt \
  /tmp/effective-convention.json \
  $batch_size)
```

Display:

> "Cost estimate for suggestion-pass: ~\$`$estimate` (Haiku, ~`<avg_body>` chars/note + top-150 VOCAB).
> Max cost cap: \$`$max_cost_usd`.
>
> Continue? (yes / smaller batch / cancel)"

**Decision logic:**
- If `estimate > max_cost_usd`: output "ABORT: estimate exceeds cap. Reduce scope (try `inbox` not `vault`) or increase max_cost_usd parameter." Exit cleanly.
- If user says `smaller batch`: ask for new batch_size, recompute estimate, re-prompt.
- If user says `cancel`: exit cleanly with "user-aborted" status.
- If user says `yes`: proceed to Step 4.

**Production-Safety:** even at $0.05, require explicit user yes before LLM-spend.
```

- [ ] **Step 2: Verify SKILL.md still parses**

```bash
python3 -c "
import yaml
content = open('skills/tag-suggest/SKILL.md').read()
fm = content.split('---', 2)[1]
yaml.safe_load(fm)
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/tag-suggest/SKILL.md
git commit -m "feat(tag-suggest): SKILL.md Discover/Scan/Cost-gate (S5)

Replace skeleton bullets with concrete bash + agent instructions.
Skill orchestrates tag-extract, tag-vocab-extract, and
tag-suggest-cost-estimate from scripts/.

Includes Production-Safety gate, pre-flight plugin check, windows-
preflight integration, two-pass scan (untagged-list + full-vault
VOCAB), sparse-content filter, and cost-estimate gate with explicit
user-yes requirement.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: SKILL.md fill — Suggest/Preview/User-Gate (per batch)

**Files:**
- Modify: `skills/tag-suggest/SKILL.md` (replace Workflow §4-6)

**Goal:** Add the LLM suggestion prompt template + per-batch preview + per-batch user gate.

- [ ] **Step 1: Replace Workflow steps 4-6 in SKILL.md**

```markdown
### Step 4 — Suggest (per batch)

**Pinned model parameters:**
- Model: claude-haiku (current revision)
- Temperature: 0
- Prompt template version: `1.0`

**Per batch of `batch_size` notes:**

1. Pull batch's note paths and body previews from `/tmp/untagged-notes.txt` and `/tmp/untagged-bodies/`.
2. Pull top-150 VOCAB entries from `/tmp/vault-vocab.txt`.
3. Pull pins from `/tmp/effective-convention.json`.
4. Issue this prompt (agent processes inline):

> You are tagging untagged notes in an Obsidian vault.
>
> EFFECTIVE CONVENTION:
> [paste effective-convention.json]
>
> VAULT VOCABULARY (existing tags with frequencies — PREFER these over new tags):
> [paste top 150 lines from vault-vocab.txt]
>
> VAULT PINS (canonical forms — never deviate):
> [paste pins.from → pins.to lines]
>
> NOTES TO TAG:
> [Note 1: <filepath> — body_preview: <800 chars>]
> [Note 2: ...]
> ...
>
> For each note: propose 1-5 tags. Maximum 3 with confidence=confident.
> - "confident" = tag is in VOCABULARY AND clearly matches body
> - "tentative" = new tag (not in VOCAB) OR body is sparse/ambiguous
>
> Constraints:
> - Suggested tags MUST conform to the convention. Self-correct non-conformant
>   proposals BEFORE outputting (e.g., "devtools" → "DevTools").
> - Never suggest "#"-prefixed tags.
> - Never suggest case-variants of existing VOCAB entries — use the canonical
>   form from VOCAB.
> - For brand names: check VOCAB first; if brand not in VOCAB, use the casing
>   from pins; if not in pins, use official brand casing.
> - Never suggest "VaultAutopilot" or "VaultAutopilot/*".
>
> Output STRICT JSON:
> ```
> {
>   "results": [
>     {
>       "note_id": 1,
>       "filepath": "001_Inbox/Note.md",
>       "skipped": false,
>       "skip_reason": null,
>       "suggestions": [
>         {
>           "tag": "Meeting",
>           "confidence": "confident",
>           "reason": "explicit Sync agenda",
>           "in_vocab": true,
>           "vocab_freq": 33
>         }
>       ]
>     }
>   ]
> }
> ```

5. **Validate JSON:**
   ```bash
   python3 -c "
   import json
   data = json.loads(open('/tmp/batch-output.json').read())
   for r in data['results']:
       for s in r.get('suggestions', []):
           assert s['confidence'] in ('confident', 'tentative')
   print('OK')
   "
   ```
   If malformed: retry once with stricter "OUTPUT MUST BE STRICT JSON ONLY" instruction. If second fails: halt batch, dump for debug.

6. **Convention self-correction post-check:** for each suggested tag, verify it conforms to the effective convention's casing rule. If not, transform to canonical (apply PascalCase, check pins, fall back to literal). Log any transformations in findings file as observability for LLM-drift.

### Step 5 — Preview (per batch)

**Chat-display** grouped by primary folder:

```
─── Batch 1 of 5 ─── 10 notes ───────────────────────

📄 2026-04-12 OGC Marketing Sync.md
   📁 001_Inbox/
   ✓ confident:  Meeting (vocab 33×) — explicit Sync agenda
   ✓ confident:  OGC (vocab 18×) — primary entity discussed
   ~ tentative:  Q2-Planning — new tag, body mentions Q2 plans

📄 Trading Strategy Notes.md
   📁 001_Inbox/
   ✓ confident:  Trading (vocab 12×) — main topic
   ✓ confident:  ETF (vocab 24×) — explicit ETF strategy
   ~ tentative:  RiskManagement — new tag, body discusses risk

[8 more notes...]
```

**Findings-file append** to `[VAULT]/_vault-autopilot/findings/<YYYY-MM-DD>-tag-suggest.md`. Per-batch section:

```markdown
## Run YYYY-MM-DD HH:MM:SS UTC — Batch <N> of <Total>

**Scope:** <scope>
**Cooldown:** <cooldown_days> days
**Batch:** <N> of <Total>
**Notes in batch:** <count>
**Prompt template version:** 1.0

### Suggestions

| Note | Tag | Confidence | In VOCAB | Reason |
| 001_Inbox/Note A.md | Meeting | confident | yes (33×) | explicit Sync agenda |
| 001_Inbox/Note A.md | OGC | confident | yes (18×) | primary entity |
| ... |

### Status: batch-suggested, awaiting-user-decision
```

### Step 6 — User Gate (per batch)

Display:

> Batch `<N>` of `<Total>`: `<count>` notes, `<sugg_count>` suggestions (`<conf_count>` confident, `<tent_count>` tentative).
>
> - `alle confident` — apply only confident tags
> - `alles` — apply all
> - `per Note` — walk each note individually
> - `skip <note-id>` — drop a specific note's suggestions
> - `override <note> <tag>` — replace a suggestion with user-chosen tag
> - `next batch` — skip this batch, continue to batch <N+1>
> - `stop` — halt, no more batches

Wait for user response. Parse and build per-note approved-tags list.

**Per-batch cost recalc.** After each batch processed, compute cumulative cost:
```bash
running_cost=$((running_cost + batch_cost))
if (( $(echo "$running_cost > $max_cost_usd * 0.8" | bc -l) )); then
  echo "Cost trending toward cap. Continue? (yes / stop)"
fi
```

Continue to next batch unless user says `stop`. Aggregate all approved suggestions across batches before Step 7.
```

- [ ] **Step 2: Verify SKILL.md parses**

```bash
python3 -c "
import yaml
content = open('skills/tag-suggest/SKILL.md').read()
fm = content.split('---', 2)[1]
yaml.safe_load(fm)
print('OK')
"
```

- [ ] **Step 3: Commit**

```bash
git add skills/tag-suggest/SKILL.md
git commit -m "feat(tag-suggest): SKILL.md Suggest/Preview/User-Gate (S6)

Add LLM suggestion prompt template (Haiku, temp=0, version 1.0),
JSON validation with retry-once, convention self-correction post-
check, per-batch chat preview, per-batch findings-file append,
per-batch user gate with override + skip + stop, and cumulative
cost recalc with 80%-of-cap warning.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: SKILL.md fill — Apply/Report

**Files:**
- Modify: `skills/tag-suggest/SKILL.md` (replace Workflow §7-8)

**Goal:** Apply approved suggestions via recipe (i) tag-add. Final report with new-vocab-entries hint.

- [ ] **Step 1: Replace Workflow steps 7-8**

```markdown
### Step 7 — Apply

For each note with approved suggestions:

1. **Pre-write concurrency check:**
   ```bash
   current_tags=$(./scripts/tag-extract.sh "$file" 2>/dev/null)
   ```
   Filter approved tags against current — if user manually added one already, skip silently (idempotent).

2. **Pre-write log to findings file Changes section:** append per-note row before mutation:
   ```markdown
   | <relative_path> | <approved_tags> | <source: vocab|new> |
   ```

3. **Execute recipe (i) tag-add** per `references/yaml-edits.md`:
   - If file has frontmatter with tags-block: append new tags inside.
   - If file has frontmatter, no tags-block: insert tags-block in canonical position.
   - If file has no frontmatter: create minimal frontmatter (only `tags:` block).
   - If verdict is `flow_style_skipped`: log Class-A finding "flow-style tags-block, skipped", continue.

4. **Birthtime preservation** per `references/skill-log.md`:
   ```bash
   created_iso=$(...)  # from YAML or Source Hierarchy
   touch -t "$(date -j -f '%Y-%m-%dT%H:%M:%S' "$created_iso" '+%Y%m%d%H%M.%S')" "$file"
   ```

5. **Skill-log callout entry** per file via recipe (e). Action string: `tag-suggest add <tag1>, <tag2>, ...`.

6. **VaultAutopilot tag** ensure present (recipe (i) call covers this).

7. **Halt on error.** Findings shows applied vs not. Re-run safe (untagged-filter on Pass A catches already-tagged notes from prior runs).

### Step 8 — Report

**Final chat-display:**

> tag-suggest applied tags to `<applied_count>` of `<total_untagged>` notes.
> - `<total_tags_added>` tags added (`<vocab_used_count>` from existing vocab, `<new_vocab_count>` new entries)
> - `<sparse_count>` notes skipped (sparse content)
> - `<user_skipped_count>` notes skipped per your decision
> - Estimated cost: \$`<estimate>` / Actual cost: \$`<actual>`
> - New vocabulary entries (consider pinning in vault-config):
>     `<sample_5_new_tags>`
> - Findings-file: `<VAULT>/_vault-autopilot/findings/<date>-tag-suggest.md`

**Update findings file Status** to `apply-complete` with full Changes ledger.

**New-vocab hint.** If `new_vocab_count > 0`, surface to user:

> "These are tags I introduced that don't exist elsewhere in your vault yet:
> `<list>`
>
> If you want them treated as canonical in future runs, add them to
> `[VAULT]/_vault-autopilot/config/tag-convention.md` as pins or as
> straight-up tag entries that future tag-suggest runs will see in VOCAB."

This is informational, not a destructive action — no scaffold-and-write here. (Bootstrap UX is tag-manage's territory; tag-suggest just hints.)

## Boundaries (carry-over from skeleton)

- Operates on YAML frontmatter only. Does not analyze inline `#tag` in body.
- Does not deduplicate or rename existing tags — that is `tag-manage`. Best-practice hint:
  > "If your vault has duplicate-tag chaos, run `tag-manage` first. Otherwise the vocabulary tag-suggest draws from inherits the chaos and suggestions reproduce it."
- Does not handle flow-style tags — recipe (i) returns flow_style_skipped, finding logged.

## Reserved Tags (carry-over)

Never suggested:
- `VaultAutopilot`
- `VaultAutopilot/*`

## See also (carry-over)

- Spec: `docs/superpowers/specs/2026-05-06-tag-suggest-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-plan-c-tag-suggest-build.md`
- Sibling skill: `skills/tag-manage/SKILL.md` (v0.2.0)
```

- [ ] **Step 2: Update SKILL.md frontmatter status from `skeleton` to `beta`**

In the YAML frontmatter, change `status: skeleton` to `status: beta`.

- [ ] **Step 3: Verify SKILL.md parses**

```bash
python3 -c "
import yaml
content = open('skills/tag-suggest/SKILL.md').read()
fm = content.split('---', 2)[1]
parsed = yaml.safe_load(fm)
assert parsed['status'] == 'beta'
print('OK, status=beta')
"
grep -c '^### Step' skills/tag-suggest/SKILL.md
```

Expected: `OK, status=beta`, 8 step sections.

- [ ] **Step 4: Commit**

```bash
git add skills/tag-suggest/SKILL.md
git commit -m "feat(tag-suggest): SKILL.md Apply/Report sections (S7)

Apply step orchestrates recipe (i) tag-add with pre-write concurrency
check, birthtime preservation, skill-log callout, and VaultAutopilot
tag injection.

Report step finalizes findings ledger with applied/skipped counts,
estimate vs actual cost, and new-vocab-entries hint suggesting user
consider pinning frequent new tags in vault-config.

Status: beta (was skeleton). Skill is now invokable for testing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Curated untagged-vault fixture + integration test

**Files:**
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/.obsidian/.gitkeep`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox/clear-topic.md`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox/sparse.md`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox/wikilinks-only.md`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox/with-tags.md`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox/no-frontmatter.md`
- Create: `tests/fixtures/curated/tag-suggest/untagged-vault/_vault-autopilot/config/tag-convention.md`
- Create: `scripts/test-tag-suggest-integration.sh`

**Goal:** Curated fixture + integration test driver for the deterministic-portion of tag-suggest workflow.

- [ ] **Step 1: Create fixture root + .obsidian + vault-config**

```bash
mkdir -p tests/fixtures/curated/tag-suggest/untagged-vault/.obsidian
mkdir -p tests/fixtures/curated/tag-suggest/untagged-vault/001_Inbox
mkdir -p tests/fixtures/curated/tag-suggest/untagged-vault/_vault-autopilot/config
touch tests/fixtures/curated/tag-suggest/untagged-vault/.obsidian/.gitkeep
```

Create `tests/fixtures/curated/tag-suggest/untagged-vault/_vault-autopilot/config/tag-convention.md`:

```markdown
---
schema: 1
pins:
  - {from: ogc, to: OGC}
---

Sample override.
```

- [ ] **Step 2: Write fixture notes**

`untagged-vault/001_Inbox/clear-topic.md`:

```markdown
---
title: OGC Marketing Sync
created: 2026-04-12
---

# OGC Marketing Sync

Met with the OGC team today to align on Q2 marketing strategy. Key decisions: focus on member acquisition through content channels, retire underperforming Facebook ads, double down on LinkedIn organic. Next steps: brief Linus on landing page redesign. We discussed budget allocation for the next quarter and agreed to A/B test new copy. Marketing dashboard will be updated weekly.
```

`untagged-vault/001_Inbox/sparse.md`:

```markdown
---
title: Quick Note
created: 2026-04-13
---

short.
```

`untagged-vault/001_Inbox/wikilinks-only.md`:

```markdown
---
title: Links
created: 2026-04-14
---

[[McFit]] [[Tibber]] [[Smartbroker]]
```

`untagged-vault/001_Inbox/with-tags.md` (already-tagged control, should NOT be processed):

```markdown
---
title: Already Tagged
created: 2026-04-15
tags:
  - Research
---

This note already has tags. tag-suggest should skip it.
```

`untagged-vault/001_Inbox/no-frontmatter.md`:

```markdown
# Note Without Frontmatter

This note has no YAML at all. tag-suggest should be able to add tags by creating minimal frontmatter.
```

- [ ] **Step 3: Write integration test driver**

Create `scripts/test-tag-suggest-integration.sh`:

```bash
#!/usr/bin/env bash
# scripts/test-tag-suggest-integration.sh
#
# Deterministic-portion integration test for tag-suggest.
# Asserts:
#   1. Pass A finds 4 untagged notes (clear-topic, sparse, wikilinks-only,
#      no-frontmatter); 1 already-tagged is filtered out.
#   2. sparse.md is filtered as insufficient_content (body < 50 chars).
#   3. Pass B VOCAB extraction returns 1 entry: Research (1×).
#   4. Cost estimate runs and produces a positive number.
#
# Does NOT exercise the LLM suggestion step (manual cycle test).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/curated/tag-suggest/untagged-vault"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cp -R "$FIXTURE" "$WORK/vault"

echo "Step 1: load effective convention"
./scripts/tag-convention-load.sh "$WORK/vault" > "$WORK/conv.json"
ogc_pin=$(python3 -c "
import json
pins = json.load(open('$WORK/conv.json'))['pins']
print(any(p['from']=='ogc' and p['to']=='OGC' for p in pins))
")
[ "$ogc_pin" = "True" ] || { echo "FAIL: vault override not merged"; exit 1; }
echo "  PASS effective convention loaded with vault override"

echo "Step 2: scan Pass A — find untagged notes"
> "$WORK/untagged.txt"
> "$WORK/sparse.txt"

find "$WORK/vault/001_Inbox" -name "*.md" -type f -print0 | \
  while IFS= read -r -d '' file; do
    tags=$(./scripts/tag-extract.sh "$file" 2>/dev/null)
    if [ -z "$tags" ]; then
      body=$(awk '/^---$/{if(f)exit;f=1;next} f' "$file" | head -c 800)
      body_chars=$(echo -n "$body" | wc -c | tr -d ' ')
      if [ "$body_chars" -lt 50 ]; then
        echo "$file" >> "$WORK/sparse.txt"
      else
        echo "$file|$body_chars" >> "$WORK/untagged.txt"
      fi
    fi
  done

untagged_count=$(wc -l < "$WORK/untagged.txt" | tr -d ' ')
sparse_count=$(wc -l < "$WORK/sparse.txt" | tr -d ' ')

# Expected: 3 untagged (clear-topic, wikilinks-only, no-frontmatter), 1 sparse
[ "$untagged_count" = "3" ] || { echo "FAIL: expected 3 untagged, got $untagged_count"; cat "$WORK/untagged.txt"; exit 1; }
[ "$sparse_count" = "1" ] || { echo "FAIL: expected 1 sparse, got $sparse_count"; exit 1; }
echo "  PASS Pass A: $untagged_count untagged, $sparse_count sparse"

# Verify with-tags.md was filtered (not in untagged)
if grep -q "with-tags.md" "$WORK/untagged.txt"; then
  echo "FAIL: with-tags.md should not be in untagged list"
  exit 1
fi
echo "  PASS already-tagged note correctly excluded"

echo "Step 3: Pass B — VOCAB extraction"
./scripts/tag-vocab-extract.sh "$WORK/vault" > "$WORK/vocab.txt"
research_freq=$(awk '$2=="Research" {print $1}' "$WORK/vocab.txt")
[ "$research_freq" = "1" ] || { echo "FAIL: expected Research freq=1, got $research_freq"; exit 1; }
echo "  PASS Pass B: Research found with freq=1"

echo "Step 4: cost estimate runs"
cost=$(./scripts/tag-suggest-cost-estimate.sh \
  "$WORK/untagged.txt" "$WORK/vocab.txt" "$WORK/conv.json" 10)
if ! [[ "$cost" =~ ^0\. ]]; then
  echo "FAIL: cost format unexpected: $cost"
  exit 1
fi
echo "  PASS cost estimate: \$$cost"

echo
echo "All tag-suggest integration assertions PASS."
echo
echo "Note: LLM suggestion step not exercised — manual cycle test."
exit 0
```

- [ ] **Step 4: Make executable, run**

```bash
chmod +x scripts/test-tag-suggest-integration.sh
./scripts/test-tag-suggest-integration.sh
```

Expected: all PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/curated/tag-suggest/ scripts/test-tag-suggest-integration.sh
git commit -m "test(tag-suggest): curated untagged-vault fixture + integration test (S8)

5 fixture notes covering clear-topic, sparse, wikilinks-only, already-
tagged (control), and no-frontmatter cases. Vault-config override with
ogc → OGC pin.

Integration test exercises Pass A (untagged-list with sparse filter),
Pass B (VOCAB extraction), and cost estimate. LLM suggestion step
deferred to manual cycle test.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Cycle 4 Gold Runs + USER-PASS

**Files:**
- Create: `scripts/cycle-tag-suggest-prep.sh`
- Create: `docs/superpowers/runs/_TEMPLATE-tag-suggest-gr.md`
- Create: `docs/superpowers/runs/<date>-tag-suggest-gr<N>.md` (4 run logs)
- Create: `docs/superpowers/runs/<date>-tag-suggest-user-pass.md`

**Goal:** Cycle 4 GR setup, manual GR runs against 4 vault topologies, then USER-PASS on production Nexus.

- [ ] **Step 1: Write Cycle prep script**

Create `scripts/cycle-tag-suggest-prep.sh`:

```bash
#!/usr/bin/env bash
# scripts/cycle-tag-suggest-prep.sh
#
# Generates the 4 vault topologies for tag-suggest Cycle 4 Gold Runs.
# Same approach as cycle-tag-manage-prep.sh but with --inject-untagged
# flag (added in this task — see generator extension).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_BASE="${1:-/tmp/tag-suggest-cycle-4}"
mkdir -p "$OUT_BASE"

echo "=== Generating GR-4 (synthetic untagged vault) ==="
"$REPO_ROOT/scripts/test-fixtures/generate-synthetic-vault.sh" \
  --output "$OUT_BASE/gr-4-synthetic" \
  --notes 200 \
  --unique-tags 80 \
  --chaos-ratio 0.0 \
  --seed 2026

# Post-process: strip tags from 50% of notes to create untagged set
python3 - "$OUT_BASE/gr-4-synthetic" <<'PYEOF'
import os, sys, random, glob, re
random.seed(2026)
vault = sys.argv[1]
files = sorted(glob.glob(f"{vault}/**/*.md", recursive=True))
files = [f for f in files if "_truth.json" not in f and "_vault-autopilot" not in f]
n_strip = len(files) // 2
to_strip = random.sample(files, n_strip)
for f in to_strip:
    with open(f) as fp:
        content = fp.read()
    # Remove tags-block lines
    new = re.sub(r'^tags:\n(?:  - .+\n)+', '', content, flags=re.MULTILINE, count=1)
    with open(f, 'w') as fp:
        fp.write(new)
print(f"Stripped tags from {n_strip} of {len(files)} notes")
PYEOF

echo
echo "=== GR-1, GR-2, GR-3 prep (manual) ==="
echo "Same procedure as tag-manage Cycle 4 prep — see scripts/cycle-tag-manage-prep.sh."
echo "For tag-suggest, the cost gate also requires that the vault has an OBSIDIAN_VAULT_PATH"
echo "with VOCAB data (Nexus is rich). Run tag-suggest with default scope (inbox)."
```

- [ ] **Step 2: Create run-log template**

Create `docs/superpowers/runs/_TEMPLATE-tag-suggest-gr.md`:

```markdown
# tag-suggest Gold Run GR-<N> — <Topology Name>

**Date:** YYYY-MM-DD
**Operator:** <name>
**OS / topology:** <macOS native | Windows powershell-clone | Windows robocopy-clone | macOS platinum>
**Vault path:** `<path>`
**Synthetic seed:** `<seed>` (only for GR-4)
**Skill version:** v0.2.x

## Pre-flight

- Plugin state check: `<grep -c result>`
- Windows preflight: `<pass | n/a>`
- Effective convention loaded: `<sha or summary>`

## Scan

- Untagged notes in scope: <N>
- Sparse-content skipped: <N>
- VOCAB total entries: <N>
- VOCAB top-3: <list>

## Cost

- Estimated: $<X>
- Actual: $<Y>  (within ±20%? <yes/no>)
- Cap: $<max_cost_usd>
- Cap-warning triggered: <yes / no>

## Suggestions

- Total batches: <N>
- Total suggestions: <N> (confident: <X>, tentative: <Y>)
- Convention self-corrections: <N>
- Folder-exclusive filter triggered: <N>

## Apply

- Approved: <N> notes, <N> tags
- Skipped (user): <N>
- Skipped (concurrent-modification): <N>
- Errors: <N>
- Birthtime restoration failures: <N>

## Synthetic baseline (GR-4 only)

- Vocabulary inheritance ≥ 70%: <%>
- New vocab entries: <N>
- Convention conformance: 100% / <%>

## Findings classes

- Class A: <list or none>
- Class B: <count>
- Class C: <count>
- Class D: <count>

## Verdict

- [ ] PASS
- [ ] FAIL — <reasons>
- [ ] CONDITIONAL PASS — <workarounds>

## Notes

<freeform>
```

- [ ] **Step 3: Run Cycle 4 GRs (manual)**

Operator runs 4 GRs in this order: GR-4 (synthetic) first for deterministic baseline, then GR-1 (macOS Nexus), GR-2 (Windows PowerShell), GR-3 (Windows robocopy). Each invokes tag-suggest in a fresh Claude Code session with the appropriate vault path. Pass criterion: 0 new Class-A skill-regressions.

For each GR, copy template + fill:

```bash
cp docs/superpowers/runs/_TEMPLATE-tag-suggest-gr.md \
   docs/superpowers/runs/$(date +%Y-%m-%d)-tag-suggest-gr<N>.md
```

After all 4 complete, commit:

```bash
git add docs/superpowers/runs/
git commit -m "test(tag-suggest): Cycle 4 GR run logs

GR-1 macOS Nexus: <verdict>
GR-2 Windows PowerShell-clone: <verdict>
GR-3 Windows robocopy-clone: <verdict>
GR-4 synthetic: <verdict>

Pass: 0 new Class-A skill-regressions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 4: USER-PASS gate**

User runs tag-suggest end-to-end against an untagged subset of Nexus. User reviews suggestions, approves selectively, verifies result. User pronounces PASS.

Document in `docs/superpowers/runs/<date>-tag-suggest-user-pass.md` (similar structure to tag-manage USER-PASS log — copy and adapt).

```bash
git add docs/superpowers/runs/<date>-tag-suggest-user-pass.md
git commit -m "test(tag-suggest): USER-PASS pronouncement on Nexus (S9)

User ran tag-suggest end-to-end against untagged subset of production
Nexus vault. <count> notes analyzed, <approved> tags applied,
<skipped> rejected, <new_vocab> new vocabulary entries surfaced.

User verdict: <PASS | CONDITIONAL | FAIL>.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

If FAIL: address issues, re-cycle, re-attempt.

---

## Task 10: Ship — version bump, changelog, CLAUDE.md update

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `logs/changelog.md`
- Modify: `CLAUDE.md`

**Goal:** Final ship steps — only after USER-PASS pronounced.

- [ ] **Step 1: Bump plugin version**

Edit `.claude-plugin/plugin.json`. Change `"version": "0.2.0"` to `"version": "0.2.1"`:

```json
{
  "name": "obsidian-vault-autopilot",
  "version": "0.2.1",
  ...
}
```

(If other features bundle in same release, may bump to `0.3.0` instead — discuss with maintainer.)

- [ ] **Step 2: Update changelog**

Append to `logs/changelog.md`:

```markdown
## v0.2.1 — Tag-suggest skill (YYYY-MM-DD)

**New skill:** `tag-suggest` — proposes tags for untagged notes based on body content + vault vocabulary. Cost-gated, batch-processed, two-bucket confidence (confident/tentative), user-approved before any write.

**Mechanics:**
- Default scope: `inbox` (cost discipline)
- Batch size default: 10 notes
- Hard cost cap: \$1.00 (overridable)
- Pinned model: claude-haiku, temperature=0
- Vocabulary inheritance: full-vault VOCAB feeds suggestion context (top 150 by frequency)
- Self-correction: LLM-proposed non-conformant tags transformed to canonical before display

**Foundations:**
- `references/yaml-edits.md` — recipe (i) tag-add (handles 4 sub-cases: existing tags-block, empty tags-key, missing tags-key, no frontmatter)

**Test infrastructure:**
- `scripts/tag-vocab-extract.sh` — VOCAB frequency table
- `scripts/tag-suggest-cost-estimate.sh` — Haiku cost projector
- `tests/fixtures/curated/tag-suggest/untagged-vault/` — handcrafted fixture

**Cycle 4 GRs:** GR-1, GR-2, GR-3, GR-4 — 0 new Class-A regressions.
**USER-PASS:** YYYY-MM-DD on Nexus production untagged subset.

**Deferred (v0.3.0 or later):** folder-exclusive enforcement, wikilink-based tag inference, multi-language tag detection.

See spec: `docs/superpowers/specs/2026-05-06-tag-suggest-design.md`
```

- [ ] **Step 3: Update CLAUDE.md Skills-Tabelle**

Update Row 8 status from `deferred (v0.2.x)` to `beta`:

```markdown
| 8 | tag-suggest | Propose tags for untagged notes (content-aware) | beta |
```

- [ ] **Step 4: Final state verification**

```bash
# Plugin version
grep '"version"' .claude-plugin/plugin.json

# Skills table
grep "tag-suggest" CLAUDE.md

# All Plan A + B + C tests still pass
./scripts/test-tag-extract.sh
./scripts/test-tag-detect-dupes.sh
./scripts/test-tag-detect-violations.sh
./scripts/test-tag-convention-load.sh
./scripts/test-tag-vocab-extract.sh
./scripts/test-tag-suggest-cost-estimate.sh
./scripts/test-tag-suggest-integration.sh
./scripts/test-tag-manage-chaos-vault.sh
./scripts/test-recipe-g-tag-rename.sh
./scripts/test-recipe-h-tag-remove.sh
./scripts/test-recipe-i-tag-add.sh
echo "All tests green."
```

Expected: all 11 test scripts exit 0.

- [ ] **Step 5: Commit + tag**

```bash
git add .claude-plugin/plugin.json logs/changelog.md CLAUDE.md
git commit -m "release(v0.2.1): ship tag-suggest skill

- Plugin version bump 0.2.0 → 0.2.1
- Changelog entry with feature summary, cycle 4 results, USER-PASS
- CLAUDE.md Skills-Tabelle: tag-suggest row → beta

USER-PASS: YYYY-MM-DD on Nexus production untagged subset.
4 Gold Runs: 0 new Class-A skill-regressions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

git tag -a v0.2.1 -m "v0.2.1 — tag-suggest skill"
git push origin HEAD --tags
```

- [ ] **Step 6: Open release PR**

```bash
gh pr create --title "v0.2.1 release — tag-suggest skill" --body "$(cat <<'EOF'
Implements Plan C from `docs/superpowers/plans/2026-05-06-plan-c-tag-suggest-build.md`.

## Ship contents
- `skills/tag-suggest/SKILL.md` — full workflow, status: beta
- `scripts/tag-vocab-extract.sh`, `tag-suggest-cost-estimate.sh`, `test-tag-suggest-integration.sh`
- `scripts/cycle-tag-suggest-prep.sh` — Cycle 4 GR prep
- `references/yaml-edits.md` — recipe (i) tag-add appended
- 4 GR run logs + USER-PASS log
- Plugin version 0.2.1
- Changelog + CLAUDE.md updated

## Cycle 4 results
| GR | Topology | Verdict |
| ---: | :--- | :--- |
| GR-1 | macOS Nexus | <PASS> |
| GR-2 | Windows PowerShell-clone | <PASS> |
| GR-3 | Windows robocopy-clone | <PASS> |
| GR-4 | synthetic | <PASS> |

USER-PASS: <date> on Nexus untagged subset.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

After merge: announce. Tag-skills (manage + suggest) are both shipped beta.

---

## Plan C Self-Review Checklist

After completing all tasks, verify:

- [ ] Spec coverage complete:
  - S1 (recipe (i) tag-add) ✓ Task 1
  - S2 (skill skeleton) ✓ Task 2
  - S3 (VOCAB + cost-estimate utilities) ✓ Tasks 3, 4
  - S4 (cost-gate workflow) ✓ Task 5
  - S5 (LLM suggest workflow) ✓ Task 6
  - S6 (approval workflow) ✓ Task 6
  - S7 (apply integration + report) ✓ Task 7
  - S8 (Cycle 4 GRs) ✓ Task 9
  - S9 (USER-PASS) ✓ Task 9
  - S10-S13 (ship) ✓ Task 10
- [ ] No "TBD"/"TODO"/"implement later" placeholders
- [ ] Function names consistent (recipe (i) tag-add, tag-vocab-extract, tag-suggest-cost-estimate)
- [ ] All test scripts exit 0
- [ ] Determinism pins consistent (Haiku, temp=0, prompt_template_version=1.0)
- [ ] Co-Authored-By footers
- [ ] Release PR opened
