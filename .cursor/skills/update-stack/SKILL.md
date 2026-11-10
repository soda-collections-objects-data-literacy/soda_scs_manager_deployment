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

**Which host?** If `SCS_MANAGER_MODE=production` in `.env` (Prime, `/var/deploy/soda_scs_manager_deployment`), use **[Prime](#prime-production)** below. Everything else (dev) uses the workflow right after this.

## Workflow (dev)

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

## Prime (production)

Prime follows the submodule pointers recorded in the deployment repo, never the newest tag or branch head. That is `--prime`; the dev mode and `start.sh` (`--remote`) are wrong here. Background and the manual steps it automates: `docs/en/technical/maintenance/dev-to-prime.md`.

```
- [ ] Step 1: ./01_scripts/global/update-stack.bash --prime --check
- [ ] Step 2: Show the plan, wait for the user's yes
- [ ] Step 3: ./01_scripts/global/update-stack.bash --prime --apply
- [ ] Step 4: Verify (the script does it, you read it)
- [ ] Step 5: Hand over the manual steps
```

**Step 1: Check.** `--prime --check` changes nothing. Exit code 1 means something blocks the apply. It prints:

- pre-checks: `SCS_MANAGER_MODE` must be `production` (aborts otherwise); `SCS_MANAGER_IMAGE_VERSION` is shown, normally `3` — a full version (e.g. `3.3.1`) pins that release, so no newer manager image arrives. Report it, change `.env` only on request.
- one row per repo: current commit → recorded pointer. `BLOCKED: checkout is not behind the pointer` means the checkout has commits the pointer lacks; following would move it backwards — ask the user.
- commit log per moving repo, override copies (`COPY` / `unchanged` / `MANUAL` when the stack copy has local edits), systemd units (`DIFFERS` / `NOT INSTALLED`) with the `sudo` commands.
- planned builds and recreates, image tag changes, whether the SCS Manager image is updated or `SKIPPED` because of a module/theme bind mount.
- new CHANGELOG sections and **bold** lines (manual steps) of the moving repos.
- the current Drupal checks and the manual steps that will remain.

Git reads over HTTPS when SSH needs a passphrase (SSH runs in batch mode, it never prompts). If a private repo cannot be fetched, ask the user to load the key (`ssh-add`) — never enter a passphrase yourself.

**Step 2: Review.** Summarise for the user: which repos move and why it matters, what is built and recreated, the snapshot, units, and every `BLOCKED` line. Resolve blockers with the user, never by force: uncommitted changes are committed, stashed or reverted by the user — no `reset`, no `checkout --`. **Do not run `--apply` without an explicit yes.**

**Step 3: Apply.** `./01_scripts/global/update-stack.bash --prime --apply` (long timeout or background: builds take minutes, the manager start up to 15 min). It runs, in order:

1. `git merge --ff-only` in the deployment, `git submodule update --init --recursive` (no `--remote`).
2. Copies changed override sources into `scs-manager-stack/` and `scs-project-website-stack/` (only if the copy had no local edits).
3. Systemd units: as root it installs them, otherwise it lists the `sudo` commands as manual steps.
4. Builds services whose build context changed, pulls the manager image.
5. Before the first recreate: a gzip dump of all databases to `/srv/backups/pre-update/<timestamp>/` (`--no-snapshot` skips it, `SCS_UPDATE_BACKUP_DIR` moves it). When the Nextcloud image tag changes, also `backup-nextcloud.bash`. A failed backup stops the run before any container is touched.
6. `docker compose up -d` for running services (only changed ones are recreated), `--force-recreate` for rebuilt or bind-mount-affected ones. Never `docker restart`, never `down`.
7. SCS Manager (path B step 5): only without a module/theme bind mount; `up -d`, follows the log until healthy, reports `Package set changed`, `Shipped content changed` and `ERROR:`.

**Step 4: Verify.** The script checks `docker compose ps` (no `unhealthy`/`Restarting`/`Exited`), `drush updatedb:status`, `drush scs:check --problems` and the enabled themes (only `scs_custom_theme`, `gin`, core; `soda_scs_manager_theme` is gone since module 4.3.0). Exit code 1 = a check failed: read `docker compose logs --tail 100 <service>` and report with excerpts. Do not claim success on a red check. On success it records the applied commit in `.git/update-stack-prime.applied`, the baseline for the next run (`--since <rev>` overrides it).

**Step 5: Manual steps.** Pass the script's checklist on verbatim: `sudo` unit commands, Nextcloud repair after a version change (`01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash`, then `occ app:update --all` — suggest, do not run), override merges, and the **bold** CHANGELOG steps (drush commands, new settings). If you commit anything on Prime, append the push to `plans/push-plan.txt` for `01_scripts/global/push-release-plan.bash`; do not push.

## Notes

- Never run `git submodule update --remote` blindly — it ignores the per-submodule release/branch policy.
- New pinned image versions in `.env` (e.g. `SCS_MANAGER_IMAGE_VERSION`) are not bumped by the script; mention newer releases if seen in commit logs, but change `.env` only on request.
- Permission errors on files owned by `www-data`: see `01_scripts/scs-manager-stack/fix-www-data-shared-edit.bash`; do not `chown` blindly.
- `--offline` re-plans against already fetched refs without network access.
