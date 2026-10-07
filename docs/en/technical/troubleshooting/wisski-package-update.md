# WissKI Drupal package update failures

## Symptom

Updating Drupal/WissKI packages from SCS Manager (component → **Installed Drupal packages** → apply environment) fails early with watchdog errors such as:

- `Failed to secure Drupal database: Failed to dump database`
- `cURL error 28: Operation timed out after 30000 milliseconds` on a Portainer URL ending in `/docker/exec/.../start`

## Cause

The pre-update safety step runs `mariadb-dump` inside the WissKI Drupal container via the Portainer Docker exec API.

Two common failure modes:

1. **HTTP timeout (cURL error 28)** — the exec `/start` request used Guzzle's default 30 s timeout while `mariadb-dump` was still running.
2. **Wrong database host** — the dump command used `-hdatabase`, but WissKI instances connect to the shared MariaDB container at `scs--database` (see `DB_HOST` in the wisski-base-stack env). The hostname `database` does not resolve inside `wisski-*--drupal`, so the dump exits non-zero with no stderr when run detached.

## Fix (module)

`soda_scs_manager` now:

1. Uses a **600 s** default HTTP timeout for Docker exec/run API calls (matching other Portainer requests).
2. Runs database dumps in **detached** exec mode and polls until completion (up to **30 minutes**).
3. Reads the database host from **`dbHost`** in SCS Manager settings (`scs--database` on this deployment) instead of hardcoding `database`.

Deploy the updated `soda_scs_manager` module to `scs-manager--drupal` and retry the package update.

After redeploy, SCS Manager polls `/health` on the raw WissKI URL for up to **10 minutes** while status is `starting` (HTTP 404 from Traefik before Drupal is wired) or `unavailable` (502/503). A single immediate 404 right after redeploy is normal; the update should not fail until that window expires.

## If it still fails

1. Check watchdog (`drush watchdog:show --type=soda_scs_manager`) for the exact exec URL and exit code.
2. Confirm Portainer can reach the WissKI stack endpoint (`deployments.scs.<domain>`).
3. Test a manual dump inside the WissKI Drupal container; if that is slow or fails, fix database connectivity or disk space first.
