# SODa SCS Manager Deployment

Docker Compose environment for the Drupal-based SCS Manager plus Keycloak, Nextcloud, JupyterHub, OpenGDB, and related services. Uses MariaDB, Traefik, and Portainer.

## Version

- SODa SCS Manager Deployment 1.0.0 · Drupal 11 · MariaDB 11.5 · Traefik 3 · Portainer CE 2.21

## Quick start

1. Clone the repo and init submodules: `git submodule update --init --recursive`
2. Copy `example-env` to `.env` and set required variables (database, Keycloak, client secrets, domains).
3. Run `./start.sh` (creates network, starts DB, runs pre-install scripts).
4. Run `docker compose up -d`.
5. Complete post-configuration (Keycloak, SCS Manager, Nextcloud, etc.) — see **Technical documentation** below.

**Prerequisites:** Docker, user in `docker` group, GitHub auth for ghcr.io and Git (see technical docs).

## Technical documentation (MkDocs)

Full documentation (prerequisites, initial setup, service infrastructure, post-configuration checklist, reference) is in the **docs** and built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

**View the docs locally (Docker):**

Download this repo to your local machine, then from the repository root run:

```bash
git clone git@github.com:soda-collections-objects-data-literacy/soda_scs_manager_deployment.git
cd soda_scs_manager_deployment
docker run --rm -it -p 3456:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

Then open [http://localhost:3456](http://localhost:3456).

**Build static site:** `docker run --rm -v "${PWD}:/docs" squidfunk/mkdocs-material build` → output in `site/`.

## License

GPL v3 — see [LICENSE.txt](LICENSE.txt).
