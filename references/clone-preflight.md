# Clone-Cluster Preflight (Cross-Platform)

A WARN-flow preflight check that runs on **every operating system** before any date-derivation skill (`property-enrich`, `note-rename`, `inbox-sort`, `property-describe`) executes against the vault. It detects vaults whose filesystem birthtimes are clustered at a clone moment, so the user understands why the runtime SKIP-gate (documented in [`clone-cluster-detection.md`](clone-cluster-detection.md)) will leave certain `created` fields blank.

## Why this exists

Cloning a vault — `robocopy` or `Copy-Item` on Windows, `cp -R` on macOS, `cp -a` on Linux, `git clone`, or any GitHub ZIP download — collapses every file's filesystem birthtime onto the clone moment. If a date-derivation skill falls through Source Hierarchy to filesystem birthtime in that situation, it will write the clone-time as `created` for every affected file. The runtime SKIP-gate prevents this by SKIPping `created` enrichment for cluster-window files with no alternate date source. This preflight surfaces the same condition to the user before runtime, so the SKIPs (which appear as Class-C findings in each skill's findings file) are not a surprise.

The clone-cluster condition is **not Windows-specific**. macOS `cp -R` and Linux `cp -a` produce the same cluster as Windows `robocopy`. Therefore this preflight runs unconditionally — independent of the host OS check in [`windows-preflight.md`](windows-preflight.md).

## WARN-flow, not STOP-flow

This step emits a non-blocking warning when a clone-induced birthtime cluster is detected. **Skill execution continues.** The runtime SKIP-gate documented in [`clone-cluster-detection.md`](clone-cluster-detection.md) is the data-safety mechanism; this preflight is transparency, not enforcement.

## Run the detector

Run the detector against the configured vault root. The script is cross-platform — it works on macOS (Darwin `stat -f '%B'`), Linux (`stat -c '%W'` with mtime fallback), and Windows under MSYS / Git Bash (which provides Linux-style `stat`).

```bash
eval "$(scripts/detect-clone-cluster.sh "$OBSIDIAN_VAULT_PATH")"
```

This sets `CLUSTER_FOUND` and, when the value is `yes`, additionally sets `CLONE_CLUSTER_WINDOW_START`, `CLONE_CLUSTER_WINDOW_END`, and `CLUSTER_FILE_COUNT`.

## Decision matrix

| `CLUSTER_FOUND` | Action |
|---|---|
| `no` | Silent. Continue to the skill's normal workflow. |
| `yes` | Emit the WARN message below, then **continue** with the skill's normal workflow. The runtime SKIP-gate handles correctness. |

## WARN message

Display verbatim, substituting the captured values, then proceed:

> **Clone-cluster birthtime detected (informational, not blocking).**
>
> [`$CLUSTER_FILE_COUNT`] files share filesystem birthtimes inside `[$CLONE_CLUSTER_WINDOW_START]..[$CLONE_CLUSTER_WINDOW_END]`. This pattern indicates the vault was recently cloned or restored — birthtimes reflect clone-time, not the original note-creation time.
>
> Date-derivation skills (`property-enrich`, `note-rename`, `inbox-sort`, `property-describe`) will automatically SKIP files in this window when no alternate date source (YAML `created`, `YYYY-MM-DD` filename, git first-commit) is available. Affected files will appear in each skill's findings file as **Class C — clone-cluster birthtime, no alt source**.
>
> Full mitigation behavior: [`references/clone-cluster-detection.md`](clone-cluster-detection.md).

After emitting the WARN, proceed with the skill's core workflow.

## Why this preflight is empirical, not theoretical

The GR-3 strict-path validation on `nexus-clone-robocopy` (2026-05-01) found 36.8 % (189 / 514) of inbox-tree files clustered at `2026-04-16T20:33:23Z` — the vault's clone time. `robocopy /E /COPY:DAT` was supposed to preserve `CreationTime` from the source; empirically it did not (post-clone Defender / Indexer / Obsidian-cache resets, or robocopy's Windows CreationTime semantics being unreliable in practice). The same shape appears on macOS when a vault is cloned via `cp -R` (no `-a`), which resets all birthtimes to the clone moment by design. This preflight surfaces the same reality to the user before any date-derivation runs, so the runtime SKIPs (which appear as Class-C findings) are not a surprise.

## Test fixture for this preflight

The regression-lock for clone-cluster detection lives at `tests/fixtures/clone-cluster/` (the W2 fixture, reused). Run `scripts/test-clone-preflight.sh` to assert that `scripts/detect-clone-cluster.sh` emits `CLUSTER_FOUND=yes` against the cluster fixture, `CLUSTER_FOUND=no` against a sub-floor (5-file) directory and against an empty directory, and that the cross-doc claims in `windows-considerations.md` and `cloning-guide.md` reflect empirical reality (no `robocopy /COPY:DAT preserves CreationTime` claim).

## What this preflight does NOT check

- **Whether the vault was cloned at all in the absence of a birthtime cluster.** A small clone (< 10 files) or a clone that occurred far enough in the past that other write activity has spread birthtimes across multiple bins will not trigger this preflight. The runtime SKIP-gate in `clone-cluster-detection.md` uses the same threshold; both are intentionally biased toward false-negatives over false-positives. See [`docs/cloning-guide.md`](../docs/cloning-guide.md) for clone-method recommendations.
- **Whether any individual file's birthtime is "correct."** This preflight detects the cluster pattern. Per-file correctness is the runtime SKIP-gate's job, not this preflight's.

## Cost

One invocation of `scripts/detect-clone-cluster.sh` per skill run. Typical vault (~ 2–5k markdown files): ~50–200 ms. The check is cheap enough to run every invocation, on every OS.

## Relationship to other preflight checks

- [`references/windows-preflight.md`](windows-preflight.md) handles Windows-specific concerns: `LongPathsEnabled` registry check (STOP-flow), trailing-dot folder detection (WARN-flow), and the Windows-aware file-enumeration pattern. It runs only when `IS_WINDOWS=1`.
- This preflight (`clone-preflight.md`) handles cross-platform clone-cluster detection. It runs unconditionally.

The two are complementary: a launch-scope skill on Windows runs both; on macOS or Linux it runs only this one.
