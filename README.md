# SODa SCS Manager Deployment

Docker Compose environment for the Drupal-based SCS Manager plus Keycloak, Nextcloud, JupyterHub, OpenGDB, phpMyAdmin (DBMS), and related services. Uses MariaDB, Traefik, and Portainer.

**DBMS / phpMyAdmin:** Keycloak SSO; credentials come from Keycloak only (no fallback passwords). Users get DB access when they create an SQL component or when added to a project with SQL databases. SCS Manager provisions the MariaDB user and syncs the password to Keycloak `mariadb_password` for phpMyAdmin signon.

## Version

- SODa SCS Manager Deployment 1.0.0 · Drupal 11 · MariaDB 11.5 · Traefik 3 · Portainer CE 2.21

## Requirements

- `jq`
- `curl`

## Quick start

1. Clone the repo and init submodules: `git submodule update --init --recursive`
2. Copy `example-env` to `.env` and set required variables (database, Keycloak, client secrets, domains, `SCS_DBMS_*` for phpMyAdmin SSO).
3. Run `./start.sh` (creates network, starts DB, runs pre-install scripts).
4. Run `docker compose up -d`.
5. Complete post-configuration — see [Technical documentation](docs/en/technical/index.md).

**Prerequisites:** Docker, user in `docker` group, GitHub auth for ghcr.io and Git.

## Documentation (Zensical)

Full docs live in [`docs/en/`](docs/en/index.md) and [`docs/de/`](docs/de/index.md) (overlays), built with [Zensical](https://zensical.org/) (modern theme), and served at **`https://docs.<SCS_SUBDOMAIN>.<SCS_BASE_DOMAIN>`** (`/en/`, `/de/`; `core--docs--app`, env `SCS_DOCS_DOMAIN`).

```bash
./01_scripts/global/build-docs.bash
docker compose up -d --force-recreate core--docs--app
```

Local preview: `docker run --rm -it -p 3456:8000 -v "${PWD}:/docs" zensical/zensical`

## License

GPL v3 — see [LICENSE.txt](LICENSE.txt).
