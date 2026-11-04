# Projektdateien

Jedes Projekt hat einen Ordner. Darin liegen die Dateien dieses Projekts. Derselbe Ordner steht im SCS Drive, in JupyterHub und in WissKI. Was du an einer Stelle ablegst oder änderst, ist an den anderen Stellen dieselbe Datei.

Persönliche Dateien außerhalb dieses Ordners bleiben privat. Jupyter und WissKI sehen sie nicht.

## Auf der Projektseite

Rechts auf der Projektseite steht **Dateien**. Dort siehst du die letzten Änderungen im Projektordner. **Go to file system** öffnet den Ordner im SCS Drive.

![Dateien auf der Projektseite](images/13-projektseite-dateien.png)

Wenn dort steht, dass du dein Drive-Konto verbinden musst, wähle **Connect Drive**. Danach zeigt die Liste die Änderungen.

## Im SCS Drive

Der Ordner trägt den Namen des Projekts. Alle Projektmitglieder sehen ihn in ihrem Drive und können Dateien hochladen, ändern und löschen.

![Projektordner robert Demo im SCS Drive](images/14-drive-projektordner.png)

Der Ordner **`SCS-Share`** ist ein anderer Ordner: er gilt für die ganze Plattform, nicht für ein einzelnes Projekt. Dateien, die Jupyter oder WissKI nutzen sollen, gehören in den Projektordner.

## In JupyterHub

Du öffnest das Lab über die Karte **JupyterHub** auf der Projektseite. Im Dateibrowser liegt der Projektordner unter `nextcloud/<Projektname>`.

![Dateibrowser in JupyterLab: nextcloud/robert Demo](images/15-jupyter-projektordner.png)

- Alle Mitglieder teilen sich dieses Lab und sehen Änderungen der anderen sofort.
- Andere Ordner deines Drives erscheinen dort nicht.
- Neue Mitglieder können den Ordner sofort öffnen, ein Neustart ist nicht nötig.
- Änderungen aus dem Drive erscheinen nach etwa 30 Sekunden im Lab. Bearbeitet jemand dieselbe Datei gleichzeitig im Drive und im Lab, gilt die zuletzt gespeicherte Fassung.
- In der Aktivitätsliste des Drives erscheinen Änderungen aus dem Lab als **SCS project mounts**.
- Das Lab startet von selbst und stoppt nach etwa einer Stunde ohne Nutzung.

## In WissKI

WissKI bindet denselben Projektordner ein. Dateien daraus kannst du an Einträgen verwenden, zum Beispiel als Bild oder Anhang. Im Dateisystem der WissKI heißt der Ordner `project_files`.

![Dateimanager in WissKI: Ordner project_files](images/16-wisski-projektdateien.png)

Eine Datei, die du im Drive oder unter `nextcloud/<Projektname>` in Jupyter ablegst, liegt in WissKI in `project_files`. Umgekehrt gilt dasselbe.

Ältere WissKI-Instanzen zeigen denselben Ordner noch als `nextcloud`.

## Demo zurücksetzen

Ein Demo-Reset überschreibt die Dateien in diesem Ordner mit den Beispieldaten. Was das sonst noch zurücksetzt, steht unter [Projekt anlegen](projekt-anlegen.md).
