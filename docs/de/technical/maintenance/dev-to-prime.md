# Änderungen von Dev auf Prime bringen

Dev-Checkout: `/var/www/deploy/soda_scs_manager_deployment`. Prime-Checkout: `/var/deploy/soda_scs_manager_deployment`. Die `.env` wird nicht committet und nicht von Dev nach Prime kopiert.

Es gibt zwei Wege. Nimm den, der zur Änderung passt. Haben sich beide geändert, zuerst Weg A auf Dev pushen. Auf Prime zuerst das Deployment auschecken und den Manager-Container erst am Ende von Weg B neu erzeugen.

## Mit einem Befehl

Auf Prime erledigt `update-stack.bash --prime` die Prime-Seite beider Wege: Weg A, Schritt 2 und 3, und Weg B, Schritt 5. Die Schritte auf Dev (pushen, releasen, taggen) bleiben Handarbeit. Die Abschnitte unten bleiben als Referenz dafür, was das Skript tut.

```bash
cd /var/deploy/soda_scs_manager_deployment
./01_scripts/global/update-stack.bash --prime --check   # nur der Plan, ändert nichts
./01_scripts/global/update-stack.bash --prime --apply   # nachdem du den Plan gelesen hast
```

`--check` zeigt, welche Repos auf welchen festgehaltenen Zeiger gehen (mit Commit-Log), was gebaut, neu erzeugt und kopiert wird, welche Systemd-Units abweichen, die neuen CHANGELOG-Abschnitte und die aktuellen Drupal-Checks. Es endet mit 1, wenn etwas das Update blockiert, zum Beispiel nicht committete Änderungen.

`--apply` macht dann:

1. Das Deployment wird vorgespult, danach läuft `git submodule update --init --recursive` ohne `--remote`.
2. Geänderte Override-Quellen werden nach `scs-manager-stack/` und `scs-project-website-stack/` kopiert, außer die Kopie dort hat lokale Änderungen.
3. Geänderte Systemd-Units werden als root installiert, sonst gibt das Skript die `sudo`-Befehle aus.
4. Vor dem ersten neu erzeugten Container werden alle Datenbanken nach `/srv/backups/pre-update/<Zeitstempel>/` gesichert. Wechselt die Nextcloud-Version, läuft zusätzlich `backup-nextcloud.bash`.
5. Die betroffenen Container werden gebaut und neu erzeugt (Tabelle in [Schritt 3](#3-die-betroffenen-container-neu-erzeugen)).
6. Das SCS-Manager-Image wird gezogen und das Log verfolgt ([Weg B, Schritt 5](#5-auf-prime-das-image-starten)), aber nur, wenn der Container keinen Bind-Mount auf Modul oder Theme hat.
7. Geprüft werden `docker compose ps`, `drush updatedb:status`, `drush scs:check --problems` und die aktiven Themes.
8. Am Ende stehen die übrigen Handgriffe: `sudo`-Befehle, der Nextcloud-Repair und die fetten Zeilen aus den CHANGELOGs.

Optionen: `--no-snapshot` lässt die Datenbanksicherung weg, `--since <Commit>` legt den Deployment-Commit fest, ab dem verglichen wird (Standard: das letzte erfolgreiche `--prime --apply`), und `--offline` plant ohne Fetch. Braucht der SSH-Key eine Passphrase, liest Git öffentliche Repos über HTTPS.

`SCS_MANAGER_IMAGE_VERSION` wird nur angezeigt. Mit einer vollen Version wie `3.3.1` kommt kein neueres Manager-Image, bis dort `3` steht.

## Weg A: Deployment und Submodule

Das gilt für JupyterHub, Nextcloud, Keycloak, OpenGDB, WebProtégé, Voyager, Health, die Project Website und für Compose, Overrides und Skripte im Deployment. Auch für den `scs-manager-stack`, solange sich nur dessen Compose ändert und nicht Modul, Theme oder Seiten.

### 1. Auf Dev pushen, von innen nach außen

Im Repo committen und pushen, in dem die Dateien liegen. Liegt das Repo in einem Submodule, danach im darüberliegenden Repo den neuen Zeiger committen und pushen. Die Kette endet im Deployment auf `main`.

JupyterHub:

```bash
cd /var/www/deploy/soda_scs_manager_deployment/jupyterhub
git push
cd /var/www/deploy/soda_scs_manager_deployment
git add jupyterhub
git commit -m "Point JupyterHub at the hub change."
git push origin main
```

Dieselbe Kette für `keycloak`, `scs-nextcloud-stack`, `open_gdb`, `webprotege`, `scs-health`, `scs-voyager`, `scs-project-website-stack` und `scs-manager-stack`.

Die Nextcloud-App `scs_manager_integration` ist ein Submodule von `scs-nextcloud-stack`. Zuerst die App pushen, dann den Zeiger im Nextcloud-Stack, dann den Zeiger im Deployment.

Liegt die Änderung nur im Deployment (`docker-compose.yml`, `00_custom_configs/`, `01_scripts/`), reicht der Push von `main`.

### 2. Auf Prime auschecken

`start.sh` zieht Submodule mit `--remote` auf den Branch-Kopf, nicht auf den Zeiger aus dem Deployment-Commit. Für dieses Update die beiden Befehle einzeln:

```bash
cd /var/deploy/soda_scs_manager_deployment
git pull
git submodule update --init --recursive
```

Compose liest die Overrides von JupyterHub, Keycloak, Nextcloud, OpenGDB, WebProtégé, Health und Voyager direkt aus `00_custom_configs/`. Für den SCS Manager und die Project Website liest es die gitignorierte Kopie im Stack. Nach einer Änderung an der Quelle die Kopie ersetzen:

```bash
cp 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml scs-manager-stack/docker-compose.override.yml
cp 00_custom_configs/scs-project-website-stack/docker/docker-compose.override.yml scs-project-website-stack/docker-compose.override.yml
```

Haben sich Unit-Dateien unter `01_scripts/global/` geändert, sie neu nach `/etc/systemd/system/` kopieren und `systemctl daemon-reload` ausführen. Die Befehle stehen in [Pre-start steps](../initial-setup/pre-start-steps.md#host-preparation-once-per-host-before-startsh).

### 3. Die betroffenen Container neu erzeugen

Ein `git pull` ändert einen laufenden Container nicht. `docker restart` lädt kein neues Image und keinen neuen Build.

| Geändert | Befehl auf Prime |
| --- | --- |
| JupyterHub | `docker compose up -d --build jupyterhub--jupyterhub--app` |
| Notebook-Image | `docker compose build jupyterhub--spawner--builder` |
| Nextcloud, gleicher Versionsstand | `docker compose up -d nextcloud--nextcloud--app` |
| Nextcloud-App `scs_manager_integration` | `docker compose up -d nextcloud--nextcloud--app` |
| OnlyOffice | `docker compose pull nextcloud--ods--app && docker compose up -d nextcloud--ods--app` |
| Keycloak | `docker compose up -d --build keycloak--keycloak--app` |
| WebProtégé | `docker compose up -d --build webprotege--webprotege--app` |
| Health | `docker compose up -d --build health--health--app` |
| Voyager | `docker compose up -d --build voyager--voyager--app` |
| Project Website | `docker compose up -d --build scs-project-website--drupal` |
| OpenGDB | `docker compose up -d --build` mit dem geänderten Container (`opengdb--nginx--edge`, `opengdb--rdf4j--db`, `opengdb--authproxy--proxy`, `opengdb--outproxy--proxy`) |
| Traefik, MariaDB, Portainer, nur neues Image-Tag | `docker compose pull <container> && docker compose up -d <container>` |
| SCS-Manager-Compose, ohne Modul, Theme oder Seiten | `docker compose up -d manager--drupal--app` |

Wechselt die Nextcloud-Version, zuerst sichern und danach die Repair-Schritte aus [Updates](updates.md#nextcloud-aktualisieren) ausführen. Ein Recreate mitten in der Migration abbrechen lässt die Instanz in Maintenance.

## Weg B: SCS Manager, Modul, Theme und Seiten

Dev bindet Modul und Theme aus den Checkouts. Prime startet die Kopien aus dem Production-Image. Ein Push von Modul oder Theme allein ändert Prime nicht.

Reihenfolge: Seiten packen, Theme pushen, Modul releasen, Image taggen, auf Prime ziehen. Einen Schritt weglassen, dessen Baum sich nicht geändert hat.

### 1. Seiten nach `content/sync` packen

Die Startseite, die Abschnitte und die Menüs liegen als YAML im Theme `scs_custom_theme`, Verzeichnis `content/sync`. `content/manifest.yml` listet die Inhaltstypen, Node-UUIDs und Menüs. Der Export liest diese Entitäten aus der laufenden Dev-Site und schreibt die YAML-Dateien neu. Der Import auf Prime legt Entitäten mit bekannter UUID an oder aktualisiert sie.

Dev muss laufen, der Export geht per Drush in `manager--drupal--app`.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
./content/export-content.bash
git status
git add content/sync content/manifest.yml
git commit -m "Update the shipped home page and legal pages."
git push origin main
```

### 2. Theme pushen

Der Image-Bau klont `scs_custom_theme` von Branch `main`. Commits, die nicht auf diesem Branch liegen, fehlen im Image. Das Styling der Manager-Oberfläche liegt im Modul (`css/soda-scs-manager.css`) und kommt mit dem Modul-Release. Schritt 1 hat `scs_custom_theme` schon gepusht, wenn sich nur die Seiten geändert haben.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
git push origin main
```

### 3. Modul releasen

Der Production-Bau installiert `drupal/soda_scs_manager` mit `^4.3` von Drupal.org. Der Branch `4.x` allein ist nicht im Production-Image.

Vor dem Tag den Abschnitt `[Unreleased]` in `CHANGELOG.md` in die neue Version schieben. `4.1.1` durch den nächsten Tag ersetzen, höher als der letzte (`git tag -l '4.*' --sort=-v:refname | head -1`). `origin` ist `git.drupal.org`. Ein Tag nur auf dem GitHub-Fork reicht nicht.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager
git push origin 4.x
git tag 4.1.1
git push origin 4.1.1
```

Warten, bis das Release unter [soda_scs_manager releases](https://www.drupal.org/project/soda_scs_manager/releases) steht.

### 4. Image taggen

`git tag -l '3.*' --sort=-v:refname | head -1` im Image-Repo zeigt den letzten Tag. Ein Push von `main` veröffentlicht nur `:main`. Prime pinnt den Major-Tag `3`. Ein Versions-Tag wie `3.3.5` setzt `3.3.5`, `3.3` und `3`.

```bash
cd /var/www/deploy/soda_scs_manager_deployment/repos/scs-manager-image
git push origin main
git tag 3.3.5
git push origin 3.3.5
```

Warten, bis [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) grün ist. `3.3.5` durch den nächsten Tag ersetzen.

Die Vorgabe `^4.3` nur in `repos/scs-manager-image/.github/workflows/build-image.yml` ändern, wenn sich die Zeile selbst ändert (`SODA_SCS_MANAGER_VERSION`, `SODA_SCS_MANAGER_DEV_VERSION`, `SCS_CUSTOM_THEME_REF`). Diese Datei vor dem Tag committen und mit pushen.

### 5. Auf Prime das Image starten

Zuerst [Weg A, Schritt 2](#2-auf-prime-auschecken), wenn sich auch das Deployment geändert hat.

`SCS_MANAGER_MODE` bleibt `production`. `SCS_MANAGER_IMAGE_VERSION` bleibt `3`. Der Tag zeigt auf das neueste Release der Major-Version 3. Nur ein neues Major (4.0) ändert die Zeile. Zum Zurückrollen die volle Version eintragen, zum Beispiel `3.3.4`.

Diese Mount-Ziele dürfen nicht erscheinen. Ein Bind-Mount verdeckt Theme und Modul aus dem Image.

```bash
cd /var/deploy/soda_scs_manager_deployment
docker inspect manager--drupal--app --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' | grep -E 'scs_custom_theme|soda_scs_manager' || echo "no theme or module bind mount"
docker compose pull manager--drupal--app
docker compose up -d manager--drupal--app
docker compose logs -f manager--drupal--app
```

Die Logs offen lassen, bis nginx läuft. Dann diese Zeilen suchen:

- `Package set changed` — `drush updatedb -y` und `drush cr` sind gelaufen. Auf einer bestehenden Site gibt es kein `drush config:import`.
- `Shipped content changed` — `content/import.php` ist gelaufen. Entitäten mit bekannter UUID werden aktualisiert. Neue UUIDs werden angelegt.
- `ERROR:` — dieser Schritt hat seinen Fingerabdruck nicht geschrieben. Das nächste `docker compose up -d manager--drupal--app` versucht es erneut.

Ein Start ohne `Package set changed` und ohne `Shipped content changed` hat beide Fingerabdrücke unverändert gefunden und nichts getan.

#### Wenn Prime noch die Bind-Mounts hat

Prime kann Modul und Theme noch aus Host-Checkouts einbinden, so wie Dev. Dann ändert ein neues Image nichts, `drush scs:check` fehlt womöglich, und ausgemusterte Themes bleiben aktiv. `update-stack.bash --prime --check` meldet das als `SCS Manager image: SKIPPED`. Die Mounts stehen in der gitignorierten Kopie `scs-manager-stack/docker-compose.override.yml`, nicht in der Quelle unter `00_custom_configs/`.

**1. Prüfen, dass das Image nicht älter ist als die Site.** Jede Update-Hook-Nummer, die die Datenbank kennt, muss es im Image geben. Das Image darf mehr haben; die laufen beim Start.

```bash
cd /var/deploy/soda_scs_manager_deployment
IMAGE=ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production:3
docker pull -q "$IMAGE"
# Schema-Version der Site
docker exec manager--drupal--app drush ev "echo \Drupal::service('update.update_hook_registry')->getInstalledVersion('soda_scs_manager');"; echo
# Modulversion und neuester Update-Hook im Image
docker run --rm --entrypoint sh "$IMAGE" -c 'd=/opt/drupal/web/modules/contrib/soda_scs_manager; grep -m1 "^version" $d/*.info.yml; grep -oE "^function soda_scs_manager_update_[0-9]+" $d/soda_scs_manager.install | grep -oE "[0-9]+$" | sort -n | tail -1'
```

Ist der neueste Hook im Image kleiner als die Schema-Version, hier aufhören: erst das Modul releasen und das Image taggen (Schritt 3 und 4).

**2. Sichern, was es nur auf Prime gibt.** Nicht committete Änderungen in den Host-Checkouts sind weg, sobald das Image läuft. Sie sichern, auf Dev einspielen und mit dem nächsten Release ausliefern.

```bash
BACKUP=/srv/backups/pre-update/$(date +%Y%m%d_%H%M%S)-manual; mkdir -p "$BACKUP"
M=scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager
git -C "$M" status --short
git -C "$M" diff > "$BACKUP/soda_scs_manager-prime-local.patch"
cp scs-manager-stack/docker-compose.override.yml "$BACKUP/scs-manager-stack.docker-compose.override.yml"
```

Dasselbe für die Theme-Checkouts unter `…/web/themes/custom/`.

**3. Mounts entfernen und dem Major-Tag folgen.** Unterscheidet sich die Kopie von der Quelle nur durch die beiden Mount-Zeilen (`diff scs-manager-stack/docker-compose.override.yml 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml`), die Quelle darüberkopieren. Sonst die beiden Zeilen von Hand löschen.

```bash
cp 00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml scs-manager-stack/docker-compose.override.yml
sed -i 's/^SCS_MANAGER_IMAGE_VERSION=.*/SCS_MANAGER_IMAGE_VERSION=3/' .env
./01_scripts/global/update-stack.bash --prime --check   # jetzt: "docker compose pull manager--drupal--app"
./01_scripts/global/update-stack.bash --prime --apply
```

Das Skript sichert zuerst alle Datenbanken und erzeugt dann den Manager neu. Zu erwarten sind `Package set changed` (die neuen Update-Hooks laufen, ein ausgemustertes Theme wird deinstalliert) und meist `Shipped content changed`. Danach müssen `drush scs:check --problems` und die Theme-Prüfung grün sein. Zeigt ein Host-Timer direkt nach dem Start `never ran`, seinen nächsten Lauf abwarten: Ein Heartbeat während des Neustarts geht verloren.

Danach Theme-Checkouts löschen, die der CHANGELOG ausmustert, zum Beispiel `…/web/themes/custom/soda_scs_manager_theme`, sobald `git status` und `git log --branches --not --remotes` nichts Lokales zeigen.

**4. Zurück, wenn der Manager nicht hochkommt.**

```bash
cp "$BACKUP/scs-manager-stack.docker-compose.override.yml" scs-manager-stack/docker-compose.override.yml
sed -i 's/^SCS_MANAGER_IMAGE_VERSION=.*/SCS_MANAGER_IMAGE_VERSION=3.3.1/' .env   # die Version, die vorher lief
docker compose up -d manager--drupal--app
```

Sind die Datenbank-Updates schon gelaufen, passt das alte Modul womöglich nicht zum neuen Schema. Dann zusätzlich den Dump zurückspielen, den `--prime --apply` nach `/srv/backups/pre-update/<Zeitstempel>/all-databases.sql.gz` geschrieben hat, mit allen schreibenden Containern gestoppt.

### Was auf Prime liegen bleibt

| Kommt aus dem Image | Bleibt |
| --- | --- |
| Composer-Packages, einschließlich `drupal/soda_scs_manager` mit der Vorgabe aus dem Image | `soda_scs_manager.settings`, OpenID, Rollen, Benutzer, Projekte und jede andere Config, die schon auf der Site liegt |
| Seiten und Menülinks in `scs_custom_theme/content/sync` | Die Startseite, außer sie steht noch auf `/node` |

Theme-Config, die es noch nicht gibt (die Inhaltstypen der Startseite), wird installiert. Config-Namen, die schon existieren, werden nicht ersetzt.

`SODA_SCS_MANAGER_VERSION` in der Deployment-`.env` wird beim Containerstart nicht gelesen. Compose wählt das Image nur über `SCS_MANAGER_MODE` und `SCS_MANAGER_IMAGE_VERSION`.
