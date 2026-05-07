# tests/fixtures/clone-cluster

Synthetic vault for the W2 clone-cluster-detection regression test (`scripts/test-clone-cluster.sh`).

## Population

30 markdown files split into four cells, mapped 1:1 to the decision matrix in `references/clone-cluster-detection.md`:

| Cell | Count | birthtime | alt source (YAML/filename/git) | Expected verdict |
|------|-------|-----------|---------------------------------|------------------|
| A | 20 | clustered (2026-04-16 20:33:23 UTC ± 30 min, deterministic offsets) | none | **SKIP** auto-enrich |
| B | 5 | clustered (same window) | YAML `created: 2024-...` | **PROCESS** (use YAML) |
| C | 3 | not clustered (2026-01-15 + offsets, days apart) | none | **PROCESS** normally |
| D | 2 | not clustered | YAML `created: 2024-...` | **PROCESS** (use YAML) |

Total: 30 files. Cluster size ≥ 10 within 1h → `is_birthtime_in_clone_cluster_window` returns true for cells A+B (25 files). `has_alternate_date_source` returns true for cells B+D (7 files).

## Deterministic generation

`generate.sh` is idempotent. It removes `notes/` if it exists, recreates it, and uses `touch -t` to set birthtimes deterministically. The generated `notes/` directory is gitignored — regenerate on demand.

## Truth file

`_truth.json` maps each filename to its expected verdict (`SKIP` or `PROCESS`) and the reason (`clustered_no_alt`, `clustered_alt`, `not_clustered_no_alt`, `not_clustered_alt`). The assertion script validates that any tool implementing the recipes produces the same verdict.
