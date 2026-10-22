# Voyager 3D viewer

**Smithsonian DPO Voyager** ([github.com/Smithsonian/dpo-voyager](https://github.com/Smithsonian/dpo-voyager)) is a browser-based 3D viewer for scenes (`*.svx.json`) and glTF models. The deployment builds it from the git submodule at `scs-voyager/` and serves it as static files from container `voyager--voyager--app` (alias `scs--voyager`) behind Traefik. Drupal sites (SCS Manager, WissKI instances) embed it via iframe or as a web component.

## Stack wiring

| Piece | Location |
| --- | --- |
| Submodule | `scs-voyager/` → `https://github.com/Smithsonian/dpo-voyager.git` (pinned to a release tag) |
| Image build | `00_custom_configs/voyager/docker/Dockerfile` (Node build → `nginx:${NGINX_VERSION}-alpine`) |
| Compose service | `00_custom_configs/voyager/docker/docker-compose.override.yml` |
| nginx config | `00_custom_configs/voyager/nginx/default.conf.template` |
| Model volume | `voyager--files` → `/usr/share/nginx/html/files` (read-only) |
| `COMPOSE_FILE` entry | `00_custom_configs/voyager/docker/docker-compose.override.yml` |

The upstream `scs-voyager/docker-compose.yml` is a development server with WebDAV write access and is **not** part of `COMPOSE_FILE`.

The Dockerfile changes two things in the upstream source before building:

- **System assets** (fonts, Draco and Basis decoders) load from `https://${VOYAGER_DOMAIN}/` instead of `cdn.jsdelivr.net/…@latest`. Embeds need no `resourceRoot` attribute and make no CDN requests.
- **Google Analytics** is only rendered when `VOYAGER_ANALYTICS_ID` is set at build time (upstream renders it in every production build).

It builds the offline variant (local favicon and fonts) of all apps: `voyager-explorer`, `voyager-mini`, `voyager-story`, `voyager-launcher`.

## Environment variables

Set in the **root** `.env` (see `example-env`):

| Variable | Purpose |
| --- | --- |
| `VOYAGER_DOMAIN` | Hostname (default `3d.${SCS_SUBDOMAIN}.${SCS_BASE_DOMAIN}`). Baked into the bundle: rebuild after changing it. |
| `VOYAGER_CORS_ORIGIN` | `Access-Control-Allow-Origin` for bundle, fonts and models (default `*`) |
| `VOYAGER_FRAME_ANCESTORS` | CSP `frame-ancestors` for iframe embeds (default `'self' https://${SCS_BASE_DOMAIN} https://*.${SCS_BASE_DOMAIN}`) |

## Build and start

```bash
docker compose build voyager--voyager--app
docker compose up -d voyager--voyager--app
curl -fsS https://${VOYAGER_DOMAIN}/healthz
```

`https://${VOYAGER_DOMAIN}/` redirects to `voyager-explorer.html` and keeps the query string.

## Hosting models

Models and scenes can live anywhere that sends CORS headers for the Drupal origin. For files hosted by this service, copy them into the `voyager--files` volume; they are served under `https://${VOYAGER_DOMAIN}/files/`:

```bash
docker run --rm -v voyager--files:/files -v "$PWD/my-object:/src:ro" alpine \
  cp -r /src /files/my-object
```

Another container (e.g. Drupal) can mount the same volume read-write to publish models.

## Embedding in Drupal

### iframe

Works in any text format that allows `<iframe>`. Parameters: `document` (scene, `.svx.json`) **or** `model` (single `.glb`), relative to `root` (or absolute URLs).

```html
<iframe
  src="https://3d.scs.example.org/voyager-explorer.html?root=https://3d.scs.example.org/files/my-object/&document=scene.svx.json"
  width="100%" height="600" allow="fullscreen; xr-spatial-tracking" allowfullscreen
  style="border:0"></iframe>
```

The embedding site must match `VOYAGER_FRAME_ANCESTORS`.

### Web component

Load the bundle once (e.g. as an external library in the theme or module `*.libraries.yml`) and place the element:

```yaml
voyager:
  js:
    https://3d.scs.example.org/js/voyager-explorer.min.js: { type: external, minified: true }
```

```html
<voyager-explorer
  root="https://3d.scs.example.org/files/my-object/"
  document="scene.svx.json"
  style="display:block; width:100%; height:600px"></voyager-explorer>
```

Further attributes (also usable as iframe query parameters): `model`, `quality`, `uiMode`, `bgColor`, `bgStyle`, `controls`, `prompt`, `lang`. See the [Voyager documentation](https://smithsonian.github.io/dpo-voyager/).

## Updating Voyager

```bash
git -C scs-voyager fetch --tags
git -C scs-voyager checkout v0.xx.y
git add scs-voyager && git commit -m "chore(voyager): bump to v0.xx.y"
docker compose build voyager--voyager--app && docker compose up -d voyager--voyager--app
```

`start.sh` runs `git submodule update --remote`, which moves `scs-voyager/` to upstream `master`. Check out the release tag again before building if you need a pinned version.

The Dockerfile fails the build if upstream renames the patched strings (`CVAssetReader.ts` default asset path, Analytics block in `explorer.hbs`); adjust the `sed` patterns in that case.
