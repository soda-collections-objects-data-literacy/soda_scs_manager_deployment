# SODa SCS Manager deployment

The project rules live in `.cursor/rules/` and are shared by Cursor and Claude Code.
The skills live in `.cursor/skills/`; `.claude/skills/` only links to them.

Always apply:

@.cursor/rules/stack-operations.mdc
@.cursor/rules/clean-code.mdc

Read the matching rule before you edit these files:

| Files | Rule |
| --- | --- |
| `CHANGELOG.md` | `.cursor/rules/changelog.mdc` |
| `docs/**`, `zensical*.toml`, `README.md` | `.cursor/rules/documentation.mdc` |
| Dockerfiles, compose files, entrypoints | `.cursor/rules/docker.mdc` |
| PHP, `.module`, `.theme`, `.install`, Drupal YAML, composer | `.cursor/rules/php-drupal.mdc` |
| CSS, SCSS, PCSS | `.cursor/rules/css.mdc`, `.cursor/rules/theming.mdc` |
| Python | `.cursor/rules/python.mdc` |
| TypeScript / JavaScript | `.cursor/rules/typescript.mdc` |
| Application code (logging) | `.cursor/rules/logging.mdc` |

Skills: `/git-commit`, `/release` (one repo), `/scs-release-prep` (all SCS repos,
push plan and manual steps). Nothing is pushed from the agent shell: the user runs
`01_scripts/global/push-release-plan.bash`.
