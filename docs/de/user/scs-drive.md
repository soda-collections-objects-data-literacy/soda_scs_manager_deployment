# SCS Drive

Dein persönlicher **SCS Drive** ist Cloud-Speicher auf Basis von Nextcloud. Hier liegen Dateien, Dokumente und gemeinsame Arbeit in der SCS-Plattform (Scholarly Communication System).

## Dateispeicher

Dein Drive funktioniert wie jeder Cloud-Speicher: Dateien hochladen, organisieren, teilen und von überall darauf zugreifen. Alles, was du hier ablegst, gehört dir und ist nur für Personen zugänglich, mit denen du es ausdrücklich geteilt hast.

## OnlyOffice — Office-Suite

OnlyOffice ist direkt in deinen Drive integriert. Du kannst folgende Dokumente erstellen und bearbeiten:

- **Textdokumente** (`.odt`)
- **Tabellen** (`.ods`)
- **Präsentationen** (`.odp`)

Klicke auf **+ Neu** in der Dateiansicht, um ein neues Dokument zu erstellen, oder öffne ein vorhandenes — OnlyOffice öffnet sich direkt im Browser.

## Draw.io — Diagramme & Visualisierungen

Draw.io steht als integrierte App für Diagramme, Flussdiagramme, Mindmaps und Netzwerkdiagramme zur Verfügung. Klicke auf **+ Neu → Neues Diagramm**. Alle Diagramme werden als `.drawio`-Dateien in deinem Drive gespeichert.

## Projektordner

Jedes SCS-Projekt hat einen **Team-Ordner** mit dem Namen des Projekts. Alle Projektmitglieder sehen ihn in ihrem Drive und arbeiten gemeinsam darin. Die Anwendungen des Projekts nutzen denselben Ordner:

- **WissKI** — semantisches Datenmanagement für Kulturgut und Forschungsdaten
- **JupyterHub** — interaktive Rechenumgebung für Datenanalyse und Notebooks

In JupyterHub hat jedes Projekt ein gemeinsames JupyterLab. Alle Mitglieder arbeiten gleichzeitig darin und sehen die Änderungen der anderen sofort. Du öffnest es über die Karte **JupyterHub** des Projekts im SCS Manager; es startet von selbst und stoppt nach einer Stunde ohne Nutzung. Der Projektordner liegt unter `nextcloud/<Projektname>`. Deine persönlichen Dateien und andere Ordner erscheinen dort nicht.

- Neue Mitglieder können das Lab sofort öffnen, ein Neustart ist nicht nötig.
- Die Mitglieder teilen sich das Lab: Sie sehen gegenseitig Terminals und laufende Kernel, und Stoppen oder Neustarten betrifft alle.
- Änderungen im Drive erscheinen nach etwa 30 Sekunden im Lab. Bearbeitet jemand dieselbe Datei gleichzeitig im Drive und im Lab, gilt die zuletzt gespeicherte Fassung.
- In der Aktivitätsliste des Drives erscheinen Änderungen aus dem Lab als **SCS project mounts**.

## Der SCS-Share-Ordner

Der Ordner **`SCS-Share`** ist ein **geteilter Team-Ordner** (nicht dein privater Home-Ordner) zum Austausch von Dateien über die ganze Plattform. Dateien für ein Projekt gehören in den Ordner dieses Projekts, dort können seine Anwendungen sie nutzen.

## Hilfe benötigt?

Bei Fragen zu Zugriff, Freigaben oder Speicherplatz wende dich an deine Systemadministration. Plattform-Dienste: [Verfügbare Dienste](services.md).
