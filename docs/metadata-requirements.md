# Metadata Requirements

> Skills depend on YAML frontmatter — especially the `created` field.

Detailed metadata requirements, the `created` source hierarchy, and troubleshooting for common issues are coming soon.

**Key requirement:** Every note should have a YAML `created` field. Without it, skills fall back to filesystem birthtime, which is unreliable after copying, cloning, or syncing.

```yaml
---
created: 2026-01-15T10:30:00
title: My Note Title
modified: 2026-04-10T14:22:00
---
```

The `property-enrich` skill can fill missing `created` fields automatically. Run it first on a fresh vault.

---

*This guide is being written. Follow the [repo](https://github.com/neckarshore-ai/obsidian-vault-autopilot) for updates.*
