# Benutzerhandbuch

Wie du die SCS-Plattform im Alltag nutzt. Deployment und Server-Interna stehen in der [Technischen Dokumentation](../technical/index.md).

Die Bilder zeigen das Demo-Projekt **robert Demo**. Ein Demo-Projekt bringt WissKI, JupyterHub und WebProtégé mit Beispieldaten mit. Jedes freigegebene Konto bekommt genau eines, zusätzlich zum eigenen Projekt.

```mermaid
flowchart LR
  registrierung[Registrieren] --> freigabe[Freigabe abwarten]
  freigabe --> anmeldung[Anmelden]
  anmeldung --> projekt[Projekt anlegen]
  projekt --> anwendungen[Anwendungen]
  projekt --> team[Team einladen]
```

## Anleitungen

1. [Registrierung](registrierung.md) — Konto beantragen und auf die Freigabe warten.
2. [Anmeldung](anmeldung.md) — mit dem SCS-Login auf die Projektseite kommen.
3. [Projekt anlegen](projekt-anlegen.md) — eigenes Projekt. Das Demo-Projekt ist schon da.
4. [Anwendungen](anwendungen.md) — WissKI, JupyterHub, WebProtégé, SQL-Datenbank und Triplestore.
5. [Projektmitglieder](mitglieder.md) — Personen einladen, annehmen, entfernen.
6. [Projektdateien](projektdateien.md) — der gemeinsame Ordner in Drive, JupyterHub und WissKI.
7. [Grundlegende Aufgaben](anleitungen/index.md) — erste Schritte in jeder Anwendung, am Demoprojekt.

## Verfügbare Anwendungen

- [JupyterHub mit OpenRefine](apps/jupyter.md)
- [MariaDB mit phpMyAdmin](apps/mariadb.md)
- [Nextcloud mit OnlyOffice und draw.io](apps/nextcloud.md)
- [OpenGDB](apps/opengdb.md)
- [WebProtégé](apps/webprotege.md)
- [WissKI-Umgebung](apps/wisski.md)

## Nachrichten

**Nachrichten** im Menü zeigt Projekteinladungen und Nachrichten der Administration. Eine Nachricht der Administration öffnet sich als Konversation: deine Nachrichten rechts, die der Administration links, jeweils mit dem Namen der Person, die sie geschrieben hat. Antworte im Feld unten. Eigene Nachrichten kannst du bearbeiten oder löschen; eine gelöschte Nachricht erscheint als „Nachricht gelöscht“. Die Zahl im Menü zählt Einladungen und Konversationen mit einer neuen Nachricht.

## Hilfe benötigt?

Bei Fragen zu Zugriff, Freigaben oder Speicherplatz wende dich an deine Systemadministration.
