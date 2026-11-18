# SCS-Manager-Image aktualisieren

Compose wählt das Image nur über `SCS_MANAGER_MODE` und `SCS_MANAGER_IMAGE_VERSION`:

`ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-${SCS_MANAGER_MODE}:${SCS_MANAGER_IMAGE_VERSION}`

Modul-Release-Tags, Image-Release-Tags und das Rolling-Development-Image sind drei verschiedene Dinge. Nicht vermischen.

## Tag-Regeln

| Tag | Rolle |
|---|---|
| `:main` | Offizielles Rolling-Development-Image. Die CI veröffentlicht es bei jedem Push auf `main` in [scs-manager-image](https://github.com/soda-collections-objects-data-literacy/scs-manager-image). |
| `:local` | Nur für selbst gebaute Images (Dockerfile- oder Entrypoint-Arbeit vor der CI). Nicht der Standard auf dem gemeinsamen Dev-Host. |
| `:3`, `:3.7.0`, … | Release-/Kompatibilitätsreferenzen. Prime nutzt den Floating-Major (`SCS_MANAGER_IMAGE_VERSION=3`). |

### Dev-Host

```bash
SCS_MANAGER_MODE=development
SCS_MANAGER_IMAGE_VERSION=main
```

Auf dem gemeinsamen Dev-Host keinen Floating-Major (`3`) und keine volle SemVer pinnen. Modul und Theme kommen weiter aus den Bind-Mount-Checkouts (`4.x` / `main`); der Image-Tag ersetzt diese Mounts nicht.

Bewusst aktualisieren:

```bash
# aus dem Deployment-Repo-Root
docker compose pull manager--drupal--app
docker compose up -d --force-recreate manager--drupal--app
```

`pull` allein bewegt keinen laufenden Container. Ein Container behält seine Image-ID, wenn der Tag später woanders hinzeigt (dangling / untagged), bis er neu erstellt wird.

Nur für lokale Image-Arbeit: mit `-t …/scs-manager-image-development:local` bauen, `SCS_MANAGER_IMAGE_VERSION=local` setzen, recreaten, danach wieder auf `main`.

### Prime

`SCS_MANAGER_MODE=production` und `SCS_MANAGER_IMAGE_VERSION=3`. Modul, Theme und Seiten ausliefern: [Änderungen von Dev auf Prime bringen](dev-to-prime.md#weg-b-scs-manager-modul-theme-und-seiten).
