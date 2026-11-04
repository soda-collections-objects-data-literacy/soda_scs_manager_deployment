# Anwendungen

Anwendungen gehören zu einem Projekt. Du öffnest sie über die Karte auf der Projektseite. Der Pfeil auf der Karte öffnet die Anwendung in einem neuen Tab. **Details** zeigt die Seite der Anwendung im SCS Manager.

Das Demo-Projekt **robert Demo** enthält drei Anwendungen:

![Projektseite mit JupyterHub, WissKI und WebProtégé](images/04-demoprojekt.png)

| Karte | Art | Im Beispiel |
|---|---|---|
| **JupyterHub** | Datenanreicherung | **Gestoppt**, bis du sie öffnest. Sie startet dann und stoppt nach etwa einer Stunde ohne Nutzung. Alle Mitglieder teilen sich dieses Lab. |
| **WissKI** | Datenmanagement | **Läuft**. Die Umgebung enthält die Datenbank und den Triplestore für diese WissKI. |
| **WebProtégé** | Ontologiemanagement | **Läuft**. Öffnet die Ontologie dieses Projekts. |

Der Punkt vor dem Status ist rot bei **Gestoppt** und grün bei **Läuft**. **Startet** heißt, die Anwendung wird gerade eingerichtet oder hochgefahren.

Rechts auf der Seite:

- **Notizen** — die Notiz aus dem Assistenten. Der Stift öffnet **Notizen** zum Ändern.
- **Team** — Eigentümer und Mitglieder. Siehe [Projektmitglieder](mitglieder.md).
- **Dateien** — die letzten Änderungen im Projektordner. **Go to file system** öffnet den Ordner im SCS Drive. Derselbe Ordner ist in JupyterHub und WissKI nutzbar, siehe [Projektdateien](projektdateien.md).
- **Löschen** — nur für die Eigentümerin oder den Eigentümer. Solange andere Mitglieder im Projekt sind, müssen sie zuerst entfernt werden. Löschen nimmt das Projekt samt seinen Anwendungen zurück und lässt sich nicht rückgängig machen.

## Anwendung hinzufügen

Die schwarze Karte **Anwendung hinzufügen** (oder das Plus, wenn die Überschrift eine solche Schaltfläche zeigt) öffnet die Auswahl.

Im Demo-Projekt sind JupyterHub und WebProtégé schon da. Beide gibt es nur einmal pro Projekt, deshalb fehlen sie in der Auswahl. WissKI, SQL-Datenbank und Triplestore kannst du zusätzlich anlegen.

![Anwendung hinzufügen: WissKI, SQL-Datenbank und Triplestore](images/10-anwendung-auswahl.png)

Eine Karte öffnet das Formular. **← Zurück** kehrt zur Auswahl zurück, ohne etwas anzulegen.

### WissKI

**Bezeichnung** mit höchstens 25 Zeichen, dazu optionale Notizen. Unter der Bezeichnung erscheint die künftige Adresse. Eine WissKI-Umgebung enthält ihre Datenbank und ihren Triplestore. Das Einrichten dauert einige Minuten. Die Karte zeigt solange **Startet**.

Im Assistenten beim Projektanlegen sieht das Formular so aus:

![Formular WissKI: Bezeichnung und Notizen](images/07-projekt-wizard-wisski.png)

### JupyterHub

Ebenfalls einmal pro Projekt, Bezeichnung wie bei WissKI. Das Lab nutzt den Projektordner. Im Dateibrowser liegt er unter `nextcloud/<Projektname>`. Persönliche Dateien anderer Ordner sind dort nicht sichtbar. Mehr dazu steht unter [Projektdateien](projektdateien.md).

### WebProtégé

Einmal pro Projekt. Mitglieder erhalten Zugriff, sobald sie die Einladung annehmen. Die Karte öffnet die Ontologie dieses Projekts.

### SQL-Datenbank

![SQL-Datenbank: Bezeichnung, Notizen und Erstellen](images/11-anwendung-sql.png)

**Bezeichnung** ist der Name, den du auf der Karte siehst. **Notizen** sind optional. **Erstellen** legt die Datenbank an. Das ist eine eigene Datenbank neben derjenigen, die eine WissKI-Umgebung schon mitbringt.

### Triplestore

Dasselbe Formular: **Bezeichnung**, **Notizen**, **Erstellen**. Auch das ist ein zusätzlicher Triplestore, nicht derjenige der WissKI-Umgebung.

!!! warning "Erst Erstellen, dann ist die Anwendung da"
    Solange du das Fenster schließt oder **← Zurück** wählst, wird nichts angelegt. **Erstellen** startet die Einrichtung sofort.
