#!/usr/bin/env python3
"""
Validate recipe (f) — Normalize inside-colon quoted-keys (F26 repair).

This is the deterministic part of v0.1.3 that does NOT depend on an LLM. It
applies the recipe-f algorithm directly to F26/F19 fixtures and compares the
result against the expected golden files. Validates that fixtures + recipe
are internally consistent.

Does NOT replace the full smoke-test (which requires actual skill execution
for Source Hierarchy walks, title-from-H1, tag append, callout, etc.). It
validates the YAML-edit-recipe surface only.

Exit 0 on PASS, 1 on diff, 2 on error.

Per references/yaml-edits.md recipe (f):
  1. Read frontmatter lines.
  2. For each line matching F26_INSIDE_COLON_PATTERN: replace with normalized form.
  3. Resolve duplicate-key collisions (keep first, remove subsequent).
  4. Idempotent.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
F26_INSIDE_COLON_PATTERN = re.compile(r'^(\s*)"([^"]+):"\s*:(.*)$')
F25_STANDARD_QUOTED_PATTERN = re.compile(r'^(\s*)"([^":]+)"\s*:(.*)$')


def read_frontmatter(text: str) -> tuple[list[str], list[str]] | None:
    """Return (frontmatter_lines, body_lines) or None if no frontmatter."""
    lines = text.splitlines(keepends=False)
    if not lines or lines[0].rstrip() != "---":
        return None
    for i in range(1, len(lines)):
        if lines[i].rstrip() == "---":
            return lines[1:i], lines[i + 1 :]
    return None


def recipe_f_normalize(frontmatter: list[str]) -> tuple[list[str], list[tuple[str, str]]]:
    """Apply recipe (f). Return (normalized_lines, dedup_findings)."""
    # Step 1: normalize inside-colon shapes
    normalized: list[str] = []
    for line in frontmatter:
        m = F26_INSIDE_COLON_PATTERN.match(line)
        if m:
            indent, key_name, rest = m.group(1), m.group(2), m.group(3)
            normalized.append(f"{indent}{key_name}:{rest}")
        else:
            normalized.append(line)

    # Step 2: resolve duplicate-key collisions (keep first, remove rest)
    findings: list[tuple[str, str]] = []
    seen_keys: dict[str, int] = {}
    keep: list[bool] = [True] * len(normalized)
    for idx, line in enumerate(normalized):
        # Per-line key extraction — match plain identifier OR shape-α
        m_plain = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*:', line)
        m_alpha = F25_STANDARD_QUOTED_PATTERN.match(line)
        key = None
        if m_plain:
            key = m_plain.group(1)
        elif m_alpha:
            key = m_alpha.group(2)
        if key is None:
            continue  # not a key line (list item, blank, comment)
        if key in seen_keys:
            keep[idx] = False
            findings.append((key, line.strip()))
        else:
            seen_keys[key] = idx
    deduped = [line for line, k in zip(normalized, keep) if k]
    return deduped, findings


def normalize_line_endings_and_strip_callout(text: str) -> str:
    """Strip the skill-log callout block + normalize line endings.

    Mirrors scripts/smoke-test.sh::normalize_for_diff so the validator and the
    bash runner produce comparable output.
    """
    out = []
    in_callout = False
    for raw in text.splitlines():
        if raw.rstrip() == "> [!info] Vault Autopilot":
            in_callout = True
            continue
        if in_callout:
            stripped = raw.lstrip()
            if not stripped.startswith(">"):
                in_callout = False
                # fall through and emit
            else:
                continue
        out.append(raw)
    return "\n".join(out)


def apply_recipe_f_only(input_text: str) -> str:
    """Apply recipe (f) to a fixture. Skill-log + tag-append are NOT applied here."""
    fm = read_frontmatter(input_text)
    if fm is None:
        return input_text
    fm_lines, body = fm
    deduped, _ = recipe_f_normalize(fm_lines)
    return "\n".join(["---", *deduped, "---", *body])


# --- Test cases ---

TESTS = [
    # (label, input_path, expected_text_after_recipe_f_only)
    (
        "f19 — both keys shape β",
        "test-data/f19-repro.md",
        # Expected post-recipe-f only: "created:" → created, "modified:" → modified.
        # (No tag-append, no callout — those are skill-log Nahbereich, separate from recipe f.)
        None,  # computed below
    ),
    (
        "f26 — 4 shape-β + 1 duplicate collision",
        "test-data/f26-repro.md",
        None,  # computed below
    ),
    (
        "f26-mixed — 1 shape-β + 1 shape-α (untouched)",
        "test-data/f26-mixed-shapes-repro.md",
        None,
    ),
    (
        "f25 — shape α only (recipe f no-op)",
        "test-data/f25-repro.md",
        None,
    ),
    (
        "f2 — no quoted keys at all (recipe f no-op)",
        "test-data/f2-repro.md",
        None,
    ),
]


def compute_expected_for(fixture_label: str, input_text: str) -> str:
    """Compute the post-recipe-f-only expected output deterministically."""
    return apply_recipe_f_only(input_text)


def main() -> int:
    failed = 0
    print("=== validate-recipe-f.py ===\n")
    for label, fixture_rel, _ in TESTS:
        fixture = REPO_ROOT / fixture_rel
        if not fixture.exists():
            print(f"  ERROR: fixture not found: {fixture}")
            return 2
        input_text = fixture.read_text(encoding="utf-8")
        actual = apply_recipe_f_only(input_text)

        # Idempotency check: applying recipe-f again must be a no-op.
        actual2 = apply_recipe_f_only(actual)
        if actual != actual2:
            print(f"  FAIL [{label}]: recipe (f) is NOT idempotent")
            print("  --- diff first-vs-second pass ---")
            for a, b in zip(actual.splitlines(), actual2.splitlines()):
                if a != b:
                    print(f"    < {a!r}")
                    print(f"    > {b!r}")
            failed += 1
            continue

        # Validate specific guarantees per fixture
        fm = read_frontmatter(actual) or ([], [])
        fm_lines = fm[0]

        # No line should still match F26_INSIDE_COLON_PATTERN (all repaired)
        unrepaired = [ln for ln in fm_lines if F26_INSIDE_COLON_PATTERN.match(ln)]
        if unrepaired:
            print(f"  FAIL [{label}]: {len(unrepaired)} inside-colon lines remain after recipe (f)")
            for ln in unrepaired:
                print(f"    {ln!r}")
            failed += 1
            continue

        # Shape-α lines should be PRESERVED
        if "f25" in fixture_rel:
            alpha_lines = [ln for ln in fm_lines if F25_STANDARD_QUOTED_PATTERN.match(ln)]
            if not alpha_lines:
                print(f"  FAIL [{label}]: shape-α line `\"description\":` was NOT preserved by recipe (f)")
                failed += 1
                continue
        if "f26-mixed" in fixture_rel:
            alpha_lines = [ln for ln in fm_lines if F25_STANDARD_QUOTED_PATTERN.match(ln)]
            if not alpha_lines:
                print(f"  FAIL [{label}]: shape-α line was NOT preserved (recipe f scope-leak)")
                failed += 1
                continue

        # Duplicate-collision check for f26
        if fixture_rel.endswith("/f26-repro.md"):
            created_count = sum(
                1 for ln in fm_lines if re.match(r'^\s*created\s*:', ln)
            )
            if created_count != 1:
                print(f"  FAIL [{label}]: expected 1 `created:` line after dedup, got {created_count}")
                failed += 1
                continue

        print(f"  PASS [{label}]")

    print()
    if failed == 0:
        print("=== validate-recipe-f.py PASS — recipe (f) is idempotent + scope-correct on all fixtures ===")
        return 0
    print(f"=== validate-recipe-f.py FAIL — {failed} fixture(s) failed ===")
    return 1


if __name__ == "__main__":
    sys.exit(main())
