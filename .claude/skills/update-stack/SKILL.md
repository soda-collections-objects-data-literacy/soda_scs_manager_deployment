---
name: update-stack
description: >-
  Update the running deployment: check the deployment repo and every submodule
  for new commits or releases, fast-forward them, rebuild services whose build
  context changed, pull new images, recreate/restart affected containers and
  verify health. Use when the user asks to update, upgrade, pull, sync or
  refresh the stack, the deployment or the submodules.
disable-model-invocation: true
---
# Update stack (repos → build → restart)

All mechanics live in `01_scripts/global/update-stack.bash`. Do not hand-roll `git pull` / `docker compose` sequences — run the script, read its output, and handle what it reports.

## Workflow

```
- [ ] Step 1: Check (read-only)
- [ ] Step 2: Review the plan with the user
- [ ] Step 3: Apply
- [ ] Step 4: Verify
- [ ] Step 5: Handle submodule pointers
```

**Step 1: Check.** From the repo root:

```bash
./01_scripts/global/update-stack.bash --check
```

It fetches all remotes and prints one row per repo:

| Column | Meaning |
|--------|---------|
| `MODE` | `release` = submodule sits on a SemVer tag → moves to the newest tag. `branch` = fast-forwards its branch's upstream (detached → default branch). Override per submodule in `.gitmodules` with `scs-track = release` or `scs-track = branch`. |
| `STATE` | `UPDATE (+n)`, `up-to-date`, or `SKIP: <reason>` |

Followed by the commit log per updated repo and the **planned actions**: services to rebuild (changed files inside a build context or its Dockerfile), services to restart (changed bind-mounted config) and whether compose files changed.

**Step 2: Review.** Summarise for the user: which repos move, notable commits (breaking changes, migrations, version bumps), which services will be rebuilt/restarted. Resolve `SKIP` states before applying, never by force:

| SKIP reason | Action |
|-------------|--------|
| `dirty` | Show `git -C <path> status`/`diff`. Ask: commit (use `/git-commit` in that repo), stash, or leave the repo out. Never `reset`/`checkout --` without explicit consent. |
| `diverged` | Local commits not on the remote. Show `git log --oneline --left-right HEAD...<target>`; ask the user (push / rebase / leave). |
| `fetch-failed` | Usually SSH: `ssh -T git@github.com`. In Cursor remote sessions a stale `SSH_AUTH_SOCK` is common — ask the user to run the script in their own terminal. |
| `no-remote-branch` / `no-tags` / `uninitialized` | Report; `git submodule update --init <path>` for uninitialized. |

If nothing has updates and no images should be pulled, stop here. If the user only asked to check, stop here.

**Step 3: Apply.** After the user confirms (this restarts production containers):

```bash
./01_scripts/global/update-stack.bash --apply            # everything
./01_scripts/global/update-stack.bash --apply --no-images   # repos only, keep image tags as they are
./01_scripts/global/update-stack.bash --apply --only scs-health,scs-voyager
```

Builds can take minutes (webprotege/maven, voyager/npm): use a long timeout or run in the background. What `--apply` does:

1. `git merge --ff-only` for the deployment repo; initialises only *new* submodules (never resets existing ones back to the recorded pointer).
2. Per submodule: checkout newest tag (`release`) or fast-forward (`branch`), then nested `submodule update`.
3. `docker compose pull --ignore-buildable` for running services (skip with `--no-images`).
4. `docker compose build` for affected services, then `docker compose up -d` on running services (compose recreates only changed ones), force-recreates rebuilt ones, restarts bind-mount-affected ones not already recreated.
5. Services defined but not running are left untouched and listed.

**Step 4: Verify.** The script warns about `unhealthy`/`Restarting`/`Exited` services. For each: `docker compose logs --tail 100 <service>`. Also check `docker compose ps` for the recreated ones, and the SCS system check (scs-health) if reachable. Report failures with log excerpts — do not claim success on a red service.

If a rebuilt service fails, offer a rollback: `git -C <path> checkout <FROM-sha>` (from the table), rebuild and recreate that one service.

**Step 5: Submodule pointers.** Moving submodules leaves modified pointers in the deployment repo (script lists them). Ask whether to commit them; if yes use `/git-commit` (message like `Update scs-voyager to v0.68.0 and scs-health to main@abc1234.`). Push only if asked.

## Notes

- Never run `git submodule update --remote` blindly — it ignores the per-submodule release/branch policy.
- New pinned image versions in `.env` (e.g. `SCS_MANAGER_IMAGE_VERSION`) are not bumped by the script; mention newer releases if seen in commit logs, but change `.env` only on request.
- Permission errors on files owned by `www-data`: see `01_scripts/scs-manager-stack/fix-www-data-shared-edit.bash`; do not `chown` blindly.
- `--offline` re-plans against already fetched refs without network access.
