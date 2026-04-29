# German Date Normalization

## Purpose

`property-enrich` Source Hierarchy step (Prio 1) reads YAML `created` values. ISO 8601 (`2024-03-14`, `2024-03-14T17:02:59`) parses directly. Other formats fall through to lower priorities (filename, git, birthtime). German locale users frequently store DACH-region timestamps in the form `DD.MM.YYYY[, HH:mm:ss]` — these would otherwise be discarded as unparseable, even though a valid date is in YAML.

This reference defines the normalization step that runs BEFORE the ISO parser, so German-formatted values are recognized and converted to ISO 8601.

## Scope

This reference covers ONLY the `DD.MM.YYYY[, HH:mm:ss]` format (German / Swiss / Austrian / Liechtensteinian convention). Other locale formats (American `MM/DD/YYYY`, ISO-with-slashes, RFC 2822, etc.) are out-of-scope for v0.1.3.

If a value matches none of the patterns below, fall through to the regular ISO parser (which then falls through to filename / git / birthtime per Source Hierarchy). Never silently overwrite an unparseable existing value.

## The pattern

```python
import re

GERMAN_DATE_PATTERN = re.compile(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:,\s*(\d{1,2}):(\d{2})(?::(\d{2}))?)?$'
)

def normalize_german_date(value: str) -> str | None:
    """Convert DD.MM.YYYY[, HH:mm:ss] to ISO 8601. Return None if no match."""
    m = GERMAN_DATE_PATTERN.match(value.strip())
    if not m:
        return None
    day, month, year = m.group(1), m.group(2), m.group(3)
    hour, minute, second = m.group(4), m.group(5), m.group(6)
    iso = f"{year}-{int(month):02d}-{int(day):02d}"
    if hour:
        iso += f"T{int(hour):02d}:{minute}:{second or '00'}"
    return iso
```

## Examples

| Input | Output |
|-------|--------|
| `30.01.2026, 17:02:59` | `2026-01-30T17:02:59` |
| `30.01.2026` | `2026-01-30` |
| `1.6.2024` | `2024-06-01` |
| `1.6.2024, 9:05` | `2024-06-01T09:05:00` |
| `01.06.2024, 09:05:30` | `2024-06-01T09:05:30` |
| `2024-03-14` | `None` (already ISO; pass through to existing parser) |
| `March 14, 2024` | `None` (out-of-scope; fall through) |
| `14/03/2024` | `None` (out-of-scope; fall through) |

## Where called

`property-enrich` Workflow Step 3 (Compute), specifically when reading the YAML `created` value (Source Hierarchy Prio 1). Normalization runs BEFORE the existing ISO parser. If `normalize_german_date` returns a value, treat that as a valid Prio-1 hit. If `None`, try the existing ISO parser. If still `None`, fall through to Prio 2 (filename date pattern) per existing logic.

## Boundaries

- Read-only normalization. The original YAML value is NOT rewritten — `property-enrich` is additive, and `created` is one of its never-overwrite fields.
- Only used for the `created` Source Hierarchy. Other fields (e.g. `modified`) get their values from the filesystem, not parsed from YAML.
- If the user wants the YAML value rewritten to ISO format, that is a separate normalization pass (out-of-scope for v0.1.3).

## Test fixture

`test-data/f2-repro.md` exercises this normalization. Expected post-enrich state: `created` is preserved as the German-formatted value in YAML (additive-only), `modified` is refreshed from filesystem mtime, `VaultAutopilot` tag added, skill-log callout appended.

## Risk — locale ambiguity

The pattern `DD.MM.YYYY` is unambiguous in DACH locales but conflicts with American month-first formats in edge cases (e.g. `01.02.2024` is January 2nd in American, February 1st in DACH). v0.1.3 assumes DACH convention since this is a German-locale-targeted normalization. If broader locale support is needed later, a config knob (`locale_date_format: dach | us | iso`) goes onto the v0.2.0 roadmap.
