# WebProtégé patches (vs upstream, not a fork)

The `webprotege/` submodule tracks [protegeproject/webprotege](https://github.com/protegeproject/webprotege), not a SODa fork. Site-specific behaviour lives here as unified diffs plus a README per patch.

**Base:** `origin/master` at `3ca40cf44e733f72adbdb2db69f61420b2803fc8` (PR #826 merge).

## Apply

From the WebProtégé source root (`webprotege/`):

```bash
patch -p1 < ../00_custom_configs/webprotege/patches/docker-build/docker-build.patch
patch -p1 < ../00_custom_configs/webprotege/patches/oidc-sso/oidc-sso.patch
patch -p1 < ../00_custom_configs/webprotege/patches/project-api/project-api.patch
```

Apply in that order. `docker-build` and `oidc-sso` are independent of each other; `project-api` only needs upstream `POST /data/projects` (already in master).

To refresh a patch after editing sources:

```bash
git -C webprotege diff origin/master -- Dockerfile \
  > 00_custom_configs/webprotege/patches/docker-build/docker-build.patch
```

## Patches

| Folder | What it adds |
|--------|----------------|
| [docker-build](docker-build/) | Image build without embedded MongoDB; skip test compile |
| [oidc-sso](oidc-sso/) | Keycloak / OIDC login and local user provisioning |
| [project-api](project-api/) | Owner `CAN_MANAGE` on create; collaborator PUT/DELETE; trash DELETE |

Traefik, networks, and volumes stay in `00_custom_configs/webprotege/docker/docker-compose.override.yml`, not in these patches.
