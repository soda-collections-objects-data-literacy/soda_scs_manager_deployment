# Projekt anlegen

Ein Projekt bündelt Anwendungen, den gemeinsamen Ordner im SCS Drive und das Team. Jede Anwendung gehört zu einem Projekt. Du bist die Eigentümerin oder der Eigentümer.

Auf **Projekte** steht oben **Projekt anlegen**. Dieselbe Schaltfläche ist das Plus neben **Projekte** in der Seitenleiste.

![Projektliste mit Suche, Projekt anlegen und der Karte robert Demo](images/03-dashboard.png)

Die Karte zeigt den Namen, Schlagworte der enthaltenen Anwendungen, das Datum und dein Kürzel. Ein Klick auf die Karte öffnet das Projekt.

## Assistent

**Projekt anlegen** öffnet einen Assistenten. Nichts wird gespeichert, bevor du auf der letzten Seite **Projekt anlegen** wählst. Schließt du das Fenster vorher, ist alles verworfen.

Die Zahl der Schritte hängt davon ab, ob du Anwendungen auswählst. Ohne Anwendungen sind es vier Schritte. Jede gewählte Anwendung fügt einen Schritt zum Benennen hinzu.

### 1. Name und Notiz

![Create Project, Schritt Bezeichnung und Notiz](images/05-projekt-wizard-name.png)

- **Bezeichnung** ist der Projektname. Er muss auf der ganzen Plattform eindeutig sein und wird auch der Name des Projektordners in Nextcloud.
- **Notiz** ist frei. Sie erscheint später auf der Projektseite.

**Weiter** geht zum nächsten Schritt. **← Zurück** ist auf der ersten Seite noch gesperrt.

### 2. Anwendungen wählen

![Anwendungen im Assistenten, WissKI ist ausgewählt](images/06-projekt-wizard-anwendungen.png)

Wähle eine oder mehrere Karten. Ein zweiter Klick nimmt die Auswahl zurück. **Skip** oder **Weiter** ohne Auswahl lässt das Projekt ohne Anwendungen. Anwendungen kannst du später auf der Projektseite ergänzen.

| Anwendung | Wofür | Wie oft |
|---|---|---|
| **JupyterHub** (Datenanreicherung) | Notebooks und Rechnen, gemeinsamer Ordner des Projekts | einmal pro Projekt |
| **WebProtégé** (Ontologiemanagement) | Ontologie des Projekts | einmal pro Projekt |
| **WissKI** (Datenmanagement) | Umgebung für Sammlungsdaten, mit eigener Datenbank und eigenem Triplestore | mehrfach |
| **SQL-Datenbank** (Datenbank) | eigene relationale Datenbank, zusätzlich zu WissKI | mehrfach |
| **Triplestore** (Datenbank) | eigener Triplestore, zusätzlich zu WissKI | mehrfach |

Das Buch-Symbol auf einer Karte öffnet die kurze Hilfe zu dieser Anwendung.

### 3. Anwendung benennen

Hast du mindestens eine Karte gewählt, kommt für jede ein Formular.

![WissKI benennen: Bezeichnung und Notizen](images/07-projekt-wizard-wisski.png)

Bei **WissKI** und **JupyterHub** hat die **Bezeichnung** höchstens 25 Zeichen. Daraus entsteht die Adresse der Anwendung; sie erscheint unter dem Feld, sobald der Name geprüft ist. **Notizen** sind optional. **Skip** lässt diese eine Anwendung aus. **Weiter** merkt sie sich für die Prüfung am Ende.

SQL-Datenbank und Triplestore fragst du genauso nach Bezeichnung und Notizen. Eine WissKI-Umgebung bringt Datenbank und Triplestore schon mit. Die beiden Karten darunter sind zusätzliche, eigenständige Anwendungen.

### 4. Personen einladen

![Einladung im Assistenten: Username oder E-Mail und Hinzufügen](images/08-projekt-wizard-mitglieder.png)

Trag den **Username oder die E-Mail** einer Person ein, die schon ein SCS-Konto hat, und wähle **Hinzufügen**. Die Einladung geht erst raus, wenn du das Projekt wirklich anlegst. Den Schritt kannst du mit **Skip** oder **Weiter** ohne Eintrag überspringen und später auf der Projektseite nachholen. Wie die Person die Einladung annimmt, steht unter [Projektmitglieder](mitglieder.md).

### 5. Prüfen und anlegen

![Prüfung ohne Anwendungen und ohne Personen](images/09-projekt-wizard-pruefen.png)

Die Prüfung listet Name, Notiz, Anwendungen und Personen. Im Bild sind Anwendungen und Personen leer, weil beide Schritte übersprungen wurden. Hast du welche gewählt, stehen sie hier.

**Projekt anlegen** legt das Projekt an, startet die gewählten Anwendungen und verschickt die Einladungen. WissKI braucht dafür einige Minuten. Die Projektseite zeigt den Fortschritt an den Karten (**Läuft**, **Startet**, **Gestoppt**).

## Demo-Projekt

Solange du noch kein Demo-Projekt hast, hat der erste Schritt zwei Reiter: **Neu** und **Demo**. **Demo** legt kein leeres Projekt an, sondern eines mit WissKI, JupyterHub und WebProtégé und mit Beispieldaten. Die Schaltfläche heißt **Demo-Projekt anlegen**. Das Einrichten dauert einige Minuten. Danach verschwindet der Reiter. Ein zweites Demo-Projekt pro Konto gibt es nicht.

Das Ergebnis sieht so aus:

![Projektseite robert Demo mit JupyterHub, WissKI, WebProtégé, Notizen, Team und Dateien](images/04-demoprojekt.png)

Oben rechts stehen der Status **Demo**, die Version und **Demo zurücksetzen**.

!!! warning "Demo zurücksetzen"
    Zurücksetzen überschreibt alle Änderungen in WissKI, den Datenbanken, den Triplestores, dem Jupyter-Home-Verzeichnis, dem Team-Ordner und der WebProtégé-Ontologie dieses Projekts mit den Demo-Daten. Anwendungen, die du selbst hinzugefügt hast, bleiben. Das lässt sich nicht rückgängig machen.

Dieselbe Möglichkeit, ein Demo-Projekt zu starten, bietet die Einführung beim ersten Login (**Oder mit einem Demo-Projekt starten**).
