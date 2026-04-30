# YAML Sanity — Pre-Write Defense-in-Depth

## Purpose

Every property-writing skill calls this sanity-check BEFORE attempting any
YAML edit (recipes b/c/d/e per `references/yaml-edits.md`). The check returns
a verdict the skill uses to decide: proceed, repair, or skip-with-finding.

## When to call

Step zero of any property-write workflow:

- `property-enrich` Step 2a (before Compute / Source Hierarchy walk) AND pre-Write (Step 5)
- `property-describe` Step 2a (before Filter — eligibility check) AND pre-Write (Step 5)
- `note-rename` Step 4a (before Classify cooldown logic)
- `inbox-sort` Step 5a (before Cooldown evaluation)
- `property-classify` (v0.2.0+) Step 2 (before Type/Status detection)

## Procedure

1. Read frontmatter lines per `references/yaml-edits.md` recipe (a).
2. If no frontmatter exists: return verdict `OK_NO_FRONTMATTER`.
3. Walk frontmatter lines. Match each line against detection patterns (§ "Detection patterns" below). Collect findings.
4. Walk the entire file (not just frontmatter) for multi-block / unclosed-block detection.
5. Return verdict + finding list.

## Verdicts

| Verdict | Meaning | Action by skill |
|---------|---------|-----------------|
| `OK` | Frontmatter is well-formed, only plain-identifier keys | Proceed normally |
| `OK_QUOTED` | Frontmatter has standard quoted-keys (shape α — `"key":`, valid YAML) but no inside-colon shape and no other issues | Proceed normally; skill regexes must accept both plain and standard-quoted forms |
| `OK_NO_FRONTMATTER` | File has no frontmatter to inspect | Proceed normally — recipe (c) creates one if needed |
| `BROKEN_KEYS_INSIDE_COLON` | One or more shape β inside-colon patterns detected (`"<key>:":`) — F26 | Repair via recipe (f) (if skill is repair-capable) OR skip + Class-C finding (additive-only skills) |
| `MULTIPLE_FRONTMATTER_BLOCKS` | Two or more `---/---` pairs at frontmatter-boundary positions | Skip + Class-A finding. Route to `note-rename` corrupted-file-detection if not already there. |
| `UNCLOSED_FRONTMATTER` | First line `---` but no matching closing `---` | Skip + Class-A finding. User-investigation required. |
| `INVALID_YAML` | Detection patterns OK but YAML still unparseable (rare) | Skip + Class-A finding. Manual review. |

**Verdict-priority:** A file may match multiple patterns. Verdict order: `MULTIPLE_FRONTMATTER_BLOCKS` > `UNCLOSED_FRONTMATTER` > `INVALID_YAML` > `BROKEN_KEYS_INSIDE_COLON` > `OK_QUOTED` > `OK_NO_FRONTMATTER` > `OK`. Highest matching verdict wins. Cosmetic findings logged regardless of verdict.

## Detection patterns

### Pattern 1 — Inside-colon quoted-key (shape β — F26)

**Per-line regex (single-line input — safe per yaml-edits.md):**

```python
F26_INSIDE_COLON_PATTERN = re.compile(r'^(\s*)"([^"]+):"\s*:(.*)$')
```

The crucial structure: `:"` BEFORE the closing quote AND `\s*:` AFTER the closing quote. Both colons are required to match.

**Match groups:**
1. Leading whitespace (preserve indentation)
2. Key name (without surrounding quotes, without trailing-colon-inside-quotes)
3. Everything after the value-colon (the value, possibly with trailing comment)

**Example:**

```
"created:": 2024-03-14
```

Match groups: `("", "created", " 2024-03-14")`.

**Verdict contribution:** if any line matches → `BROKEN_KEYS_INSIDE_COLON`.

### Pattern 1b — Standard quoted-key (shape α — F25)

**Per-line regex (single-line input):**

```python
F25_STANDARD_QUOTED_PATTERN = re.compile(r'^(\s*)"([^":]+)"\s*:(.*)$')
```

The crucial part: `[^":]+` inside the brackets — NO `"` and NO `:` allowed inside the key name. This is what distinguishes shape α from shape β.

**Match groups:**
1. Leading whitespace
2. Key name (without surrounding quotes)
3. Everything after the value-colon

**Example:**

```
"description": A standard quoted-key value
```

Match groups: `("", "description", " A standard quoted-key value")`.

**Verdict contribution:** if any line matches AND no shape-β line matches → `OK_QUOTED`. If both shapes coexist on different lines → `BROKEN_KEYS_INSIDE_COLON` wins (the broken shape signals to the skill to repair, then re-scan).

**No repair needed.** Standard quoted-keys are valid YAML. Skill regexes must simply accept this shape (see per-skill policy table below).

### Detection-precedence rule (critical)

Walk inside-colon pattern FIRST, standard quoted-key SECOND. The inside-colon pattern is a strict subset (must contain inside-colon); standard pattern matches any quoted-key WITHOUT inside-colon.

A line like `"description:":` matches inside-colon (verdict β), NOT standard (because the `:` inside `[^":]+` is forbidden). A line like `"description":` matches standard (verdict α), NOT inside-colon.

### Pattern 2 — Multiple frontmatter blocks

Walk the entire file (not just frontmatter). Count occurrences of lines where `.rstrip() == '---'`. Treat first occurrence at line 0 as frontmatter open. Treat next occurrence as frontmatter close.

After the close, if a subsequent line is also `.rstrip() == '---'` AND is NOT inside a code-fence (no triple-backtick opening before it), AND a subsequent matching `---` exists, AND at least one line between the two `---` markers matches a YAML-key-like pattern (`^\s*[A-Za-z_][A-Za-z0-9_-]*\s*:` OR `^\s*"[^"]+"\s*:`): this is a SECOND frontmatter block.

Otherwise (no YAML-key-like lines between the pair): body-level horizontal-rule separator — not a frontmatter block, no verdict contribution.

> **Why this matters:** Body-level `---` horizontal-rule pairs are common in longer notes. Without the YAML-content check, any note with two `---` separators in the body produces a false-positive `MULTIPLE_FRONTMATTER_BLOCKS` verdict. Empirically confirmed: 72 false positives in GR-2 Cell 4 re-run (2026-04-30) on nexus-clone-powershell (1016 files); all were body horizontal-rule pairs, zero genuine second frontmatter blocks.

**Verdict contribution:** if two or more genuine frontmatter blocks → `MULTIPLE_FRONTMATTER_BLOCKS`.

This pattern is canonically defined in `note-rename`'s Corrupted File Detection (SKILL.md § "Corrupted File Detection"). The sanity-check uses the same detection logic, exposed as a callable.

### Pattern 3 — Unclosed frontmatter

If line 0 is `---` but no subsequent line equals `---`: frontmatter never closes. **Verdict:** `UNCLOSED_FRONTMATTER`.

### Pattern 4 — Cosmetic-only (Class-D)

Whitespace-only lines between final field and closing `---`. Or trailing whitespace on a frontmatter field line. These are non-blocking.

**Verdict contribution:** logged in finding list, but verdict stays at the worst non-cosmetic verdict found.

## Per-skill policy

| Skill | On Class-A (multi-block / unclosed) | On `BROKEN_KEYS_INSIDE_COLON` (shape β) | On `OK_QUOTED` (shape α) | On Class-D cosmetic |
|-------|-----------|---------------------------------|----------------------------------|---------------------|
| `property-enrich` | skip + Class-A finding (route to user / note-rename) | repair via Step 2a recipe (f), then re-run sanity-check (idempotent fixpoint) | proceed; skill regex matches both shapes | proceed |
| `note-rename` | use existing Corrupted File Detection (rename file with corruption-label) | repair via Step 4a recipe (f) (broadened from existing hardcoded-list) | proceed; skill regex matches both shapes | proceed |
| `inbox-sort` | skip + Class-A finding (route to note-rename) | repair via Step 5a recipe (f) (broadened from existing hardcoded-list) | proceed; skill regex matches both shapes | proceed |
| `property-describe` | skip + Class-A finding | SKIP + Class-C finding "broken-yaml: inside-colon shape detected — run property-enrich first" (NOT repair — boundaries: describe is additive-only) | proceed; broadened filter regex catches both plain and standard-quoted forms | proceed |
| `property-classify` (v0.2.0) | skip + finding | skip + finding | proceed; broadened regex | proceed |

Defense-in-depth lives in the **sanity-check call itself**: skills that already have repair logic in their workflow (enrich, rename, sort) are calling sanity-check as a Step-zero pre-flight. If sanity-check returns Class-A, skill skips. If Class-C (`BROKEN_KEYS_INSIDE_COLON`), skill calls its own repair step. If both succeed, skill proceeds normally.

## Idempotency

After a repair-skill runs the inside-colon-quoted-key normalization (recipe f), calling the sanity-check again on the same file MUST return `OK`, `OK_QUOTED`, or `OK_NO_FRONTMATTER` (any non-`BROKEN_KEYS_INSIDE_COLON` non-Class-A verdict). This is the contract: repair is permanent within the run, normalize is idempotent.

## Worked example

Input file (broken — shape β):

```yaml
---
"created:": 2024-03-14
"description:": Apple Notes export
tags: [AppleNoteImport]
---
```

`property-enrich` calls sanity-check:

1. Walk frontmatter lines.
2. Line 1: matches `F26_INSIDE_COLON_PATTERN` → finding ("created").
3. Line 2: matches `F26_INSIDE_COLON_PATTERN` → finding ("description").
4. Line 3: no match.
5. Return `BROKEN_KEYS_INSIDE_COLON` with two findings.

Skill calls Step 2a normalize (recipe f):

1. Replace line 1: `created: 2024-03-14`
2. Replace line 2: `description: Apple Notes export`

Re-call sanity-check: returns `OK`. Skill proceeds.

`property-describe` later runs on same file (now repaired): sanity-check returns `OK`. Filter detects `description: Apple Notes export` (length 20 ≥ 10) → file already has description → skip (eligible-skip, not error-skip).

## Why a separate file

`yaml-edits.md` defines the WRITE recipes (b, c, d, e) and the prerequisite read recipe (a). Recipe (f) (normalize) lives in `yaml-edits.md` too, as the canonical write-side procedure.

`yaml-sanity.md` defines the PRE-WRITE check that runs before any of those recipes. They are complementary: yaml-edits.md is "how to safely edit"; yaml-sanity.md is "should we attempt to edit at all".
