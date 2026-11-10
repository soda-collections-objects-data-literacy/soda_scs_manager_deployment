# Ship changes from dev to Prime

Dev checkout: `/var/www/deploy/soda_scs_manager_deployment`. Prime checkout: `/var/deploy/soda_scs_manager_deployment`. `.env` is not committed and is not copied from dev to Prime.

There are two paths. Take the one that matches the change. When both changed, push path A on dev first. On Prime, check out the deployment first and recreate the manager container only at the end of path B.

## Short recipe

1. **On dev:** `/scs-release-prep` (skill) — commits, changelogs, tags, `plans/push-plan.txt`. Details: [Release prep](release-prep.md).
2. **On dev:** `01_scripts/global/push-release-plan.bash` (try `--dry-run` first). Finish any manual steps from the prep (for example the drupal.org release node).
3. **On Prime:**

```bash
cd /var/deploy/soda_scs_manager_deployment
./01_scripts/global/update-stack.bash --prime --check   # plan only, changes nothing
./01_scripts/global/update-stack.bash --prime --apply   # after reading the plan
```

Paths A and B below remain the reference for what those steps do.

## What `--prime` does on Prime

`update-stack.bash --prime` runs the Prime side of both paths: path A steps 2 and 3, and path B step 5.

`--check` shows which repos move to which recorded pointer (with the commit log), what is built, recreated and copied, which systemd units differ, the new CHANGELOG sections, and the current Drupal checks. It exits with 1 when something blocks the update, for example uncommitted changes.

`--apply` then:

1. fast-forwards the deployment and runs `git submodule update --init --recursive` without `--remote`,
2. copies changed override sources into `scs-manager-stack/` and `scs-project-website-stack/`, unless the copy there has local edits,
3. installs changed systemd units when run as root, otherwise lists the `sudo` commands,
4. dumps all databases to `/srv/backups/pre-update/<timestamp>/` before the first container is recreated, and runs `backup-nextcloud.bash` when the Nextcloud version changes,
5. builds and recreates the affected containers (table in [step 3](#3-recreate-the-containers-that-changed)),
6. pulls the SCS Manager image and follows its log ([path B, step 5](#5-start-the-image-on-prime)), but only when the container has no module or theme bind mount,
7. checks `docker compose ps`, `drush updatedb:status`, `drush scs:check --problems` and the enabled themes,
8. prints the manual steps that are left: `sudo` commands, the Nextcloud repair, and the bold lines from the CHANGELOGs.

Options: `--no-snapshot` skips the database dump, `--since <commit>` sets the deployment commit to compare from (default: the last successful `--prime --apply`), and `--offline` plans without fetching. Git reads public repos over HTTPS when the SSH key needs a passphrase.

`SCS_MANAGER_IMAGE_VERSION` is only shown. With a full version such as `3.3.1`, no newer manager image arrives until the line says `3`.

## Path A: deployment and submodules

This covers JupyterHub, Nextcloud, Keycloak, OpenGDB, WebProtégé, Voyager, Health, the project website, and Compose, overrides, and scripts in the deployment. It also covers `scs-manager-stack` when only its Compose changed, and not the module, a theme, or the pages.

### 1. Push on dev, from the inside out

Commit and push in the repo that holds the files. When that repo is a submodule, commit and push the new pointer in the repo above it. The chain ends in the deployment on `main`.

JupyterHub:

```bash
cd /var/www/deploy/soda_scs_manager_deployment/jupyterhub
git push
cd /var/www/deploy/soda_scs_manager_deployment
git add jupyterhub
git commit -m "Point JupyterHub at the hub change."
git push origin main
```

The same chain for `keycloak`, `scs-nextcloud-stack`, `open_gdb`, `webprotege`, `scs-health`, `scs-voyager`, `scs-project-website-stack`, and `scs-manager-stack`.

The Nextcloud app `scs_manager_integration` is a submodule of `scs-nextcloud-stack`. Push the app first, then the pointer in the Nextcloud stack, then the pointer in the deployment.

When the change is only in the deployment (`docker-compose.yml`, `00_custom_configs/`, `01_scripts/`), pushing `main` is enough.

### 2. Check out on Prime

`start.sh` moves submodules with `--remote` to the branch tip, not to the pointer in the deployment commit. For this update, run the two commands on their own:

```bash
cd /var/deploy/soda_scs_manager_deployment
git pull
git submodule update --init --recursive
```

Compose reads the overrides for JupyterHub, Keycloak, Nextcloud, OpenGDB, WebProtégé, Health, and Voyager straight from `00_custom_configs/`. For the SCS Manager and the project website it reads the gitignored copy in the stack. After a change to the source, replace the copy:

```bash
cp 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml scs-manager-stack/docker-compose.override.yml
cp 00_custom_configs/scs-project-website-stack/docker/docker-compose.override.yml scs-project-website-stack/docker-compose.override.yml
```

When the unit files under `01_scripts/global/` changed, copy them to `/etc/systemd/system/` again and run `systemctl daemon-reload`. The commands are in [Pre-start steps](../initial-setup/pre-start-steps.md#host-preparation-once-per-host-before-startsh).

### 3. Recreate the containers that changed

A `git pull` does not change a container that is already running. `docker restart` does not load a new image or a new build.

| Changed | Command on Prime |
| --- | --- |
| JupyterHub | `docker compose up -d --build jupyterhub--jupyterhub--app` |
| Notebook image | `docker compose build jupyterhub--spawner--builder` |
| Nextcloud, same version | `docker compose up -d nextcloud--nextcloud--app` |
| Nextcloud app `scs_manager_integration` | `docker compose up -d nextcloud--nextcloud--app` |
| OnlyOffice | `docker compose pull nextcloud--ods--app && docker compose up -d nextcloud--ods--app` |
| Keycloak | `docker compose up -d --build keycloak--keycloak--app` |
| WebProtégé | `docker compose up -d --build webprotege--webprotege--app` |
| Health | `docker compose up -d --build health--health--app` |
| Voyager | `docker compose up -d --build voyager--voyager--app` |
| Project website | `docker compose up -d --build scs-project-website--drupal` |
| OpenGDB | `docker compose up -d --build` with the container that changed (`opengdb--nginx--edge`, `opengdb--rdf4j--db`, `opengdb--authproxy--proxy`, `opengdb--outproxy--proxy`) |
| Traefik, MariaDB, Portainer, image tag only | `docker compose pull <container> && docker compose up -d <container>` |
| SCS Manager Compose, without module, theme, or pages | `docker compose up -d manager--drupal--app` |

When the Nextcloud version changes, back up first and run the repair steps in [Updates](updates.md#updating-nextcloud). Stopping a recreate in the middle of the migration leaves the instance in maintenance mode.

## Path B: SCS Manager module, theme, and pages

Dev bind-mounts the module and the theme from the checkouts. Prime runs the copies from the production image. Pushing the module or the theme on its own does not change Prime.

Order: pack the pages, push the theme, release the module, tag the image, pull it on Prime. Skip a step whose tree did not change.

### 1. Pack the pages into `content/sync`

The home page, its sections, and the menus live as YAML in the theme `scs_custom_theme`, directory `content/sync`. `content/manifest.yml` lists the node bundles, node UUIDs, and menus. The export reads those entities from the running dev site and rewrites the YAML files. The import on Prime creates or updates entities with a known UUID.

Dev has to be running. The export calls Drush in `manager--drupal--app`.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
./content/export-content.bash
git status
git add content/sync content/manifest.yml
git commit -m "Update the shipped home page and legal pages."
git push origin main
```

### 2. Push the theme

The image build clones `scs_custom_theme` from branch `main`. Commits that are not on that branch are missing from the image. The manager UI styles live in the module (`css/soda-scs-manager.css`) and ship with the module release. Step 1 already pushed `scs_custom_theme` when only the pages changed.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
git push origin main
```

### 3. Release the module

The production build installs `drupal/soda_scs_manager` at `^4.3` from Drupal.org. The `4.x` branch alone is not in the production image.

Move the `[Unreleased]` section in `CHANGELOG.md` into the new version before tagging. Replace `4.1.1` with the next tag, higher than the last one (`git tag -l '4.*' --sort=-v:refname | head -1`). `origin` is `git.drupal.org`. A tag on the GitHub fork alone is not enough.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager
git push origin 4.x
git tag 4.1.1
git push origin 4.1.1
```

Wait until the release is listed on [soda_scs_manager releases](https://www.drupal.org/project/soda_scs_manager/releases).

### 4. Tag the image

`git tag -l '3.*' --sort=-v:refname | head -1` in the image repo shows the last tag. Pushing `main` publishes only `:main`. Prime pins the major tag `3`. A version tag such as `3.3.5` sets `3.3.5`, `3.3`, and `3`.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/repos/scs-manager-image
git push origin main
git tag 3.3.5
git push origin 3.3.5
```

Wait until [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) is green. Replace `3.3.5` with the next tag.

Change the `^4.3` constraint only in `repos/scs-manager-image/.github/workflows/build-image.yml` when the line itself changes (`SODA_SCS_MANAGER_VERSION`, `SODA_SCS_MANAGER_DEV_VERSION`, `SCS_CUSTOM_THEME_REF`). Commit that file and push it with the tag.

### 5. Start the image on Prime

Do [path A, step 2](#2-check-out-on-prime) first when the deployment changed as well.

`SCS_MANAGER_MODE` stays `production`. `SCS_MANAGER_IMAGE_VERSION` stays `3`. That tag points at the newest release of major version 3. Change the line only for a new major (4.0). To roll back, set the full version instead, for example `3.3.4`.

These mount destinations must not appear. A bind mount hides the theme and the module from the image.

```bash
cd /var/deploy/soda_scs_manager_deployment
docker inspect manager--drupal--app --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' | grep -E 'scs_custom_theme|soda_scs_manager' || echo "no theme or module bind mount"
docker compose pull manager--drupal--app
docker compose up -d manager--drupal--app
docker compose logs -f manager--drupal--app
```

Leave the logs open until nginx is up. Then look for these lines:

- `Package set changed` — `drush updatedb -y` and `drush cr` ran. There is no `drush config:import` on an existing site.
- `Shipped content changed` — `content/import.php` ran. Entities with a known UUID are updated. New UUIDs are created.
- `ERROR:` — that step did not write its fingerprint. The next `docker compose up -d manager--drupal--app` tries it again.

A start that prints neither `Package set changed` nor `Shipped content changed` found both fingerprints unchanged and did nothing.

#### When Prime still has the bind mounts

Prime may still bind-mount the module and the theme from host checkouts, as dev does. Then a new image changes nothing, `drush scs:check` can be missing, and retired themes stay enabled. `update-stack.bash --prime --check` reports it as `SCS Manager image: SKIPPED`. The mounts live in the gitignored copy `scs-manager-stack/docker-compose.override.yml`, not in the source under `00_custom_configs/`.

**1. Check that the image is not older than the site.** Every update hook number the database knows must exist in the image. The image may have more; they run on start.

```bash
cd /var/deploy/soda_scs_manager_deployment
IMAGE=ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production:3
docker pull -q "$IMAGE"
# Schema version of the site
docker exec manager--drupal--app drush ev "echo \Drupal::service('update.update_hook_registry')->getInstalledVersion('soda_scs_manager');"; echo
# Module version and newest update hook in the image
docker run --rm --entrypoint sh "$IMAGE" -c 'd=/opt/drupal/web/modules/contrib/soda_scs_manager; grep -m1 "^version" $d/*.info.yml; grep -oE "^function soda_scs_manager_update_[0-9]+" $d/soda_scs_manager.install | grep -oE "[0-9]+$" | sort -n | tail -1'
```

If the newest hook in the image is lower than the schema version, stop: release the module and tag the image first (steps 3 and 4).

**2. Save what only exists on Prime.** Uncommitted edits in the host checkouts are lost once the image runs. Save them, apply them on dev and ship them with the next release.

```bash
BACKUP=/srv/backups/pre-update/$(date +%Y%m%d_%H%M%S)-manual; mkdir -p "$BACKUP"
M=scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager
git -C "$M" status --short
git -C "$M" diff > "$BACKUP/soda_scs_manager-prime-local.patch"
cp scs-manager-stack/docker-compose.override.yml "$BACKUP/scs-manager-stack.docker-compose.override.yml"
```

Do the same for the theme checkouts under `…/web/themes/custom/`.

**3. Remove the mounts and follow the major tag.** When the copy differs from the source only by the two mount lines (`diff scs-manager-stack/docker-compose.override.yml 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml`), copy the source over it. Otherwise delete the two lines by hand.

```bash
cp 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml scs-manager-stack/docker-compose.override.yml
sed -i 's/^SCS_MANAGER_IMAGE_VERSION=.*/SCS_MANAGER_IMAGE_VERSION=3/' .env
./01_scripts/global/update-stack.bash --prime --check   # now: "docker compose pull manager--drupal--app"
./01_scripts/global/update-stack.bash --prime --apply
```

The script dumps all databases first and then recreates the manager. Expect `Package set changed` (the new update hooks run, a retired theme is uninstalled) and usually `Shipped content changed`. Afterwards `drush scs:check --problems` and the theme check must be green. If a host timer shows `never ran` right after the start, wait for its next run: a heartbeat sent while the manager was restarting is lost.

Then remove theme checkouts the CHANGELOG retires, for example `…/web/themes/custom/soda_scs_manager_theme`, once `git status` and `git log --branches --not --remotes` show nothing local.

**4. Roll back if the manager does not come up.**

```bash
cp "$BACKUP/scs-manager-stack.docker-compose.override.yml" scs-manager-stack/docker-compose.override.yml
sed -i 's/^SCS_MANAGER_IMAGE_VERSION=.*/SCS_MANAGER_IMAGE_VERSION=3.3.1/' .env   # the version that ran before
docker compose up -d manager--drupal--app
```

If the database updates already ran, the old module may not match the new schema. Then also restore the dump that `--prime --apply` wrote to `/srv/backups/pre-update/<timestamp>/all-databases.sql.gz`, with all writing containers stopped.

### What stays on Prime

| Applied from the image | Left as it is |
| --- | --- |
| Composer packages, including `drupal/soda_scs_manager` at the constraint baked into the image | `soda_scs_manager.settings`, OpenID, roles, users, projects, and any other config already on the site |
| Pages and menu links in `scs_custom_theme/content/sync` | The front page, unless it is still `/node` |

Theme config that does not exist yet (the home-page content types) is installed. Config names that already exist are not replaced.

`SODA_SCS_MANAGER_VERSION` in the deployment `.env` is not read when the container starts. Compose selects the image with `SCS_MANAGER_MODE` and `SCS_MANAGER_IMAGE_VERSION` only.
