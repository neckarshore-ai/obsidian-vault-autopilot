# Cloning Guide

> **Test on a copy first.** Clone your vault and run skills there before touching production.

Detailed cloning instructions per operating system (macOS, Windows, Linux), best practices for metadata preservation, and common pitfalls are coming soon.

**Quick start:** Copy your vault folder to a new location and point the skill at the copy.

| # | OS | Recommended method | Preserves metadata |
|---|----|--------------------|-------------------|
| 1 | macOS | `ditto -V /source /destination` | ✅ Yes (birthtimes) |
| 2 | Windows | File Explorer copy or `robocopy /COPY:DAT` | ⚠️ Partial |
| 3 | Linux | `cp -a /source /destination` | ⚠️ Partial (no birthtime) |

---

*This guide is being written. Follow the [repo](https://github.com/neckarshore-ai/obsidian-vault-autopilot) for updates.*
