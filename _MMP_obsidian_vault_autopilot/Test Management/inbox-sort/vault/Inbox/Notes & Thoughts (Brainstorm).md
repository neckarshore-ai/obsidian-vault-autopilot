---
tags:
  - Brainstorm
---

# Notes and Thoughts — Workflow Automation Brainstorm

Random ideas for automating repetitive tasks in our development workflow.

## Build Pipeline

- Auto-run linting on pre-commit hook (already have this, but it's slow — parallelize?)
- Cache dependency installation between CI runs (save 2 minutes per build)
- Auto-merge dependabot PRs that pass all checks and only bump patch versions

## Code Review

- Bot that assigns reviewers based on file ownership (CODEOWNERS is too coarse)
- Auto-label PRs by size (XS/S/M/L/XL) based on lines changed
- Slack notification when a PR has been waiting for review > 24 hours

## Documentation

- Generate API docs from code comments on every merge to main
- Sync README examples with actual test fixtures (so examples never go stale)
- Auto-create changelog entries from conventional commit messages

## Monitoring

- Weekly email with error rate trends (up/down/flat compared to last week)
- Alert when any endpoint p99 latency exceeds 500ms for more than 5 minutes
- Dashboard that shows deployment frequency and lead time (DORA metrics)
