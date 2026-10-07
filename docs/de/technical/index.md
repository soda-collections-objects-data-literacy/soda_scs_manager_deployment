# Technische Dokumentation

Wie das SODa-SCS-Manager-Deployment gebaut, installiert und betrieben wird. Endnutzer-Anleitungen stehen im [Benutzerhandbuch](../user/index.md).

!!! note "Sprache"
    Die technische Dokumentation ist derzeit überwiegend auf Englisch. Die Navigation und diese Übersichtsseite sind auf Deutsch; fehlende DE-Seiten werden beim Build aus der englischen Fassung übernommen. Übersetzungen folgen schrittweise.

## Hier starten

1. [Glossary](glossary.md) — Begriffe in diesem Projekt (SCS, Keycloak, Traefik, Naming, …).
2. [Prerequisites](initial-setup/prerequisites.md) — Docker, GitHub-Auth, `.env`.
3. [Pre-start steps](initial-setup/pre-start-steps.md) — `start.sh`, Netzwerk, Datenbank, Pre-Install-Skripte.
4. [Post-configuration checklist](post-configuration/checklist.md) — Keycloak, Manager, Nextcloud, JupyterHub.

## Abschnitte

- **[Service infrastructure](service-infrastructure/index.md)** — Stack-Layout, Traefik, gemeinsame DB, Manager, Drive, Code, OpenGDB, Website.
  - [Architecture overview (C4 / Mermaid)](service-infrastructure/architecture-overview.md)
  - [Naming vocabulary](service-infrastructure/naming-vocabulary.md) — `{scope}--{service}--{function}`
  - [Naming migration plan](service-infrastructure/naming-migration-plan.md)
  - [SCS Manager user lifecycle](service-infrastructure/scs-manager-user-lifecycle.md)
- **[Initial setup](initial-setup/index.md)** — vor dem ersten `docker compose up`
- **[Post-start](post-start/index.md)** — Health-Checks nach Compose-Up
- **[Post-configuration](post-configuration/index.md)** — einmalige Service-Konfiguration
- **[Maintenance](maintenance/index.md)** — Updates und Backups ([Update-Guide](maintenance/updates.md))
- **[Troubleshooting](troubleshooting/index.md)** — typische Fehler und Testskripte

## Referenz

- [Reverse proxy backend config](knowledge-base/reverse-proxy-backend-config-knowledge-base.md)
- [Traefik labels and commands](knowledge-base/traefik-labels-and-commands.md)
- [Dedicated WissKI deployment (Uni Graz)](infrastruktur-uebersicht.md)

## Quick start

1. Repository klonen und Submodule initialisieren.
2. `example-env` nach `.env` kopieren und Pflichtvariablen setzen ([Prerequisites](initial-setup/prerequisites.md)).
3. `./start.sh` ausführen.
4. `docker compose up -d` ausführen.
5. [Post-configuration checklist](post-configuration/checklist.md) abarbeiten.
