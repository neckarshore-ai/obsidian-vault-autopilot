# Windows Preflight

Run this procedure **before** the skill's core workflow if the host operating system is Windows. On macOS or Linux, skip the entire procedure — there is nothing to check.

> **Run on EVERY skill invocation. No caching across turns.**
>
> Do not skip this preflight because you ran it earlier in this conversation. The registry value can change between invocations (the user toggles it, an admin tool toggles it, a domain policy refresh resets it). A previous turn's "pass" result is not authoritative for this turn. This rule applies in resumed sessions, in continued conversations, and after any tool call that could have altered system state. When in doubt: run the check again.

## Why this exists

On Windows, file paths default to a 260-character limit (MAX_PATH). PowerShell-based file enumeration silently skips files at paths longer than 260 characters when this limit is not raised. Empirical measurement on a 1856-note vault: ~14 subfolders worth of files were invisible to enumeration without the registry fix. Skills running in that state would report "0 files" or operate on an incomplete subset.

This is a "Do no harm" issue, not a feature gap. The skill must STOP rather than silently process partial data.

Full context: [`docs/windows-considerations.md`](../docs/windows-considerations.md).

## Step 1 — Detect operating system

```bash
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac
```

If `IS_WINDOWS=0`, skip the rest of this document. Proceed with the skill's normal workflow.

If `IS_WINDOWS=1`, continue with Step 2.

## Step 2 — Check LongPathsEnabled

```bash
LP=$(powershell.exe -NoProfile -Command \
  "(Get-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem' -ErrorAction SilentlyContinue).LongPathsEnabled" \
  2>/dev/null | tr -d '\r\n')
```

Three possible outcomes:

| LP value | Meaning | Action |
|----------|---------|--------|
| `1` | Long Path support is enabled | Proceed silently. The skill is safe to run. |
| `0` or empty | Long Path support is NOT enabled | STOP — see Step 3 |
| `powershell.exe: command not found` (or any error) | Detection failed | STOP — see Step 4 |

## Step 3 — STOP if LongPathsEnabled is not 1

Do not run the skill's core workflow. Show the user this message and wait:

> **Windows Long Path support is not enabled on this system.**
>
> Without it, this skill silently skips files at paths longer than 260 characters. Most deep PARA-style vaults have files at long paths. Running the skill in this state would process only a partial subset of your vault — without telling you which files were missed.
>
> **To fix this (one-time, requires Administrator):**
>
> 1. Close this terminal.
> 2. Open Command Prompt (`cmd.exe`) **as Administrator** — Start menu → type `cmd` → right-click → "Run as administrator".
> 3. Paste and run:
>    ```cmd
>    reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f
>    ```
> 4. Close the Administrator cmd window.
> 5. Reopen your normal terminal and re-run this skill.
>
> Verify the fix worked (in any terminal, no admin needed):
> ```cmd
> reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled
> ```
> The output must show `LongPathsEnabled    REG_DWORD    0x1`.
>
> Full context: [`docs/windows-considerations.md`](../docs/windows-considerations.md).

Stop the skill. Do not proceed until the user confirms the fix has been applied and re-runs the skill.

## Step 4 — Manual fallback if powershell.exe is unavailable

If the `powershell.exe` invocation in Step 2 produced "command not found" or any other error, the skill cannot detect the registry value automatically. Show the user this message:

> **Could not automatically check Windows Long Path support.**
>
> Please run this command in any terminal (Command Prompt or PowerShell, no admin needed):
> ```cmd
> reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled
> ```
>
> Reply with the value:
> - `0x1` → safe, the skill will proceed
> - `0x0`, missing, or "unable to find the specified registry key" → STOP, see Step 3 above for the fix
>
> Full context: [`docs/windows-considerations.md`](../docs/windows-considerations.md).

Wait for the user to reply with the value. Proceed only on `0x1`.

## Step 5 — Trailing-Dot Folder Detection (Windows only)

`LongPathsEnabled = 1` does not solve every Windows enumeration problem. Win32 path normalization independently strips trailing `.` and trailing space characters from path components — so a folder named `030_Systems - reference material.` is unreachable via stock `Get-ChildItem -Recurse` regardless of the long-path flag. Empirical case (GR-3 nexus-clone-robocopy 2026-05-01): 670 files / 301 markdown silently invisible inside one such folder; affects any vault with PARA-style sentence-ending folder names.

This is **enumeration step 5**, not a STOP-gate: emit a WARN with the offending folder names listed, then proceed using the Windows-aware enumeration pattern in Step 6. The WARN gives the user visibility before downstream skills act on a partial view of the vault.

```bash
# Detect at preflight time. Run only when IS_WINDOWS=1.
powershell.exe -NoProfile -Command "
  Get-ChildItem -Path \$env:OBSIDIAN_VAULT_PATH -Directory -Recurse |
    Where-Object { \$_.Name -match '\\.\$' -or \$_.Name -match ' \$' } |
    Select-Object -ExpandProperty FullName
" 2>/dev/null
```

If the result is non-empty, list the offending folders to the user as a portability-risk WARN (not a STOP). Sample message:

> **Portability warning:** Found N folder(s) whose names end in `.` or trailing whitespace. Stock PowerShell enumeration cannot descend into these folders. The skill will use Windows-aware enumeration (extended-path prefix `\\?\`) for the rest of this run. Affected folder(s):
> - `030_Systems - reference material.`
> - …

The skill proceeds. Step 6 governs how subsequent enumeration calls are issued.

## Step 6 — Windows-aware Enumeration Pattern

Whenever a skill enumerates files (the `Scan` step, the `Check backlinks` step, the `List inbox-tree files` step, etc.), it must use a pattern that survives Win32 trailing-dot/trailing-space normalization. The pattern depends on the platform.

### PowerShell (Windows)

Stock `Get-ChildItem -Recurse` is **not** safe — it strips trailing dots from any path component before calling the underlying API.

Use `[System.IO.Directory]::EnumerateFiles` with an `\\?\`-prefixed path. The `\\?\` prefix instructs the OS to skip path normalization entirely, treating the path as already-normalized. This works for both short (<260 char) and long paths and preserves trailing dots and spaces.

```powershell
$vault = (Resolve-Path $env:OBSIDIAN_VAULT_PATH).Path
[System.IO.Directory]::EnumerateFiles("\\?\$vault", '*.md', 'AllDirectories')
```

This works in PowerShell 5.1 (Windows-default) and PowerShell 7+. The returned paths are also `\\?\`-prefixed; strip the prefix when displaying to the user, but pass the prefixed form to subsequent file APIs (`Get-Content`, `[System.IO.File]::ReadAllText`, etc.) for consistency.

### Python (Windows)

`pathlib.Path` rejects `\\?\`-prefixed paths in some interpreter versions; use `os.scandir` / `os.walk` against an `\\?\`-prefixed absolute path string, then convert back to `pathlib.Path` if needed:

```python
import os
# The Win32 extended-path prefix is the 4-character literal: \ \ ? \
PREFIX = '\\\\?\\'  # in Python source: four escaped backslashes + question mark
abs_path = os.path.abspath(vault_path)
walked = os.walk(PREFIX + abs_path)
```

Strip the prefix (`path.removeprefix('\\\\?\\')`) before display. Raw strings (`r'...'`) cannot represent the prefix directly because Python raw-string literals cannot end with an odd number of backslashes — use the escaped form above.

### Bash / find (macOS, Linux)

Pass-through. Trailing-dot folders are valid POSIX names and `find` enumerates them without special handling. No changes required:

```bash
find "$OBSIDIAN_VAULT_PATH" -type f -name '*.md'
```

### Cross-platform decision shorthand

Inside any skill that does enumeration, branch on `IS_WINDOWS` (set by Step 1):

| `IS_WINDOWS` | Enumeration approach |
|---|---|
| `0` (macOS / Linux) | `find` or any standard enumerator. No prefix needed. |
| `1` (Windows) | `[System.IO.Directory]::EnumerateFiles("\\?\$path", '*', 'AllDirectories')` or equivalent extended-path-prefixed call. |

## Step 7 — Clone-Cluster Birthtime Detection

> **WARN-flow, not STOP-flow.** This step emits a non-blocking warning when a clone-induced birthtime cluster is detected, so the user understands why date-derivation skills will SKIP affected files at runtime. Skill execution **continues**. The runtime SKIP-gate documented in [`clone-cluster-detection.md`](clone-cluster-detection.md) is the data-safety mechanism; this preflight is transparency, not enforcement.

Run the detector against the configured vault root (cross-platform — works on macOS, Linux, and Windows under MSYS / Git Bash):

```bash
eval "$(scripts/detect-clone-cluster.sh "$OBSIDIAN_VAULT_PATH")"
```

This sets `CLUSTER_FOUND` and, when the value is `yes`, additionally sets `CLONE_CLUSTER_WINDOW_START`, `CLONE_CLUSTER_WINDOW_END`, and `CLUSTER_FILE_COUNT`.

| `CLUSTER_FOUND` | Action |
|---|---|
| `no` | Silent. Continue to the skill's normal workflow. |
| `yes` | Emit the WARN message below, then **continue** with the skill's normal workflow. The runtime SKIP-gate handles correctness. |

WARN message text (display verbatim, substituting the captured values, then proceed):

> **Clone-cluster birthtime detected (informational, not blocking).**
>
> [`$CLUSTER_FILE_COUNT`] files share filesystem birthtimes inside `[$CLONE_CLUSTER_WINDOW_START]..[$CLONE_CLUSTER_WINDOW_END]`. This pattern indicates the vault was recently cloned or restored — birthtimes reflect clone-time, not the original note-creation time.
>
> Date-derivation skills (`property-enrich`, `note-rename`, `inbox-sort`, `property-describe`) will automatically SKIP files in this window when no alternate date source (YAML `created`, `YYYY-MM-DD` filename, git first-commit) is available. Affected files will appear in each skill's findings file as **Class C — clone-cluster birthtime, no alt source**.
>
> Full mitigation behavior: [`references/clone-cluster-detection.md`](clone-cluster-detection.md).

After emitting the WARN, proceed with the skill's core workflow.

### Why this preflight is empirical, not theoretical

The GR-3 strict-path validation on `nexus-clone-robocopy` (2026-05-01) found 36.8 % (189 / 514) of inbox-tree files clustered at `2026-04-16T20:33:23Z` — the vault's clone time. `robocopy /E /COPY:DAT` was supposed to preserve `CreationTime` from the source; empirically it did not (post-clone Defender / Indexer / Obsidian-cache resets, or robocopy's Windows CreationTime semantics being unreliable in practice). This preflight surfaces the same reality to the user before any date-derivation runs, so the runtime SKIPs (which appear as Class-C findings) are not a surprise.

## Test fixture for this preflight

Two regression-locks cover this preflight:

- **Trailing-dot enumeration (Step 5):** `tests/fixtures/windows-trailing-dot/` — folder named `030_Systems - reference material.` with two notes inside plus two notes outside, exercising both directions of the backlink-update path. Run `scripts/test-windows-trailing-dot.sh`. The Windows-side empirical verification (broken pattern fails, fixed pattern succeeds) is documented in the fixture's `README.md` — run on a Windows host before merging any change to enumeration in the four launch-scope skills.
- **Clone-cluster detection (Step 7):** `tests/fixtures/clone-cluster/` — 30-file synthetic vault (W2 fixture, reused). Run `scripts/test-clone-preflight.sh` to assert that `scripts/detect-clone-cluster.sh` emits `CLUSTER_FOUND=yes` against the cluster fixture, `CLUSTER_FOUND=no` against a sub-floor (5-file) directory and against an empty directory, and that the cross-doc claims in `windows-considerations.md` and `cloning-guide.md` reflect empirical reality (no `robocopy /COPY:DAT preserves CreationTime` claim).

## What this preflight does NOT check

- **Path lengths in the actual vault.** If LongPathsEnabled is `1`, all paths are accessible regardless of length. No per-path scan is needed.
- **Whether the vault was cloned at all in the absence of a birthtime cluster.** A small clone (< 10 files) or a clone that occurred far enough in the past that other write activity has spread birthtimes across multiple bins will not trigger Step 7. The runtime SKIP-gate in `clone-cluster-detection.md` is the same threshold; both are intentionally biased toward false-negatives over false-positives. See [`docs/cloning-guide.md`](../docs/cloning-guide.md) for clone-method recommendations.

## Cost

On Windows: one `powershell.exe` invocation per skill run for Steps 2 + 5 (~100-300 ms combined) plus one Step 7 detector pass (one `find` + one `awk` + per-file `stat`, ~50-150 ms on a 1 000-file vault). On macOS / Linux: one `uname -s` call (~1 ms) plus the Step 7 detector pass. The check is cheap enough to run every invocation.
