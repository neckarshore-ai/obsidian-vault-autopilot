# Vault Autopilot Note — Shared Convention

## Purpose

Every vault managed by this plugin has a `_vault-autopilot.md` file in its root directory. This file is the human-readable dashboard for the plugin: it lists available skills, their last run dates, and links to recent reports.

## Rules for All Skills

1. **Never move** `_vault-autopilot.md`
2. **Never rename** `_vault-autopilot.md`
3. **Never delete** `_vault-autopilot.md`
4. **Never modify content** — only the future `autopilot-update` meta-skill may write to this file
5. **Skip during processing** — when scanning vault root or folders, exclude this file from all skill operations (sorting, renaming, quality checks, property changes, tag changes)

## Detection

Skills must check for `_vault-autopilot.md` in the vault root at startup. If it does not exist, recommend the user create one (do not create it automatically — the user should opt in).

## File Location

Always in vault root: `${OBSIDIAN_VAULT_PATH}/_vault-autopilot.md`

The underscore prefix ensures it sorts to the top in file explorers.

## Template

See `references/vault-autopilot-template.md` for the initial content template.

## Future: Obsidian Base View

In a future version, skill reports will use standardized YAML properties (skill_name, run_date, status, items_processed). An Obsidian Base (`.base` file) can then query these properties to render a dynamic dashboard. This is planned but not required for v0.1.0 — the Markdown note is the source of truth.
