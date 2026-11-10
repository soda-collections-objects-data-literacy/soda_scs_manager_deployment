# SODa SCS Manager deployment

The rules are written once, in `.cursor/rules/*.mdc`, for Cursor and Claude Code.
`.claude/rules/` links to them, so Claude Code loads them by itself:
`stack-operations` and `clean-code` always, the others when you open a file that
matches their `paths:` (changelog, docs, Docker, PHP/Drupal, CSS, theming,
Python, TypeScript, logging). Each rule file lists its patterns twice: `globs:`
for Cursor, `paths:` for Claude Code. Keep the two lists the same, and add a
link in `.claude/rules/` for every new rule.

The skills live in `.cursor/skills/`; `.claude/skills/` only links to them.

Skills (the user starts them): `/update-stack`, `/git-commit`, `/release` (one
repo), `/scs-release-prep` (all SCS repos, push plan and manual steps).

Subagents in `.claude/agents/` run on cheaper models. Hand them the reading-heavy
work and keep decisions and anything that changes containers yourself:

| Agent | Use it for |
| --- | --- |
| `log-triage` | container status and logs: why is a service unhealthy, what do the logs say |
| `repo-inventory` | git state of the deployment, submodules, module and theme (step 1 of `/scs-release-prep`, before `/update-stack`) |
| `docs-sync` | comparing `docs/en` with `docs/de` and the three `zensical*.toml`, translating pages |

Host-specific notes (dev or Prime) are in `CLAUDE.local.md`, which is not in git.
