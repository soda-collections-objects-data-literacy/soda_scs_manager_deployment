# Update the SCS Manager image

Prime keeps the configuration of the site that is already installed. A new image replaces Composer packages and the shipped pages. The container entrypoint applies both when the container is created from that image. It does not import Drupal config over the existing site.

`docker restart` does not load a new image. The Prime steps below pull the image and recreate the container.

Replace `3.3.0` in every command with the tag you are publishing. Use that same tag in Prime's `.env`.

## Dev

Run this on the dev host. The image build clones the theme from GitHub `main` and installs `drupal/soda_scs_manager` from Drupal.org at the constraint in the image workflow (`SODA_SCS_MANAGER_VERSION`, currently `^4.0`). Commits that are not pushed are not in the image.

### 1. Export and push the pages

Skip this step when the shipped pages did not change.

`content/manifest.yml` lists the node bundles, node UUIDs, and menus that the export writes into `content/sync`.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
./content/export-content.bash
git status
git add content/sync content/manifest.yml
git commit -m "Update the shipped home page and legal pages."
git push origin main
```

### 2. Publish the image

A new `4.0.x` release on Drupal.org is picked up by the existing `^4.0` constraint. No workflow edit is required for that. Change the constraint only in `repos/scs-manager-image/.github/workflows/build-image.yml` when the line itself changes (`SODA_SCS_MANAGER_VERSION`, `SODA_SCS_MANAGER_DEV_VERSION`, `SCS_CUSTOM_THEME_REF`), commit that file, and push it with the commands below.

`main` is the rolling development line: pushing it publishes the tags `scs-manager-image-production:main` and `scs-manager-image-development:main`. Releases are plain version tags taken from `main`; the version tag is what Prime pins. A `X.x` branch is only cut from a release tag to maintain an older major.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/repos/scs-manager-image
git push origin main
git tag 3.3.0
git push origin 3.3.0
```

That second push publishes `scs-manager-image-production:3.3.0` (and the tags `3.3` and `3`). Wait until the workflow [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) is green before the Prime steps.

## Prime

Run this on Prime, in the deployment checkout. `SCS_MANAGER_MODE` stays `production`.

### 3. Point `.env` at the new tag

```bash
cd /var/deploy/soda_scs_manager_deployment
grep -E '^(SCS_MANAGER_MODE|SCS_MANAGER_IMAGE_VERSION)=' .env
```

Set:

```bash
SCS_MANAGER_MODE=production
SCS_MANAGER_IMAGE_VERSION=3
```

`3` always points to the newest release of major version 3 (3.3.0, 3.3.1, 3.4.0, …). Patch and minor releases therefore leave `.env` unchanged; step 5 (pull and recreate) is enough. Change the tag here only for a new major release (4.0). For a fixed state, for example when rolling back, set the full version instead (`3.3.0`). `.env` is not committed.

### 4. Confirm the image is what the container will run

These destinations must not appear. A bind mount hides the theme and the module that were baked into the image.

```bash
docker inspect manager--drupal--app --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' | grep -E 'scs_custom_theme|soda_scs_manager' || echo "no theme or module bind mount"
```

### 5. Pull the image and recreate the container

```bash
cd /var/deploy/soda_scs_manager_deployment
docker compose pull manager--drupal--app
docker compose up -d manager--drupal--app
docker compose logs -f manager--drupal--app
```

Leave the logs open until nginx is up. Then look for these lines:

- `Package set changed` — `drush updatedb -y` and `drush cr` ran. There is no `drush config:import` on an existing site.
- `Shipped content changed` — `content/import.php` ran. Entities with a known UUID are updated. New UUIDs are created.
- `ERROR:` — that step did not write its fingerprint. The next `docker compose up -d manager--drupal--app` tries it again.

A start that prints neither `Package set changed` nor `Shipped content changed` found both fingerprints unchanged and did nothing.

## What stays on Prime

| Applied from the image | Left as it is |
| --- | --- |
| Composer packages, including `drupal/soda_scs_manager` at the constraint baked into the image | `soda_scs_manager.settings`, OpenID, roles, users, projects, and any other config already on the site |
| Pages and menu links in `scs_custom_theme/content/sync` | The front page, unless it is still `/node` |

Theme config that does not exist yet (the home-page content types) is installed. Config names that already exist are not replaced.

`SODA_SCS_MANAGER_VERSION` in the deployment `.env` is not read when the container starts. Compose selects the image with `SCS_MANAGER_MODE` and `SCS_MANAGER_IMAGE_VERSION` only.

The first start, when `settings.php` is absent, still installs Drupal and imports `/opt/drupal/sync/configs`. That path is not used for this update.
