# JupyterHub: server spawn fails (500 / spawner_image not found)

## Symptom

After logging in at `code.<scs>.<domain>`, starting a notebook shows:

- **500 Internal Server Error**
- *Unhandled error starting server &lt;username&gt;*

Hub logs (`docker compose logs jupyterhub--jupyterhub`) contain:

```text
pull access denied for spawner_image, repository does not exist or may require 'docker login'
```

or `docker.errors.ImageNotFound` for `fromImage=spawner_image`.

## Cause

JupyterHub spawns user containers from a **local-only** Docker image named `spawner_image` (see `DOCKER_JUPYTER_IMAGE` in `jupyterhub/docker-compose.yml`). That image is built by the `jupyterhub--image-builder` compose service; it is **not** pulled from a registry and is **not** started automatically (`deploy.replicas: 0`).

If the image was never built, or was removed during `docker image prune`, spawn fails with HTTP 500.

## Fix

From the deployment root (with `COMPOSE_FILE` from `.env`):

```bash
docker compose build jupyterhub--image-builder
```

Verify:

```bash
docker images spawner_image
```

Then retry starting the server from the Hub home page (no Hub restart required).

## When to rebuild

Rebuild after changes under `jupyterhub/spawner_image/` (Dockerfile, Nextcloud sync extension, server extension package):

```bash
docker compose build jupyterhub--image-builder
```

Existing user containers keep running until stopped; new spawns use the updated image.

## Build notes

- The spawner Dockerfile uses a **Python 3.12** build stage (`nikolaik/python-nodejs:python3.12-nodejs22`) to compile the JupyterLab extension; Python 3.14 does not yet ship compatible JupyterLab wheels.
- Labextension bundling calls `/tmp/jlbuild/bin/jupyter-builder build` directly (the deprecated `jupyter labextension build` wrapper looks up `jupyter-builder` on `PATH`, which fails inside an isolated venv).

## Related

- OpenRefine must exist at `JUPYTERHUB_OPENREFINE_DIR` (default: `$PWD/openrefine` in root `.env`). Run `01_scripts/jupyterhub/pre-install.sh` if missing.
- Hub logs: `docker compose logs -f jupyterhub--jupyterhub`
