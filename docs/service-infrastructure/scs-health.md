# SCS Health dashboard

**scs-health** is a Next.js application (git submodule at `scs-health/`) that provides an operator-facing health dashboard for the SODa SCS stack. It is served by container `scs--health` behind Traefik.

## Purpose

- **Website checks** — HTTPS requests to each stack service using domain env vars from the root `.env`.
- **Container checks** — `docker ps` via a read-only mounted Docker socket (optional).
- **Authenticated access** — local credentials and/or Keycloak OIDC (NextAuth.js).

Public liveness: `GET https://${SCS_HEALTH_DOMAIN}/api/health` (no login).

## Stack wiring

| Piece | Location |
| --- | --- |
| Submodule | `scs-health/` → `git@github.com:rnsrk/scs-health.git` |
| Base compose | `scs-health/docker-compose.yml` |
| Site override | `00_custom_configs/scs-health/docker/docker-compose.override.yml` |
| `COMPOSE_FILE` entry | `scs-health/docker-compose.yml:00_custom_configs/scs-health/docker/docker-compose.override.yml` |

Traefik routes `Host(\`${SCS_HEALTH_DOMAIN}\`)` to port 3000 on the `reverse-proxy` network. TLS uses the `le` certificate resolver.

The override sets `build.context` to `${SCS_ROOT_PATH}/scs-health` so the image is built from the submodule checkout.

## Environment variables

Set in the **root** `.env` (see `example-env`):

| Variable | Purpose |
| --- | --- |
| `SCS_HEALTH_DOMAIN` | Dashboard hostname; also used for `NEXTAUTH_URL` |
| `SCS_HEALTH_AUTH_SECRET` | NextAuth session secret |
| `SCS_HEALTH_AUTH_USER` / `SCS_HEALTH_AUTH_PASSWORD` | Local login (default: Traefik admin credentials) |
| `SCS_HEALTH_OIDC_CLIENT_ID` | Keycloak client ID (optional SSO) |
| `SCS_HEALTH_OIDC_CLIENT_SECRET` | Keycloak client secret |
| `SCS_HEALTH_OIDC_ISSUER` | OIDC issuer; optional if `KC_URL` + `KC_REALM` are set |
| `SCS_HEALTH_DOCKER_ENABLED` | Set `false` to disable Docker container panel |

Service domains (`SCS_MANAGER_DOMAIN`, `KC_DOMAIN`, `NEXTCLOUD_NEXTCLOUD_DOMAIN`, …) are passed through from the main `.env` for website checks.

Generate a session secret:

```bash
openssl rand -base64 32
```

## Install and start

From the deployment repo root (after submodules and `.env` are configured):

```bash
git submodule update --init scs-health
./start.sh   # copies override files and updates submodules
docker compose up -d --build scs--health
```

Recreate after compose or env changes:

```bash
docker compose up -d --force-recreate scs--health
```

Logs:

```bash
docker compose logs -f scs--health
```

## Keycloak SSO

The realm template does **not** yet include a client for scs-health. Create one in the Keycloak admin UI:

1. **Client ID** — e.g. `https://${SCS_HEALTH_DOMAIN}` (consistent with other SCS OIDC clients).
2. **Confidential** client with standard authorization code flow.
3. **Valid redirect URI:**

   ```text
   https://${SCS_HEALTH_DOMAIN}/api/auth/callback/keycloak
   ```

4. **Web origin:** `https://${SCS_HEALTH_DOMAIN}`
5. Copy the client secret into `SCS_HEALTH_OIDC_CLIENT_SECRET` in `.env`.

Set `SCS_HEALTH_OIDC_CLIENT_ID` and either `SCS_HEALTH_OIDC_ISSUER` or rely on `KC_URL` + `KC_REALM`:

```text
https://<keycloak-host>/realms/<realm-name>
```

Recreate `scs--health` after setting OIDC variables (rebuild required when app code changes):

```bash
docker compose up -d --build scs--health
```

The login page reads OIDC env vars at **request time**, not at image build time. If you add OIDC settings later, `--force-recreate` is enough; no rebuild needed unless you changed the app.

The login page shows **Sign in with Keycloak** when all OIDC variables are set. Local credentials remain available.

Full step-by-step instructions: [scs-health/README.md](../../scs-health/README.md#sso-setup-keycloak) in the submodule.

## Operational notes

- The container runs as **root** so it can access the Docker socket; only `docker ps` is used (read-only socket mount). The image bundles a current static Docker CLI (not Debian `docker.io`) so the client API matches modern daemons.
- Build artifacts (`node_modules/`, `.next/`) are gitignored; the image is built via `Dockerfile` (standalone Next.js output).
- Submodule updates: change code in `scs-health`, commit/push there, then bump the submodule pointer in the deployment repo.

## See also

- [Service infrastructure overview](index.md)
- [Pre-start steps](../initial-setup/pre-start-steps.md) — submodule init and override copy
- [Keycloak and Nextcloud](../post-configuration/keycloak-nextcloud.md) — general OIDC patterns in this deployment
