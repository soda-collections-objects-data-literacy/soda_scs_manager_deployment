---
name: scs-release-prep
description: >-
  Prepare all pending SCS changes for shipping: scan the deployment, its
  submodules, the soda_scs_manager module, the scs_custom_theme, the
  scs-manager-image repo and the WissKI base image and stack; find what was committed since each repo's last
  release; write changelog entries, commit cleanly, cut
  releases/tags where needed, write a push plan the user runs with one script
  (SSH key has a passphrase), hand the Prime rollout to /prime-deploy and list
  every manual step left (drupal.org release node, CI checks, sudo/console work
  on Prime) before the releases show up. Use when the user
  asks to "prepare a release", "get everything ready to push", "Release
  vorbereiten", or wants dev changes ready for Prime.
disable-model-invocation: true
---
# SCS release prep

Goal: every SCS change is committed, documented in the changelog, released or
tagged where Prime needs it, and listed in `plans/push-plan.txt`, together with
every manual step that CI does not do. **You never push.** The user runs:

```bash
01_scripts/global/push-release-plan.bash --dry-run   # offline preview
01_scripts/global/push-release-plan.bash             # one passphrase, all pushes
```

Prime is rolled out from here afterwards with `/prime-deploy` (`ssh prime
check` / `apply`, WissKI version, checks). It needs everything pushed, so it
always comes after the push plan, never inside it. The plan names only what
`/prime-deploy` cannot do (sudo, consoles, secrets, free `drush`/`occ`).

Background: `docs/de/technical/maintenance/dev-to-prime.md` (Weg A = deployment
+ submodules, Weg B = module, theme, pages, image). Read it first; it wins over
this file. Commit and tag conventions: `.cursor/skills/git-commit` and
`.cursor/skills/release` (same rules, summarized below).

## Scope

All paths relative to `/var/www/deploy/soda_scs_manager_deployment`.

| Repo | Path | Branch | Remote(s) | Release | CI |
| --- | --- | --- | --- | --- | --- |
| Deployment | `.` | `main` | `origin` | none by default | none |
| JupyterHub | `jupyterhub` | `main` | `origin` | **tag `X.Y.Z`** when `[Unreleased]` has content since the last tag (changelog required); `gh-release` after push | none |
| Voyager | `scs-voyager` | `main` (rolling; never leave detached at an upstream `v*` tag) | `origin` (fork), `upstream` = Smithsonian/dpo-voyager | **tag plain `X.Y.Z`** when cutting a release (mirror upstream without the `v` prefix, or bump for SCS-only changes); `gh-release` after push | none (image built by Compose) |
| Other submodules | every other path from `git submodule status --recursive` (keycloak, open_gdb, scs-health, scs-manager-stack, scs-nextcloud-stack + `apps/scs_manager_integration`, scs-project-website-stack, webprotege) | the branch checked out | `origin` | only if the repo already has version tags and the user wants one | only open_gdb (images) |
| Module | `scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager` | `4.x` | `origin` = git.drupal.org, `fork` = GitHub | **tag `4.x.y`** when it changed since the last tag | drupal.org packages a tag **only after a release node exists** (manual) |
| Theme | `scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme` | `main` | `origin` | none (image clones `main`) | none |
| Image | `repos/scs-manager-image` | `main` | `origin` (https, pushed over SSH) | **tag `3.x.y`** whenever module, theme, shipped content or the image changed. If the image raises its module constraint (`SODA_SCS_MANAGER_VERSION`), even its `main` push waits for that module release on drupal.org, or the `:main` build fails | GitHub Actions builds `:main` on push and `X.Y.Z`/`X.Y`/`X` on a tag; `gh-release` creates the GitHub Release object |

The manager UI styles live in the theme (`assets/scss/manager/` → committed
`assets/css/styles.css`); the module ships no CSS. If the SCSS changed, rebuild
before committing (`docker exec -u developer -w /opt/drupal/web/themes/custom/scs_custom_theme manager--drupal--app npm run build`;
no Node on the host) and commit the CSS with the source. A module release that
relies on new theme classes needs the theme pushed to `main` first, then the
image tag, so Prime never gets the module without its styles.

Module and theme live in gitignored volume paths: separate repos, not
submodules.

The WissKI base image and stack are in scope as well:

| Repo | Path | Branch | Remote | Release | CI / consumers |
| --- | --- | --- | --- | --- | --- |
| WissKI base image | `repos/wisski-base-image` | `main` | `origin` GitHub (SSH) | **tag `X.Y.Z`** when it changed since the last tag (plain; ignore the old `vX.Y.Z` tags when finding the latest) | GitHub Actions builds `wisski-base-image-{production,development}`: `:main` on push, `X.Y.Z`/`X.Y`/`X` on a tag |
| WissKI base stack | `repos/wisski-base-stack` | `main` | `origin` GitHub (HTTPS) | **tag `X.Y.Z`** when it changed since the last tag | no CI; Portainer clones it by git ref |

Order: image and stack tags first, then on Prime the WissKI version entry
(image and stack tag) and `defaultVersion`. `/prime-deploy` step 5 does both
(`ssh prime wisski-version-add` / `wisski-set-default`) with the values that
`apply` prints; no separate `todo` needed.

Out of scope: the WissKI Drupal module (drupal.org/project/wisski) and its
issues, `wisski_default_data_model`, `drupal_packages`, `scs-varnish-image`,
`nextcloud_webdav_mount` and `roBot_rules` under `repos/`.

Issue work (`issue-flow`, `issue-commit` in the module) commits and pushes but
never releases; this skill is where those commits become releases.

## Workflow

```
- [ ] 1. Inventory (read-only)
- [ ] 2. Show the plan, get one confirmation
- [ ] 3. Commit, innermost repo first
- [ ] 4. Changelogs + releases/tags
- [ ] 5. Submodule pointers + deployment commit
- [ ] 6. Collect the manual steps
- [ ] 7. Write plans/push-plan.txt, dry-run, report
```

### 1. Inventory

For every repo in scope (parallel where possible). `git fetch origin` would ask
for the passphrase; for public GitHub repos fetch read-only over HTTPS instead, so
a remote that moved ahead (e.g. a commit pushed from Prime) shows up before the
push is rejected:
`git fetch -q https://github.com/<owner>/<repo>.git <branch>:refs/remotes/origin/<branch>`.
If the remote is ahead and the local commits are unpublished, rebase them onto
`origin/<branch>`; if both sides have published work, ask.

- `git status --short`, current branch (detached HEAD?), `git rev-list --count @{u}..HEAD`
- latest tag `git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1`
  (plain `X.Y.Z`; skips old `v`-prefixed tags), `git log --oneline <tag>..HEAD`
- commits since that tag that reference issues (`Issue #`, `Related:`):
  group the plan and the changelog by them
- `CHANGELOG.md` present? What does `[Unreleased]` say? Does the latest tag's
  commit contain a rolled `## [X.Y.Z]` section (`git show <tag>:CHANGELOG.md`)?
- submodules: does the parent record an older pointer? (`git -C <parent> diff --submodule=log -- <path>`)
- module: is the latest tag published? `curl -fsS https://updates.drupal.org/release-history/soda_scs_manager/current | grep -o '<version>[^<]*'`.
  A tag on git.drupal.org without a release there is a missing release node.

If module or theme changed pages, menus or content types, ask whether
`scs_custom_theme/content/export-content.bash` should run (needs the running dev
container `manager--drupal--app`). Run it only on a yes.

### 2. Plan + confirmation

One compact table: repo → commits (grouped), changelog entry, new tag with SemVer
reasoning, push lines, manual steps. Ask **once**, including every judgment call
(bump level, tagging a submodule, unclear files). Don't ask again unless
something unexpected comes up.

### 3. Commit (innermost first)

Order: `scs_manager_integration` → other submodules → module → theme → image →
deployment last.

- Split mixed diffs into logical commits; stage explicit paths, never `git add -A`.
- Message: **one plain English sentence in the imperative, ending with a period**
  (`Run WissKI updates as queued background jobs.`), no conventional-commit
  prefix. Optional body says why.
- Never commit secrets or local state: `.env`, `*.env`, `acme.json`, keys,
  `docker-compose.override.yml` copies inside stacks, `volumes/`, `backups/`,
  logs, `plans/`. Warn instead.
- Detached HEAD with changes: stop and ask which branch. Without changes: leave it.
- Hook changed files: stage them, new commit, never `--amend`. Never `--no-verify`,
  never rewrite history, never move or delete a tag.
- Files are group `www-data` with `core.sharedRepository=group`; don't chmod/chown.
- The deployment has `core.fileMode=false`: a new script needs
  `git update-index --chmod=+x <file>`, or it loses its exec bit on the next checkout.

### 4. Changelogs + releases

**Changelog** (Keep a Changelog 1.1, `.cursor/rules/changelog.mdc`): every
user-facing change gets an entry under `## [Unreleased]` of that repo, in the
same commit or one changelog commit right after. Write for admins, not a git log.
Anything an admin must do after the update goes in **bold** in the entry
(`**Re-copy the unit files** …`) — step 6 picks it up. Keep the file's style.
No changelog in the repo: mention it, don't create one unasked.

**Bump**: patch = fixes only, minor = anything `Added` or non-breaking `Changed`,
major = `Removed`, `**Breaking:**`, stack/architecture changes. The image stays on
major `3` unless the user explicitly wants `4.0.0` (Prime pins
`SCS_MANAGER_IMAGE_VERSION=3`).

**Tags are plain `X.Y.Z`, never `vX.Y.Z`**, higher than the last, not existing yet.

Release a repo:

1. Move the `[Unreleased]` body into `## [X.Y.Z] - YYYY-MM-DD` (today), leave an
   empty `## [Unreleased]` above, update compare links only if the file has them.
2. Commit `CHANGELOG.md` (plus any pinned version file): `Release X.Y.Z.`
3. Annotated tag on that commit: `git tag -a X.Y.Z -m "X.Y.Z" -m "<changelog section>"`.

Weg B dependencies:

- **Module** changed since its last tag → release `4.x.y` on `4.x`. The production
  image installs `drupal/soda_scs_manager` `^4.1` from drupal.org, so the image tag
  is pushed only after drupal.org lists the module release.
- **Image**: release `3.x.y` when the module got a tag, a theme branch got new
  commits, shipped content changed, or the image repo changed. Name the module
  version in the image changelog. Touch `.github/workflows/build-image.yml` only
  if its version constraint line must change.
- **Theme**: no tags, only its branch is pushed.

### 5. Submodule pointers + deployment

- `scs-nextcloud-stack`: `git add apps/scs_manager_integration`, commit
  `Point scs_manager_integration at <summary>.`
- Deployment: `git add <changed submodule paths>` plus own changes
  (`docker-compose.yml`, `00_custom_configs/`, `01_scripts/`, `docs/`), commit
  e.g. `Point JupyterHub and Keycloak at the project-mount changes.`
- `docs/de` and `docs/en` changed? Keep both in sync.

### 6. Collect the manual steps

CI does not publish everything. Build the list from the plan and the changelogs;
each item names the exact URL or command. Check these cases:

**Before / while pushing** (go into the plan as `pause`, so the script stops):

| Trigger | Manual step |
| --- | --- |
| Module tag `X.Y.Z` | Write `plans/release-notes-soda_scs_manager-X.Y.Z.md` (English, for drupal.org): `## Short description` (one plain-text sentence) and `## Release notes (HTML)` (fenced `html`: intro, **Upgrade notes** first, then Added/Changed/Removed/Fixed from the changelog, admin-facing, no internals). In the plan: `show plans/release-notes-…md` before the `pause`. drupal.org → https://www.drupal.org/project/soda_scs_manager → *Add new release*, pick tag `X.Y.Z`, paste both fields, set the release type. Packaging takes a few minutes; `wait-drupal` waits for it. |
| Older module tag pushed but not on updates.drupal.org | Same release node for that tag, or skip it and say so. |

**After pushing** (go into the plan as `todo`, the script prints them at the end):

| Trigger | Manual step |
| --- | --- |
| Image tag | Check that *Publish SCS Manager Docker Images* is green: https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions. |
| WissKI base image tag | Check that *Publish WissKI Base Docker Images* is green: https://github.com/soda-collections-objects-data-literacy/wisski-base-image/actions. |

**Prime, through `/prime-deploy`** (one `todo Prime: /prime-deploy …` line, after the CI checks).
`ssh prime apply` runs `update-stack.bash --prime --apply`, which covers all of
these, so they get **no** lines of their own:

- deployment pull and submodule checkout to the pointers;
- copying the changed overrides from `00_custom_configs/` into the stacks;
- snapshot, rebuild and recreate of every changed service (Weg A step 3);
- pulling and starting the new SCS Manager image, with the bind-mount check
  and the Drupal checks (Weg B step 5);
- Nextcloud backup before a version change; pulling the newest WissKI image;
- WissKI component version and default (`/prime-deploy` step 5).

Name in that line what the rollout carries, e.g.
`todo Prime: /prime-deploy (image 3.5.0, JupyterHub rebuild, WissKI 5.9.0 as default)`.
When the image CI must be green first, say so in the line.

**Prime, manual** (`todo Prime (manual): …`, after the `/prime-deploy` line): the
wrapper has no shell, no `sudo` and no free `drush`/`occ`, so these stay with
the user on Prime:

| Trigger | Manual step |
| --- | --- |
| Unit files in `01_scripts/global/*.service|*.timer` changed | `apply` only prints the commands: `sudo cp` to `/etc/systemd/system/`, `sudo systemctl daemon-reload`, restart the timers. |
| Module changed `config/install` or `config/optional` without a new `hook_update_N`/`hook_post_update_NAME` | The entrypoint runs `drush updatedb` but **never `config:import`**, so that config does not reach existing sites. Prefer writing an update hook now (ask the user); otherwise list the exact config names to import by hand. |
| New settings, API keys, permissions or roles in the changelog | Set them in the UI (e.g. `/admin/config/soda-scs-manager/settings`) or by `drush`; secrets are never in git. New `.env` variables go into Prime's `.env` **before** `/prime-deploy`, so `apply` recreates with them. |
| Drush commands or "run once" steps in the changelog (e.g. backfills) | `docker exec manager--drupal--app drush <command>` with the exact arguments. |
| Nextcloud version or app version bump (`appinfo/info.xml`) | After `apply`: `01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash`, then `occ app:update --all` / `occ upgrade` if Nextcloud reports the app as outdated. |
| Keycloak realm/theme changes | Realm imports only run on a fresh realm: apply realm changes in the admin console; the theme rebuild is part of `apply`. |
| Demo version to move | Only on request: `/prime-deploy` step 6 (the `scp -3` runs on the user's workstation). |
| Any **bold** admin instruction in a changelog entry shipped now | Copy it as its own step (as `/prime-deploy` if the wrapper covers it, otherwise manual). |

**Dev host image channel** (see `docs/en/technical/maintenance/scs-manager-image-update.md`):
the shared dev host runs `SCS_MANAGER_MODE=development` and
`SCS_MANAGER_IMAGE_VERSION=main`. CI publishes `:main` on every push to the image
repo `main`. Do **not** put a floating major (`3`) or a SemVer pin into the Dev
`.env`. Module/theme stay on bind-mounted `4.x` / theme `main` — independent of
the image tag. After the image CI is green, the plan's default Dev refresh is
`pull` + `--force-recreate` of `manager--drupal--app` (not a local rebuild).

**Optional — local image builds on this host** (Dockerfile/entrypoint work or skip
the GHCR wait). Add as `todo Optional (local): …` only when the user wants that
path. Tag with the same `ghcr.io/…` names Compose uses. `:local` is temporary:
set `SCS_MANAGER_IMAGE_VERSION=local`, recreate, then switch back to `main`.
Use `--no-cache` when the baked package set or module must change; otherwise
`--pull` is enough.

| Trigger | Local build (fill in the real `X.Y.Z`) |
| --- | --- |
| `scs-manager-image` tag `X.Y.Z` | From `repos/scs-manager-image`, build production and/or development and tag `…/scs-manager-image-{production,development}:X.Y.Z` plus `:X.Y`, `:X`. Optionally also `:local` for a temporary Dev switch. Production needs the module release on drupal.org if `SODA_SCS_MANAGER_VERSION` was raised. |
| `wisski-base-image` tag `X.Y.Z` | From `repos/wisski-base-image`, production: `--build-arg MODE=production` → `…/wisski-base-image-production:X.Y.Z` (+ `:X.Y`, optional `:local`). The Dockerfile curls `drupal_packages` from GitHub, so **push packages first** (or the build 404s). |
| `wisski-base-image` rolling development | Same repo, `--build-arg MODE=development --build-arg WISSKI_PACKAGES_LINE=4.x` → `…/wisski-base-image-development:main` (+ optional `:local`). |

Example commands (adapt version and which variants you need):

```bash
# SCS Manager (optional local — Dev host default remains :main from CI)
cd repos/scs-manager-image
docker build --pull --build-arg MODE=development \
  -t ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development:X.Y.Z \
  -t ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development:local \
  .

# WissKI production (after packages are on GitHub)
cd repos/wisski-base-image
docker build --no-cache --pull --build-arg MODE=production \
  -t ghcr.io/soda-collections-objects-data-literacy/wisski-base-image-production:X.Y.Z \
  -t ghcr.io/soda-collections-objects-data-literacy/wisski-base-image-production:local \
  .

# WissKI development rolling
docker build --no-cache --pull --build-arg MODE=development --build-arg WISSKI_PACKAGES_LINE=4.x \
  -t ghcr.io/soda-collections-objects-data-literacy/wisski-base-image-development:main \
  -t ghcr.io/soda-collections-objects-data-literacy/wisski-base-image-development:local \
  .
```

### 7. Push plan + report

Write `plans/push-plan.txt` (gitignored). Innermost first, deployment last; tags
go in the same line as their branch. Actions: `push`, `gh-release`, `show`, `pause`,
`wait-drupal`, `note`, `todo`; lines starting with `#` are comments.

For every **GitHub-hosted** tag (image, wisski-base-image, wisski-base-stack, … —
not the module on git.drupal.org), put `gh-release <path> <tag>` on the next line
after that repo's `push`. The script creates the GitHub Release from the annotated
tag message and skips if it already exists. Module releases stay on drupal.org
(`pause` + `wait-drupal`).

```text
# Generated by scs-release-prep on 2026-11-10
push scs-nextcloud-stack/apps/scs_manager_integration origin main
push scs-nextcloud-stack origin main
push jupyterhub origin main
push scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme origin main
push scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager origin 4.x 4.2.0
push scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager fork 4.x 4.2.0
show plans/release-notes-soda_scs_manager-4.2.0.md
pause drupal.org: create the release node for 4.2.0 at https://www.drupal.org/project/soda_scs_manager (Add new release, tag 4.2.0, paste the changelog)
wait-drupal soda_scs_manager 4.2.0
push repos/scs-manager-image origin main 3.4.0
gh-release repos/scs-manager-image 3.4.0
push . origin main
todo Check the image build: https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions
todo Dev (SCS_MANAGER_IMAGE_VERSION=main): docker compose pull manager--drupal--app && docker compose up -d --force-recreate manager--drupal--app
todo Optional (local Dockerfile work): cd repos/scs-manager-image && docker build --pull --build-arg MODE=development -t ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development:local . && temporarily set SCS_MANAGER_IMAGE_VERSION=local, recreate, then switch back to main
todo Prime: /prime-deploy once the image build is green (image 3.4.0, JupyterHub rebuild)
todo Prime (manual): sudo cp the changed 01_scripts/global/*.timer and *.service to /etc/systemd/system/, sudo systemctl daemon-reload (apply prints the exact commands)
```

Rules: only repos with unpushed commits or new tags; branch names as refspec, not
`HEAD`; `pause` + `wait-drupal` before the image line whenever a module tag is in
the plan; `gh-release` right after each GitHub tag push; no `git pull`,
`docker compose` or WissKI-settings lines for Prime (that is `/prime-deploy`).

Run `01_scripts/global/push-release-plan.bash --dry-run`; every line must resolve
(no `MISSING`, exit 0). Then report:

1. Per repo: commits, changelog entry, tag.
2. Skipped items and why (uncommitted files left alone, repos without changelog).
3. The command to run.
4. **Manual steps**, as a numbered checklist in order: during the push (drupal.org),
   after the push (CI checks, GitHub Releases), optional local image builds, then
   `/prime-deploy` (what it will roll out), then what stays manual on Prime
   (sudo, consoles, settings/secrets, drush/occ). Same items as the
   `pause`/`todo` lines, so nothing is only in one place.
5. Next step: once the push ran and CI is green, `/prime-deploy` from here
   (the user loads `ssh-add -t 2h ~/.ssh/scs-prime` on the workstation first).
