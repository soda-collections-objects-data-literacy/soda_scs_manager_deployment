# SCS Drive (Nextcloud)

SCS Drive ist die Nextcloud der Plattform. Es speichert deine Dateien und öffnet Office-Dokumente mit OnlyOffice im Browser. Was der Dienst ist: [Nextcloud mit OnlyOffice und draw.io](../apps/nextcloud.md).

Du öffnest das Drive von der Projektseite aus: **Dateien → Go to file system**. Es öffnet direkt den Projektordner.

## Der Team-Ordner

Jedes Projekt hat einen Team-Ordner mit dem Namen des Projekts. In den Bildern heißt er **demo_user Demo**, deiner nach deinem Demoprojekt. Alle Mitglieder sehen ihn im Drive unter **Team-Ordner**, ohne dass ihn jemand freigeben muss. Neue Mitglieder bekommen ihn, sobald sie die Einladung annehmen; entfernte Mitglieder verlieren ihn.

![Team-Ordner im Drive mit dem Ordner demo_user Demo](../images/guides/drive-teamordner-liste.png)

Im Team-Ordner der Demo liegen `import_materials_gnd.ipynb` und `materials_gnd.csv`. Derselbe Ordner ist der Projektordner in JupyterHub und WissKI, siehe [Projektdateien](../projektdateien.md).

- Alles, woran das Projekt arbeitet, gehört in den Team-Ordner, nicht in deine persönlichen Ordner.
- Dateien in deinen persönlichen Ordnern bleiben privat, solange du sie nicht freigibst.
- Wer eine Datei im Team-Ordner löscht, löscht sie für alle Mitglieder. Sie landet unter **Gelöschte Dateien** und lässt sich dort eine Zeit lang wiederherstellen.

## Ein Dokument anlegen

1. Öffne den Team-Ordner.
2. Wähle oben **+ Neu**.
3. Wähle unter **Neu erstellen** **Neues Dokument** (Text), **Neue Tabelle** oder **Neue Präsentation**.
4. Gib einen Namen ein, zum Beispiel `Objektbeschreibung Wanderkrug`, und wähle **Erstellen**.

![Das Menü + Neu mit Neues Dokument, Neue Tabelle, Neue Präsentation und Neues Diagramm](../images/guides/drive-neu-menu.png)

![Dialog Neues Dokument mit dem Dateinamen](../images/guides/drive-dokument-name.png)

Das Dokument öffnet sich in OnlyOffice. Es wird als `.docx`, `.xlsx` oder `.pptx` gespeichert.

## Ein Dokument bearbeiten

Ein Klick auf die Datei öffnet sie im Editor. OnlyOffice speichert beim Tippen: Unten in der Statusleiste steht **Alle Änderungen gespeichert**. Das **×** oben rechts schließt den Editor.

![OnlyOffice mit der Beschreibung des Wanderkrugs](../images/guides/drive-onlyoffice-dokument.png)

Eine CSV-Datei öffnet sich nicht per Klick. Nimm **⋯ → In ONLYOFFICE öffnen**. OnlyOffice fragt zuerst unter **CSV-Optionen wählen**, wie es die Datei lesen soll: **Unicode (UTF-8)** und **Komma** lassen und **OK** wählen.

![CSV-Optionen wählen für materials_gnd.csv](../images/guides/drive-onlyoffice-csv.png)

Probier es mit `materials_gnd.csv` aus der Demo: Sie hat die Spalten `material_name`, `gnd_preferred_term`, `gnd_uri` und `gnd_entity_type`. Das Notebook in [JupyterHub](jupyter.md) liest diese Datei, lass die Spalten also, wie sie sind.

Um zu einem früheren Stand zurückzukehren, öffne die Details der Datei (**⋯ → Details**), Reiter **Versionen**. Dort lässt sich jede Version wiederherstellen.

![Reiter Versionen in den Details einer Datei](../images/guides/drive-versionen.png)

## Gemeinsam arbeiten

Mehrere Personen können dasselbe Dokument gleichzeitig bearbeiten.

1. Beide öffnen dieselbe Datei im Team-Ordner.
2. Oben rechts im Editor erscheint der Avatar der anderen Person. Ihr Cursor und ihre Änderungen erscheinen im Text mit ihrem Namen.
3. Markiere Text und füge über den Reiter **Zusammenarbeit** einen Kommentar hinzu, um den anderen eine Notiz zu hinterlassen. Antworten landen im selben Thread.

Hinterher musst du nichts zusammenführen: Alle bearbeiten dieselbe Datei.

## Eine Datei oder einen Ordner freigeben

Projektmitglieder sehen den Team-Ordner ohnehin. Um eine Datei an jemanden außerhalb des Projekts zu geben, wähle das Teilen-Symbol neben der Datei. Rechts öffnet sich der Reiter **Teilen**.

![Reiter Teilen mit Interne Freigaben und Externe Freigaben](../images/guides/drive-teilen.png)

- **Interne Freigaben:** Tipp den Namen eines SCS-Kontos oder Teams in **Namen oder Teams eingeben** und wähle es aus der Liste. Unter der Person legst du fest, was sie darf, zum Beispiel bearbeiten.
- **Externe Freigaben → Öffentlichen Link erstellen:** erzeugt einen Link. Wer den Link hat, kann die Datei öffnen. Im Menü des Links setzt du ein Passwort, ein Ablaufdatum und ob bearbeitet werden darf.

Um die Freigabe zu beenden, öffne **Teilen** wieder und entferne die Person oder den Link.

!!! tip "Links für OpenRefine"
    Ein öffentlicher Link öffnet eine Vorschauseite. Um die Datei selbst zu laden, zum Beispiel in OpenRefine, hänge `/download` an den Link: `https://drive.scs.sammlungen.io/s/<id>/download`.
