# Updates und Wartung

Diese Seite beschreibt, wie Dienste aktualisiert werden, vor allem Nextcloud, und was danach zu tun ist.

---

## Allgemeines Vorgehen

Die Dienste laufen als Docker-Images mit Versions-Tag (zum Beispiel `nextcloud:31.0-fpm`, `onlyoffice/documentserver:8.3`). Ein Update geht so:

1. **Changelog des Dienstes lesen**: Breaking Changes, neue Voraussetzungen, Migrationshinweise.
2. **Image-Tag ändern** in der passenden `docker-compose.yml` oder im Override.
3. **Neues Image ziehen** und den Container neu erzeugen.
4. **Nacharbeiten ausführen** (Migrationen, Repair, Config), wie der Dienst sie beschreibt.
5. **Prüfen**, ob der Dienst richtig läuft.

Vor Major-Updates immer Datenbanken und Volumes sichern.

---

## Nextcloud aktualisieren

Nextcloud hat Zustand: Datenbank, Dateien und Apps. Ein Update braucht Sorgfalt, sonst gehen Daten oder Funktionen verloren.

### Vor dem Update

1. **Datenbank und Volumes sichern**

   Mit dem Backup-Skript aus dem Repo-Root:

   ```bash
   01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
   ```

   Das Skript:
   - schaltet den Maintenance-Modus ein,
   - sichert die Datenbank nach `/srv/backups/nextcloud/nextcloud-db_TIMESTAMP.sql`,
   - sichert das Volume `nextcloud-data` nach `/srv/backups/nextcloud/nextcloud-data_TIMESTAMP.tar.gz`,
   - sichert auf Nachfrage das Volume `onlyoffice-data`,
   - schaltet den Maintenance-Modus wieder aus.

   Alternativ von Hand:

   ```bash
   docker exec core--mariadb--db mariadb-dump -u root -p"${SCS_DB_ROOT_PASSWORD}" "${NEXTCLOUD_DB_NAME}" > nextcloud-backup-$(date +%Y%m%d).sql
   ```

2. **Release Notes von Nextcloud lesen**

   Unter [Nextcloud releases](https://nextcloud.com/changelog/) den Changelog der Zielversion lesen. Darauf achten:
   - geforderte PHP-Version,
   - geforderte Datenbankversion (zum Beispiel MariaDB 10.6–11.4),
   - Breaking Changes, entfernte oder geänderte Apps,
   - Upgrade-Pfad (zum Beispiel erst 30.x, dann 31.x).

3. **App-Kompatibilität prüfen**

   Manche Apps (zum Beispiel Social Login, der OnlyOffice-Connector) brauchen ein Update oder unterstützen die neue Version noch nicht. Im Nextcloud-App-Store oder im Repository der App nachsehen.

### Update durchführen

1. **Image-Tag ändern**

   In `scs-nextcloud-stack/docker-compose.yml`:

   ```yaml
   nextcloud--nextcloud--app:
     image: nextcloud:31.0-fpm  # zum Beispiel auf nextcloud:32.0-fpm ändern
   ```

2. **Image ziehen und Container neu erzeugen**

   Im Repo-Root:

   ```bash
   docker compose pull nextcloud--nextcloud--app
   docker compose up -d nextcloud--nextcloud--app
   ```

   Der Container erkennt die neue Version und führt die Datenbankmigrationen beim Start selbst aus. **Das kann Minuten bis Stunden dauern**, je nach Größe der Instanz. Die Logs mitlesen:

   ```bash
   docker compose logs -f nextcloud--nextcloud--app
   ```

   Typische Meldungen:
   - „Nextcloud is already the latest version or newer“ (schon aktuell),
   - „Nextcloud is in maintenance mode“ (Migration läuft),
   - „Starting web server“ (fertig).

3. **Auf das Ende der Migration warten**

   Den Container während der Migration nicht stoppen. Bricht er mit einem Fehler ab, die Logs lesen und die Nextcloud-Doku zum Fehler prüfen.

### Nacharbeiten

Wenn das Update fertig ist und Nextcloud läuft, im Repo-Root:

1. **Maintenance-Modus ausschalten** (falls noch an)

   ```bash
   docker exec nextcloud--nextcloud--app php /var/www/html/occ maintenance:mode --off
   ```

2. **Wartungs- und Repair-Aufgaben ausführen**

   Das Skript erledigt die üblichen Nacharbeiten (MIME-Migrationen, fehlende Indizes, Spalten und Primärschlüssel):

   ```bash
   01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
   ```

   Auf großen Instanzen dauert das lange. Das Skript führt aus:
   - `occ maintenance:repair --include-expensive`
   - `occ db:add-missing-indices`
   - `occ db:add-missing-columns`
   - `occ db:add-missing-primary-keys`

3. **Apps aktualisieren**

   ```bash
   docker exec nextcloud--nextcloud--app php /var/www/html/occ app:update --all
   ```

   Oder in der Weboberfläche: Admin → Apps → Updates.

4. **App-Kompatibilität prüfen**

   Inkompatible Apps werden beim Upgrade abgeschaltet. In der App-Verwaltung nachsehen und passende Apps wieder einschalten oder aktualisieren. Gibt es noch keine kompatible Version, die App abgeschaltet lassen.

5. **Proxy- und Regionseinstellungen erneut anwenden** (falls nötig)

   Falls das Upgrade Einstellungen zurückgesetzt hat (selten):

   ```bash
   01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
   ```

6. **Admin-Warnungen prüfen**

   Als Admin unter Einstellungen → Verwaltung → Übersicht nachsehen. Nach dem Repair-Skript (Schritt 2) sind die meisten Datenbankwarnungen weg. Übrige Warnungen nennen den passenden `occ`-Befehl.

7. **Funktionen testen**

   - als Benutzer anmelden,
   - Dateien hoch- und herunterladen,
   - OnlyOffice testen (ein Dokument öffnen),
   - SSO-Anmeldung über Keycloak testen,
   - Hintergrundjobs prüfen (Einstellungen → Verwaltung → Grundeinstellungen → Hintergrundjobs: „Cron“, letzter Lauf vor kurzem).

### Häufige Probleme

#### Maintenance-Modus hängt

**Symptom:** Nextcloud zeigt nach dem Upgrade „System in maintenance mode“.

**Lösung:**

```bash
docker exec nextcloud--nextcloud--app php /var/www/html/occ maintenance:mode --off
```

In den Logs nach dem Fehler suchen, der das Upgrade aufgehalten hat.

#### Datenbankmigration schlägt fehl

**Symptom:** SQL-Fehler oder „Failed to run migration“ in den Container-Logs.

**Lösungen:**

- MariaDB-Version prüfen (Nextcloud 31 empfiehlt MariaDB 10.6–11.4).
- Backup zurückspielen, Ursache beheben, Upgrade erneut starten.
- Im Nextcloud-Forum oder in den GitHub-Issues nach dem Fehler suchen.

#### Apps nach dem Upgrade abgeschaltet

**Symptom:** Apps wie Social Login, OnlyOffice oder eigene Apps sind aus.

**Lösung:**

```bash
docker exec nextcloud--nextcloud--app php /var/www/html/occ app:list
docker exec nextcloud--nextcloud--app php /var/www/html/occ app:enable <app-name>
```

Ist eine App inkompatibel, auf ein Update warten und sie so lange abgeschaltet lassen.

Team Folders (`groupfolders`) und `scs_manager_integration` schaltet `scs-nextcloud-stack/hooks/post-upgrade/ensure-scs-apps.sh` beim nächsten Image-Upgrade wieder ein. Auf einer Instanz, auf der diese Apps nie installiert waren, einmal `install-scs-manager-integration.sh` ausführen, wie in der [Post-Configuration-Checkliste](../post-configuration/checklist.md) beschrieben.

#### OnlyOffice oder SSO nach dem Upgrade kaputt

**Symptom:** Dokumente öffnen sich nicht in OnlyOffice, oder die Keycloak-Anmeldung schlägt fehl.

**Lösungen:**

- **OnlyOffice:** Prüfen, ob die App an und richtig eingestellt ist. Unter Einstellungen → Verwaltung → OnlyOffice müssen URL des Document Servers und JWT-Secret zur `.env` passen.
- **SSO:** Prüfen, ob Social Login an ist und Issuer, Client-ID und Secret zum Keycloak-Realm passen. Den Post-Install-Hook erneut ausführen oder die App von Hand einstellen.

#### Reverse-Proxy-Warnungen sind wieder da

**Symptom:** Die Admin-Übersicht meldet „The reverse proxy header configuration is incorrect“.

**Lösung:**

```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

#### Nextcloud ist nach dem Upgrade langsam

**Symptom:** Nextcloud reagiert langsam oder gar nicht.

**Lösungen:**

- `occ db:add-missing-indices` ausführen.
- Prüfen, ob Redis läuft und Nextcloud es als Cache nutzt (die Admin-Übersicht zeigt sonst eine Cache-Warnung).
- CPU- und Speicherlimits des Containers prüfen und bei Bedarf anheben.

---

## Andere Dienste aktualisieren

### OnlyOffice Document Server

Die Version steht in `scs-nextcloud-stack/docker-compose.yml`:

```yaml
nextcloud--onlyoffice-document-server:
  image: onlyoffice/documentserver:8.3
```

Update:

1. Den [OnlyOffice-Changelog](https://github.com/ONLYOFFICE/DocumentServer/releases) auf Breaking Changes prüfen.
2. Den Image-Tag ändern.
3. Ziehen und neu erzeugen:

   ```bash
   docker compose pull nextcloud--onlyoffice-document-server
   docker compose up -d nextcloud--onlyoffice-document-server
   ```

4. In Nextcloud ein Dokument öffnen.

### Keycloak

Die Version steht in `keycloak/docker-compose.yml` (Variable `KC_VERSION`). Dem [Keycloak-Upgrade-Guide](https://www.keycloak.org/docs/latest/upgrading/index.html) folgen.

Wichtig:

- Vor dem Upgrade die Keycloak-Datenbank sichern.
- Die [Release Notes](https://www.keycloak.org/docs/latest/release_notes/index.html) auf Breaking Changes prüfen.
- Den Realm nur neu importieren, wenn Schemaänderungen das verlangen (selten).

### SCS Manager (Drupal)

Package-Versionen und mitgelieferte Seiten stecken im `scs-manager-image`. Prime zieht das Image und erzeugt den Container neu. Der Entrypoint führt die Datenbank-Updates und den Content-Import aus. Die bestehende Site-Config bleibt. Änderungen am Deployment und an den Submodulen sind auf Prime ein `git pull` und brauchen kein neues Image. Die ganze Reihenfolge, auch für JupyterHub, Nextcloud, das Modul-Release und das Packen der Seiten, steht unter [Dev nach Prime](dev-to-prime.md). Commits, Tags und Push-Plan bereitet [Release vorbereiten](release-prep.md) vor.

### JupyterHub, OpenGDB

Jeder Dienst hat seinen eigenen Upgrade-Weg. Allgemein:

1. Datenbank sichern.
2. Upgrade-Hinweise des Dienstes lesen.
3. Image-Tag in der passenden Compose-Datei ändern.
4. Ziehen und Container neu erzeugen.
5. Migrationen oder Skripte nach dem Upgrade ausführen, wie der Dienst sie beschreibt.

---

## Zurückrollen

Geht ein Update schief, aus dem Backup wiederherstellen.

### Mit dem Restore-Skript (empfohlen)

Im Repo-Root:

```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

Das Skript:
- listet die Backups mit Zeitstempel,
- stoppt die Nextcloud-Dienste,
- löscht die Datenbank und legt sie neu an,
- spielt das gewählte Datenbank-Backup ein,
- stellt das Volume `nextcloud-data` wieder her (falls gesichert),
- startet die Dienste und schaltet den Maintenance-Modus aus.

### Von Hand

1. **Den Dienst stoppen**:

   ```bash
   docker compose stop nextcloud--nextcloud--app nextcloud--nginx--edge
   ```

2. **Das Datenbank-Backup einspielen**:

   ```bash
   docker exec core--mariadb--db mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${NEXTCLOUD_DB_NAME};"
   docker exec core--mariadb--db mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${NEXTCLOUD_DB_NAME};"
   docker exec -i core--mariadb--db mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" "${NEXTCLOUD_DB_NAME}" < /srv/backups/nextcloud/nextcloud-db_TIMESTAMP.sql
   ```

3. **Den Image-Tag** in der Compose-Datei auf die alte Version zurücksetzen.

4. **Den Container neu erzeugen**:

   ```bash
   docker compose up -d nextcloud--nextcloud--app nextcloud--nginx--edge
   ```

5. **Prüfen**, ob der Dienst mit der alten Version und den gesicherten Daten läuft.

---

## Sichern und wiederherstellen

### Backup-Skript

```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**Was gesichert wird:**
- die Nextcloud-Datenbank (MariaDB-Dump),
- das Volume `nextcloud-data` (alle Dateien, Apps, Config),
- das Volume `onlyoffice-data` (auf Nachfrage).

**Ablage:** `/srv/backups/nextcloud/` mit Zeitstempel im Namen:
- `nextcloud-db_YYYYMMDD_HHMMSS.sql`
- `nextcloud-data_YYYYMMDD_HHMMSS.tar.gz`
- `onlyoffice-data_YYYYMMDD_HHMMSS.tar.gz` (falls gesichert)

Das Skript schaltet für die Dauer des Backups den Maintenance-Modus ein, packt die Volumes, zeigt die Größen und legt `/srv/backups/nextcloud/` an, falls es fehlt.

**Aufruf:**

```bash
cd /var/deploy/soda_scs_manager_deployment
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

Der aufrufende Benutzer braucht Schreibrechte auf `/srv/backups/`. Falls nötig:

```bash
sudo mkdir -p /srv/backups
sudo chown $(whoami):$(whoami) /srv/backups
```

**Empfehlungen:**
- vor Updates und größeren Änderungen sichern,
- regelmäßig sichern (zum Beispiel täglich per Cron),
- Backups extern oder auf einer eigenen Platte lagern,
- den Restore regelmäßig testen,
- mehrere Generationen aufheben.

### Restore-Skript

```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

Das Skript listet die Backups mit Größe, fragt nach dem gewünschten Backup, zeigt, was wiederhergestellt wird, verlangt eine Bestätigung (Eingabe „YES“), stoppt die Dienste, stellt die Daten wieder her und startet die Dienste neu.

!!! warning "Datenverlust"
    Der Restore überschreibt alle aktuellen Nextcloud-Daten. Nur zum gewollten Zurückrollen oder nach Datenverlust benutzen.

## Regelmäßige Wartung

### Nextcloud-Hintergrundjobs

Nextcloud nutzt Cron für Hintergrundjobs (Datei-Scans, Aufräumen). Das Deployment richtet Cron über einen Entrypoint-Hook im Container ein. Prüfen:

```bash
docker exec nextcloud--nextcloud--app php /var/www/html/occ background:cron
```

Den letzten Lauf zeigt Einstellungen → Verwaltung → Grundeinstellungen → Hintergrundjobs.

### Datenbankpflege

MariaDB regelmäßig mit `mariadb-dump` sichern (siehe oben) und die Backups sicher ablegen. Dafür bietet sich ein Cron-Job auf dem Host an.

### Alte Images und Volumes entfernen

Nach Updates bleiben alte Docker-Images liegen. Regelmäßig aufräumen:

```bash
docker image prune -a
docker volume prune  # Vorsicht: entfernt alle ungenutzten Volumes
```

---

## Checkliste für Nextcloud-Updates

- [ ] `01_scripts/scs-nextcloud-stack/backup-nextcloud.bash` ausführen.
- [ ] Release Notes und Upgrade-Pfad prüfen.
- [ ] Image-Tag in der Compose-Datei ändern.
- [ ] Image ziehen und Container neu erzeugen.
- [ ] Logs während der Migration mitlesen.
- [ ] Maintenance-Modus ausschalten, falls er hängt.
- [ ] `01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash` ausführen.
- [ ] Alle Apps aktualisieren (`occ app:update --all`).
- [ ] Abgeschaltete Apps wieder einschalten, falls kompatibel.
- [ ] Admin-Warnungen prüfen.
- [ ] Proxy- und Regionseinstellungen bei Bedarf erneut anwenden (`apply-nextcloud-proxy-and-region.bash`).
- [ ] Datei-Upload, OnlyOffice, SSO und Hintergrundjobs testen.
