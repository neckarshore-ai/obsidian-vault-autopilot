# Test Fixture — Windows Trailing-Dot Folder Enumeration (F-NEW-A-1)

## Purpose

Regression-lock for **F-NEW-A-1** — the Class-A Public-Flip-blocker discovered during the GR-3 strict-path validation on 2026-05-01: stock PowerShell `Get-ChildItem -Recurse` (and `[System.IO.Directory]::EnumerateFiles` without the `\\?\` extended-path prefix) silently returns "Path not found" for any folder name ending in a `.`. Win32 path normalization strips trailing dots and trailing spaces unless the path is prefixed with `\\?\`, which bypasses normalization entirely.

Affected folder shape on the empirical case: `030_Systems - WHAT SUPPORTS IT - Stable knowledge, models, frameworks, and reference material.` — the trailing dot is the period that closes the sentence-style PARA folder name. This is a very common shape for any user with descriptive PARA-style folder names.

`LongPathsEnabled = 1` does **not** fix this. It is a separate Win32 normalization issue, not a path-length issue.

## Fixture Layout

```
tests/fixtures/windows-trailing-dot/
├── README.md                                      this file
├── note-pointing-in.md                            outside the trailing-dot folder; links to target-inside
├── target-outside.md                              outside; link target for note-with-link
└── 030_Systems - reference material./             trailing-dot folder
    ├── note-with-link.md                          inside; links to target-outside
    └── target-inside.md                           inside; link target for note-pointing-in
```

The structure exercises **both** directions of the backlink-update path:

1. **Inside → Outside.** `note-with-link.md` lives inside the trailing-dot folder and links to a target outside it. To find this file at all (and to update its wikilink when `target-outside` is renamed), enumeration must descend into the trailing-dot folder.
2. **Outside → Inside.** `note-pointing-in.md` lives outside and links to a target inside the trailing-dot folder. To rename `target-inside.md` and update incoming wikilinks, the enumeration that finds `target-inside.md` must descend into the trailing-dot folder.

Without F-NEW-A-1's fix, both files inside the folder are invisible to the skill, both rename and backlink-update silently miss them, and the wikilinks in the surviving files break.

## Verification on the Three Platforms

### macOS / Linux

The bug does not exist on these platforms. The fixture's role here is to:
- Verify the test runner's contract (`scripts/test-windows-trailing-dot.sh`)
- Guard against accidental fixture decay (someone deletes the trailing-dot folder, the test catches it)
- Document the canonical fixture shape for cross-team reference

Run: `scripts/test-windows-trailing-dot.sh` from the repo root. Expect `PASS`.

### Windows

The bug is empirically reproducible. Manual procedure for v0.1.4 W1 PR review until the OVA repo grows a Windows CI runner:

1. Clone the repo on a Windows host. **Important:** check `git config --get core.protectNTFS` first — it defaults to `true` on Windows-Git and may refuse to check out the trailing-dot folder. If checkout fails with a path error, set `git config core.protectNTFS false` before re-cloning. (See PR description for the rationale.)
2. From PowerShell, attempt the broken pattern:
   ```powershell
   Get-ChildItem -Path "tests\fixtures\windows-trailing-dot\030_Systems - reference material." -Recurse
   ```
   Expected: `Path not found` or empty result. **This demonstrates the bug.**
3. Now attempt the fixed pattern:
   ```powershell
   $path = (Resolve-Path "tests\fixtures\windows-trailing-dot\030_Systems - reference material.").Path
   [System.IO.Directory]::EnumerateFiles("\\?\$path", '*', 'AllDirectories')
   ```
   Expected: `note-with-link.md` and `target-inside.md` returned. **This demonstrates the fix.**
4. Document the result (PASS / FAIL) in the PR comments.

## Cross-References

- [`references/windows-preflight.md`](../../../references/windows-preflight.md) — runtime guidance the skills consume; documents the enumeration pattern and trailing-dot detection.
- [`docs/windows-considerations.md`](../../../docs/windows-considerations.md) — the user-facing Windows handbook; the trailing-dot guidance lives in the "Windows Considerations" section.
