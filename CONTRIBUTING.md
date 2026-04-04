# Contributing

Thanks for your interest in Obsidian Vault Autopilot.

## Reporting Issues

Open a [GitHub issue](https://github.com/neckarshore-ai/mmp-obsidian-vault-autopilot/issues) with:

1. **What you expected** to happen
2. **What actually happened** (include the skill report output if available)
3. **Your setup** — OS, Claude Code version, vault size (approximate number of notes)

## Pull Requests

1. Fork the repo and create a feature branch
2. Follow the existing skill structure (`skills/skill-name/SKILL.md`)
3. Ensure your skill passes the quality checklist in `CLAUDE.md`
4. Open a PR with a clear description of what the skill does and why

### Skill Quality Checklist

Before submitting a skill PR, verify:

- [ ] SKILL.md has valid YAML frontmatter (`name`, `description`)
- [ ] Description includes 3+ trigger phrases
- [ ] No hardcoded vault paths (use `${OBSIDIAN_VAULT_PATH}`)
- [ ] Output format follows Core + Nahbereich + Report principle
- [ ] Skill is focused — one job, done well

## Code of Conduct

Be kind, be constructive, be patient. We are building tools for knowledge workers,
not fighting about tabs vs. spaces.

## License

By contributing, you agree that your contributions will be licensed under MIT.
