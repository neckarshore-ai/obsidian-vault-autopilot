# Launch Plan — Vault Autopilot v0.1.0

## Context

Karpathy's "LLM + Obsidian" approach is going viral. Our product is exactly that — but finished and installable. The window closes in 1-2 weeks.

This plan replaces the original KW 17 plan. Provenance, tag-manage, and community templates are deferred to v0.2.0.

## Launch Phases

### Phase 1: Skill Testing — CLI (current)

**Goal:** Every launch skill passes a formal test run against the Nexus vault via CLI.

| # | Skill | Test Status | Notes |
|---|-------|-------------|-------|
| 1 | note-rename | In progress | Last test: ~100 files, 1 duplicate trashed. Needs clean formal run. |
| 2 | inbox-sort | Not started | 64 notes informally tested. Needs formal run. |
| 3 | Third skill TBD | Deferred | Decide after rename + sort are green. Candidate: property-enrich. |

**Test protocol per skill:**
1. Snapshot vault state before (file list, frontmatter, links)
2. Run skill with user confirmation at every step
3. Verify: no data loss, correct behavior, skill log written, backlinks intact
4. Document results in test report

**Definition of Done — Phase 1:**
- Both skills pass formal CLI test
- Test results documented
- Any bugs found are fixed and re-tested

### Phase 2: Cross-Platform Smoke Tests

**Goal:** Verify skills trigger and execute correctly on all supported platforms.

**Prerequisite:** Phase 1 complete (CLI tests green).

#### Platform Support Matrix

| # | Platform | Support Level | Test Type | Priority |
|---|----------|--------------|-----------|----------|
| 1 | Claude Code CLI (Terminal) | Full | Formal test (Phase 1) | P0 |
| 2 | VS Code Extension | Full | Smoke test | P0 |
| 3 | Claude Desktop App | Full | Smoke test | P0 |
| 4 | JetBrains IDEs | Full | Smoke test | P2 |
| 5 | claude.ai/code (Web Editor) | Limited | Smoke test if possible | P3 |
| 6 | claude.ai (Chat) | Not supported | N/A | N/A |

**Key insight:** All platforms share the same Claude Code engine. The skill logic is identical — only the interface differs. Therefore:
- CLI = full test (validates all logic)
- Other platforms = smoke test (validates trigger + execution, not logic)

#### Smoke Test Checklist (per platform)

1. Plugin is discovered (skill appears in available commands)
2. Skill triggers correctly (via trigger phrase or slash command)
3. Skill reads vault path from environment variable
4. Skill produces output (report format correct)
5. No platform-specific errors

#### Automation Opportunity (post-launch)

A **Vault-State-Diff-Script** can automate the structural verification:
1. Snapshot vault before (file list, frontmatter, backlinks)
2. Skill runs (on any platform)
3. Snapshot vault after
4. Diff: renames correct, trash correct, backlinks intact, skill log present

This is platform-independent because it checks output, not UI. Build this after launch when test volume justifies the investment.

### Phase 3: Documentation and README

**Goal:** A new user can install and run their first skill within 5 minutes.

| # | Deliverable | Description |
|---|-------------|-------------|
| 1 | README (slim) | What it is, skill table, quick install, link to Getting Started |
| 2 | `docs/getting-started.md` | Step-by-step: clone, configure vault path, run first skill |
| 3 | Skill table in README | Only launch skills (stable). Roadmap section for upcoming skills. |
| 4 | Platform support note | Which platforms are supported (see matrix above) |

### Phase 4: Final Cleanup and Ship

| # | Task | Effort |
|---|------|--------|
| 1 | SKILL.md frontmatter: `status: stable` on launch skills | XS |
| 2 | plugin.json: version `0.1.0`, repo URL correct | XS |
| 3 | Remove WIP/TODO markers from all skill files | XS |
| 4 | Git log review — no embarrassing commit messages | XS |
| 5 | Repo → public | XS (User) |
| 6 | Gary: LinkedIn launch post | Separate session |

## Decisions Made

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Launch with 2-3 stable skills only (no beta) | Better impression with fewer solid skills than many broken ones |
| 2 | note-rename and inbox-sort are confirmed launch skills | Highest value, most tested |
| 3 | Third skill (property-enrich) decided after Phase 1 | Test first, decide with data |
| 4 | README slim + Getting Started linked | One doc for discovery, one for doing |
| 5 | CLI is the formal test, other platforms get smoke tests | Same engine, different UI |
| 6 | Playwright automation deferred to post-launch | ROI not there yet for 2-3 skills |
| 7 | tag-manage deferred to v0.2.0 | Too complex for MVP |
| 8 | Provenance/skill-log deferred to v0.2.0 | No user expects audit trails on day 1 |

## Open Questions

| # | Question | Decides What | When |
|---|----------|-------------|------|
| 1 | Does property-enrich make the launch cut? | 2 vs 3 skills | After Phase 1 |
| 2 | Exact Getting Started content | User documentation | Phase 3 |
| 3 | Vault-State-Diff-Script scope | Test automation depth | Post-launch |
