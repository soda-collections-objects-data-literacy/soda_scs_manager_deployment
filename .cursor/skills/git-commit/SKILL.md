---
name: git-commit
description: >-
  Create clean git commit(s) in the SCS deployment, a submodule, the
  soda_scs_manager module or the scs_custom_theme: reviews staged and unstaged
  changes, splits mixed diffs into logical commits, makes sure the changelog has
  an entry for user-facing changes, writes messages in the repo's style and bumps
  submodule pointers. Use when the user asks to commit work.
disable-model-invocation: true
---
# Git commit

Committing only. Tags and version bumps: `/release`. Everything across all SCS
repos at once, ready to push: `/scs-release-prep`.

## Workflow

1. **Inspect** (in parallel): `git status`, `git diff`, `git diff --staged`,
   `git log --oneline -10` for the message style.
2. **Changelog.** User-facing change (feature, fix, behaviour, config, upgrade
   step — not pure refactor/CI/typo) → entry under `## [Unreleased]` in that
   repo's `CHANGELOG.md` (Added/Changed/Deprecated/Removed/Fixed/Security, see
   `.cursor/rules/changelog.mdc`). Admin actions after the update in **bold**.
   No changelog in the repo: mention it, don't create one unasked.
3. **Safety.** Never stage `.env`, `*.env`, `acme.json`, keys, `volumes/`,
   `backups/`, logs, `plans/`, generated `docker-compose.override.yml` copies
   inside stacks, `node_modules/`, build output. Warn instead.
4. **Split.** One logical change per commit, in dependency order (foundation →
   feature → docs/changelog). Ask only when the split is ambiguous.
5. **Stage explicit paths** (no `git add -A`) and commit:

   ```bash
   git commit -m "$(cat <<'EOF'
   Run WissKI updates as queued background jobs.

   Optional body: why, trade-offs, upgrade notes.
   EOF
   )"
   ```

   Subject = **one plain English sentence, imperative, ending with a period**, no
   `feat:`/`fix:` prefix, ≤ 72 characters where possible.
6. **Submodules: innermost first.** Commit inside the submodule, then
   `git add <submodule-path>` in the parent and commit the pointer
   (`Point JupyterHub at the project-mount change.`). Chain:
   `scs_manager_integration` → `scs-nextcloud-stack` → deployment.
   Detached HEAD with changes: ask which branch first.
7. **Verify** with `git status`. A hook changed files → stage them and make a new
   commit, never `--amend` a rejected commit.

## Hard rules

- Never `--no-verify`, never `--amend` or rebase published commits, never force.
- Don't chmod/chown: the repos are group `www-data` with `core.sharedRepository=group`.
- **Don't push.** The SSH key has a passphrase; pushes go through
  `01_scripts/global/push-release-plan.bash`. If the user wants a push, add the
  lines to `plans/push-plan.txt` (`push <path> <remote> <branch>`) and tell them
  to run the script.
