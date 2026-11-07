# SCS-Manager-Image aktualisieren

Prime behält die Config der bereits installierten Site. Ein neues Image ersetzt die Composer-Packages und die mitgelieferten Seiten. Der Entrypoint spielt beides ein, wenn der Container aus diesem Image erzeugt wird. Er importiert keine Drupal-Config über die bestehende Site.

`docker restart` lädt kein neues Image. Die Schritte auf Prime ziehen das Image und erzeugen den Container neu.

`3.3.0` in jedem Befehl durch den Tag ersetzen, den du veröffentlichst. Denselben Tag in der `.env` auf Prime eintragen.

## Dev

Das läuft auf dem Dev-Host. Der Image-Bau klont das Theme von GitHub `main` und installiert `drupal/soda_scs_manager` von Drupal.org mit der Vorgabe im Image-Workflow (`SODA_SCS_MANAGER_VERSION`, derzeit `^4.0`). Commits, die nicht gepusht sind, sind nicht im Image.

### 1. Seiten exportieren und pushen

Diesen Schritt weglassen, wenn sich die mitgelieferten Seiten nicht geändert haben.

`content/manifest.yml` listet die Inhaltstypen, Node-UUIDs und Menüs, die der Export nach `content/sync` schreibt.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
./content/export-content.bash
git status
git add content/sync content/manifest.yml
git commit -m "Update the shipped home page and legal pages."
git push origin main
```

### 2. Image veröffentlichen

Ein neues Release `4.0.x` auf Drupal.org fällt unter die bestehende Vorgabe `^4.0`. Dafür muss der Workflow nicht geändert werden. Die Vorgabe nur in `repos/scs-manager-image/.github/workflows/build-image.yml` ändern, wenn sich die Zeile selbst ändert (`SODA_SCS_MANAGER_VERSION`, `SODA_SCS_MANAGER_DEV_VERSION`, `SCS_CUSTOM_THEME_REF`). Diese Datei committen und mit den Befehlen unten pushen.

Ein Push des Branch `3.x` veröffentlicht die Tags `scs-manager-image-production:3.x` und `scs-manager-image-development:3.x`. Prime pinnt den Versions-Tag.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/repos/scs-manager-image
git push origin 3.x
git tag 3.3.0
git push origin 3.3.0
```

Der zweite Push veröffentlicht `scs-manager-image-production:3.3.0` (und die Tags `3.3` und `3`). Mit den Schritten auf Prime warten, bis der Workflow [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) grün ist.

## Prime

Das läuft auf Prime, im Deployment-Checkout. `SCS_MANAGER_MODE` bleibt `production`.

### 3. `.env` auf den neuen Tag setzen

```bash
cd /var/deploy/soda_scs_manager_deployment
grep -E '^(SCS_MANAGER_MODE|SCS_MANAGER_IMAGE_VERSION)=' .env
```

Setzen:

```bash
SCS_MANAGER_MODE=production
SCS_MANAGER_IMAGE_VERSION=3.3.0
```

Denselben Tag wie bei `git tag` auf Dev verwenden. Die `.env` wird nicht committet.

### 4. Prüfen, dass das Image wirklich läuft

Diese Ziele dürfen nicht erscheinen. Ein Bind-Mount verdeckt Theme und Modul aus dem Image.

```bash
docker inspect manager--drupal--app --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' | grep -E 'scs_custom_theme|soda_scs_manager' || echo "no theme or module bind mount"
```

### 5. Image ziehen und den Container neu erzeugen

```bash
cd /var/deploy/soda_scs_manager_deployment
docker compose pull manager--drupal--app
docker compose up -d manager--drupal--app
docker compose logs -f manager--drupal--app
```

Die Logs offen lassen, bis nginx läuft. Dann diese Zeilen suchen:

- `Package set changed` — `drush updatedb -y` und `drush cr` sind gelaufen. Auf einer bestehenden Site gibt es kein `drush config:import`.
- `Shipped content changed` — `content/import.php` ist gelaufen. Entitäten mit bekannter UUID werden aktualisiert. Neue UUIDs werden angelegt.
- `ERROR:` — dieser Schritt hat seinen Fingerabdruck nicht geschrieben. Das nächste `docker compose up -d manager--drupal--app` versucht es erneut.

Ein Start ohne `Package set changed` und ohne `Shipped content changed` hat beide Fingerabdrücke unverändert gefunden und nichts getan.

## Was auf Prime bleibt

| Kommt aus dem Image | Bleibt |
| --- | --- |
| Composer-Packages, einschließlich `drupal/soda_scs_manager` mit der Vorgabe aus dem Image | `soda_scs_manager.settings`, OpenID, Rollen, Benutzer, Projekte und jede andere Config, die schon auf der Site liegt |
| Seiten und Menülinks in `scs_custom_theme/content/sync` | Die Startseite, außer sie steht noch auf `/node` |

Theme-Config, die es noch nicht gibt (die Inhaltstypen der Startseite), wird installiert. Config-Namen, die schon existieren, werden nicht ersetzt.

`SODA_SCS_MANAGER_VERSION` in der Deployment-`.env` wird beim Containerstart nicht gelesen. Compose wählt das Image nur über `SCS_MANAGER_MODE` und `SCS_MANAGER_IMAGE_VERSION`.

Der erste Start, wenn `settings.php` fehlt, installiert Drupal und importiert `/opt/drupal/sync/configs`. Dieser Pfad gilt nicht für dieses Update.
