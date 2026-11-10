# Wartung

Dieser Abschnitt beschreibt die laufende Wartung des SODa-SCS-Manager-Deployments.

## Themen

- **[Dev nach Prime](dev-to-prime.md)** — Schritt für Schritt für Änderungen am Deployment und an den Submodulen (JupyterHub, Nextcloud, Keycloak und die anderen) sowie am SCS-Manager-Modul, am Theme und an den mitgelieferten Seiten.
- **[Release vorbereiten](release-prep.md)** — Der Skill `scs-release-prep` committet, schreibt Changelogs, setzt Tags und schreibt einen Push-Plan. Ein Skript pusht alles. Am Ende steht die Liste der Handgriffe, die keine CI erledigt.
- **[Updates](updates.md)** — Dienste aktualisieren (vor allem Nextcloud), Nacharbeiten, häufige Probleme, Backup- und Restore-Skripte.

## Überblick

Das Deployment umfasst mehrere Dienste (Nextcloud, Keycloak, JupyterHub, Drupal und andere). Jeder Dienst hat seinen eigenen Update-Weg.

Wiederkehrende Aufgaben:

- **Updates** — Sicherheitspatches und neue Versionen einspielen.
- **Backups** — Datenbanken und Volumes regelmäßig sichern. Für Nextcloud gibt es Skripte.
- **Monitoring** — Logs, Admin-Oberflächen und das Traefik-Dashboard auf Fehler und Warnungen prüfen.
- **Datenbankpflege** — Alte Daten aufräumen, Repair- und Optimize-Befehle ausführen.
- **Aufräumen** — Ungenutzte Docker-Images und -Volumes entfernen.

Vor größeren Änderungen immer sichern. Die Abläufe stehen unter [Updates](updates.md).

### WissKI-Performance-Tuning

Geänderte Einstellungen für PHP-FPM, Varnish oder den Triplestore auf **laufende** Stacks anwenden, ohne auf neue Images zu warten:

```bash
01_scripts/wisski/apply-performance-tuning.bash
```

Die Vorgaben und Konfigurationspfade stehen unter [WissKI-Stack-Infrastruktur](../service-infrastructure/wisski-stack/index.md#performance-defaults-aligned-with-dedicated-wisski-deployments).

## Kurzreferenz

### Nextcloud sichern und wiederherstellen

**Sichern** (Zeitstempel-Backups in `/srv/backups/nextcloud/`):

```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**Wiederherstellen** (interaktiv, listet die vorhandenen Backups):

```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

### Nextcloud-Wartung

**Alle Nacharbeiten nach einem Update** (Repair, DB-Indizes, Spalten, Primärschlüssel):

```bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
```

**Proxy- und Regionseinstellungen anwenden** (für bestehende Installationen):

```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

**E-Mail konfigurieren** (aus den Umgebungsvariablen, für bestehende Installationen):

```bash
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash
```
