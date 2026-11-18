# Update the SCS Manager image

Compose selects the image with `SCS_MANAGER_MODE` and `SCS_MANAGER_IMAGE_VERSION` only:

`ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-${SCS_MANAGER_MODE}:${SCS_MANAGER_IMAGE_VERSION}`

Module release tags, the image release tags, and the rolling development image are three different things. Do not mix them.

## Tag rules

| Tag | Role |
|---|---|
| `:main` | Official rolling development image. CI publishes it on every push to `main` in [scs-manager-image](https://github.com/soda-collections-objects-data-literacy/scs-manager-image). |
| `:local` | Only for a self-built image (Dockerfile or entrypoint work before CI). Not the default on the shared dev host. |
| `:3`, `:3.7.0`, … | Release / compatibility references. Prime uses the floating major (`SCS_MANAGER_IMAGE_VERSION=3`). |

### Dev host

```bash
SCS_MANAGER_MODE=development
SCS_MANAGER_IMAGE_VERSION=main
```

Do not pin a floating major (`3`) or a full SemVer on the shared dev host. The module and theme still come from the bind-mounted checkouts (`4.x` / `main`); the image tag does not replace those mounts.

Refresh deliberately:

```bash
# from the deployment repo root
docker compose pull manager--drupal--app
docker compose up -d --force-recreate manager--drupal--app
```

`pull` alone does not move a running container. A container keeps its image ID when the tag later points elsewhere (dangling / untagged ID) until you recreate it.

For local image work only: build with `-t …/scs-manager-image-development:local`, set `SCS_MANAGER_IMAGE_VERSION=local`, recreate, then switch back to `main`.

### Prime

`SCS_MANAGER_MODE=production` and `SCS_MANAGER_IMAGE_VERSION=3`. Shipping module, theme, and pages: [Ship changes from dev to Prime](dev-to-prime.md#path-b-scs-manager-module-theme-and-pages).
