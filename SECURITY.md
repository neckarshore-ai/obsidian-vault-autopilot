# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

Only the current release receives security updates.

## Scope

Obsidian Vault Autopilot is a **local-only** plugin. It runs entirely on your machine
inside Claude Code. No data is transmitted to external servers. No cloud services are
involved.

The plugin reads and writes files within your configured `OBSIDIAN_VAULT_PATH`. It does
not access files outside that path.

## Reporting a Vulnerability

Report security issues via [GitHub Issues](https://github.com/neckarshore-ai/obsidian-vault-autopilot/issues).

Include:

1. **What you found** — describe the vulnerability
2. **How to reproduce** — steps to trigger the issue
3. **Impact** — what could go wrong if exploited

**Response time:** Best-effort. This is a solo-maintained open-source project, not a
commercial service with an SLA.

**No separate email channel.** Since the plugin runs locally with no network component,
GitHub Issues provides sufficient visibility and tracking for security reports.
