# JupyterHub

Jedes Projekt hat ein JupyterLab, das sich alle Mitglieder teilen. Was der Dienst ist: [JupyterHub mit OpenRefine](../apps/jupyter.md).

## Das Lab öffnen

1. Wähle auf der Projektseite den Pfeil auf der Karte **JupyterHub**.
2. JupyterHub bittet um Anmeldung: Wähle **Sign in with SODa SCS Login**.

![JupyterHub-Anmeldung mit dem Knopf Sign in with SODa SCS Login](../images/guides/jupyter-anmelden.png)

Steht auf der Karte **Gestoppt**, startet das Lab jetzt; das dauert einen Moment. Nach etwa einer Stunde ohne Nutzung stoppt es von selbst.

Das Lab öffnet sich im Projektordner `nextcloud/<Projektname>`, hier `nextcloud/demo_user Demo`. Es ist derselbe Ordner wie der Team-Ordner im Drive und `project_files` in der WissKI, siehe [Projektdateien](../projektdateien.md).

![JupyterLab mit dem Projektordner links und dem Starter rechts](../images/guides/jupyter-start.png)

- Notebooks und Daten des Projekts gehören in diesen Ordner. Dort finden sie die anderen Mitglieder und das Drive.
- Das Home-Verzeichnis drumherum gehört zum Lab. Auch das teilen sich alle Mitglieder des Projekts, im Drive liegt es aber nicht.

## Ein Notebook anlegen

1. Öffne im Dateibrowser `nextcloud/demo_user Demo`.
2. Wähle im Reiter **Starter** (oder oben links **+** für einen neuen) unter **Notebook** einen Kernel: **Python 3 (ipykernel)**, **Julia** oder **R**. Der Starter öffnet auch **OpenRefine**.

Das neue Notebook heißt `Untitled.ipynb`. Rechtsklick darauf im Dateibrowser, **Umbenennen**, gibt ihm einen Namen, zum Beispiel `materialien.ipynb`.

## Code ausführen

Ein Notebook besteht aus Zellen. Eine Code-Zelle enthält Code, eine Markdown-Zelle Text.

1. Schreib in die erste Zelle:

    ```python
    import pandas as pd

    materials = pd.read_csv("materials_gnd.csv")
    materials
    ```

2. Drück **Shift+Enter**. Die Zelle läuft, ihr Ergebnis erscheint darunter, und der Cursor springt in die nächste Zelle. Die Demo-CSV erscheint als Tabelle mit den Materialien und ihren GND-Einträgen.

![Ausgeführte Zelle mit der Materialtabelle](../images/guides/jupyter-notebook-ausgefuehrt.png)

3. Um aus einer Zelle Text zu machen, wähle sie aus und stelle in der Werkzeugleiste **Markdown** ein, oder drück **M**.

Weitere Befehle stehen im Menü **Ausführen**: **Alle Zellen ausführen** führt das ganze Notebook von oben aus, **Kernel neu starten und Alle Zellen ausführen…** beginnt vorher neu.

![Menü Ausführen mit Alle Zellen ausführen](../images/guides/jupyter-menue-ausfuehren.png)

Das Notebook speichert sich alle paar Minuten selbst. **Strg+S** speichert sofort.

## Gemeinsam arbeiten

Alle Mitglieder des Projekts arbeiten im selben Lab. Öffnen zwei Personen dasselbe Notebook, sieht jede den Cursor der anderen mit Namen, und Änderungen erscheinen schon beim Tippen, wie in einem Online-Dokument.

- Auch die Variablen eines Notebooks sind gemeinsam: Wer eine Zelle ausführt, ändert den Zustand für alle in diesem Notebook.
- Sag den anderen Bescheid, bevor du den Kernel neu startest oder alles ausführst.
- Im Drive geänderte Dateien erscheinen nach etwa 30 Sekunden im Lab. Bearbeitet jemand dieselbe Datei gleichzeitig im Drive und im Lab, gewinnt die letzte Speicherung.

## Über die API in die WissKI schreiben

Die Demo zeigt, wie ein Notebook in die WissKI schreibt. Im Team-Ordner liegt `import_materials_gnd.ipynb`. Es liest `materials_gnd.csv` und legt über die WissKI-REST-API (v0) an:

1. je Zeile einen **Normdaten**-Eintrag (Authority data) mit GND-Begriff, GND-URL und GND-Entitätstyp,
2. je Zeile ein **Material**, das auf diesen Normdaten-Eintrag verweist.

Vorhandene Einträge werden nicht doppelt angelegt: Normdaten werden über die GND-URL wiedererkannt, Materialien über ihren Namen.

So führst du es aus:

1. Öffne `import_materials_gnd.ipynb` im Projektordner.
2. Wähle **Ausführen → Alle Zellen ausführen**. Das Notebook läuft zunächst als Probelauf (`DRY_RUN = True`). Es schreibt nichts; am Ende steht *PROBELAUF – nichts geschrieben* und für jede Zeile, was es tun würde.

    ![Probelauf: 50 Zeilen mit dem Status Probelauf](../images/guides/jupyter-api-probelauf.png)

3. Um wirklich zu schreiben, setze in der ersten Code-Zelle `DRY_RUN = False` und führe alle Zellen noch einmal aus. Jede Zeile hat jetzt den Status *angelegt*.

    ![Import: jedes Material angelegt, mit seiner WissKI-URI](../images/guides/jupyter-api-import.png)

4. Öffne in der WissKI die Liste der Materialien (**Browse → Material**). Die neuen Materialien sind da, jedes mit seinem GND-Eintrag.

Mit eigenen Daten probierst du es, indem du eine Zeile zu `materials_gnd.csv` hinzufügst. Die GND-URI des Materials findest du in der [GND](https://explore.gnd.network/), in der Form `https://d-nb.info/gnd/<Nummer>`.

Die Zugangsdaten der Demo-WissKI liegen in `~/.wisski-demo-api.env`, im Home-Verzeichnis des Labs und nicht im Team-Ordner. Das Notebook liest sie dort, das Passwort steht also nie im Notebook.

!!! info "Für deine eigene WissKI"
    Die API muss in der WissKI unter **Konfiguration → WissKI → WissKI API** (`/admin/config/wisski/wisski_api`) aktiviert sein. Das Konto, das das Notebook nutzt, braucht die Berechtigungen *WissKI API Read* und *WissKI API Write* und ein lokales Drupal-Passwort: Die SCS-Anmeldung funktioniert für die API nicht. Im Lab ist außerdem das Python-Paket `wisski_py` installiert, ein Client für dieselbe API.
