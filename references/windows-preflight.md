# Windows Preflight

Run this procedure **before** the skill's core workflow if the host operating system is Windows. On macOS or Linux, skip the entire procedure — there is nothing to check.

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
> 2. Open PowerShell as Administrator.
> 3. Run:
>    ```powershell
>    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
>    ```
> 4. Close PowerShell.
> 5. Reopen your terminal and re-run this skill.
>
> Verify the fix worked:
> ```powershell
> (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").LongPathsEnabled
> ```
> The output must be `1`.
>
> Full context: [`docs/windows-considerations.md`](../docs/windows-considerations.md).

Stop the skill. Do not proceed until the user confirms the fix has been applied and re-runs the skill.

## Step 4 — Manual fallback if powershell.exe is unavailable

If the `powershell.exe` invocation in Step 2 produced "command not found" or any other error, the skill cannot detect the registry value automatically. Show the user this message:

> **Could not automatically check Windows Long Path support.**
>
> Please run this command in PowerShell yourself:
> ```powershell
> (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").LongPathsEnabled
> ```
>
> Reply with the value:
> - `1` → safe, the skill will proceed
> - `0` or empty → STOP, see Step 3 above for the fix
>
> Full context: [`docs/windows-considerations.md`](../docs/windows-considerations.md).

Wait for the user to reply with the value. Proceed only on `1`.

## What this preflight does NOT check

- **Clone method (Copy-Item vs robocopy).** `CreationTime` reset is a separate concern, handled by `property-enrich`'s Source Hierarchy (filename > git > birthtime). The preflight's job is enumeration safety only.
- **Path lengths in the actual vault.** If LongPathsEnabled is `1`, all paths are accessible regardless of length. No per-path scan is needed.
- **Whether the vault was cloned at all.** That is a different concern documented in `docs/cloning-guide.md`.

## Cost

On Windows: one `powershell.exe` invocation per skill run (~50-200ms). On macOS/Linux: one `uname -s` call (~1ms). The check is cheap enough to run every invocation.
