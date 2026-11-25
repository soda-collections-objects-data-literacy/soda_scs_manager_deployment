# Datenbanken

Ein Projekt kann eigene SQL-Datenbanken haben, neben der Datenbank, die eine WissKI-Umgebung schon mitbringt. Was der Dienst ist: [MariaDB mit phpMyAdmin](../apps/mariadb.md).

## Eine Datenbank anlegen

1. Öffne das Projekt, zum Beispiel das Demoprojekt.
2. Wähle die schwarze Karte **Anwendung hinzufügen**.
3. Wähle **SQL-Datenbank**.

    ![Auswahl mit WissKI, SQL-Datenbank und Triplestore](../images/guides/db-anwendung-auswahl.png)

4. Gib eine **Bezeichnung** ein, zum Beispiel `Leihgaben`. **Maschinenname** wird daraus gefüllt. **Notizen** sind optional.
5. Wähle **Erstellen**.

![Formular für die SQL-Datenbank mit Bezeichnung, Maschinenname und Notizen](../images/guides/db-formular.png)

Die Datenbank erscheint als Karte *Leihgaben (SQL-Datenbank)* auf der Projektseite. Mehr zum Formular: [Anwendungen](../anwendungen.md#sql-datenbank).

## In phpMyAdmin verwalten

Der Pfeil auf der Karte öffnet phpMyAdmin. Wenn nötig, meldest du dich mit deinem SCS-Konto an; ein eigenes Datenbank-Passwort musst du nicht eingeben.

Links stehen deine Datenbanken, die neue als `sql-leihgaben`.

![phpMyAdmin-Startseite mit den Datenbanken links](../images/guides/db-phpmyadmin-start.png)

Ein Klick auf eine Datenbank öffnet sie. Die Reiter oben:

- **SQL** führt SQL-Anweisungen aus. So legst du am schnellsten eine Tabelle an: Anweisung einfügen und **OK** wählen.

    ```sql
    CREATE TABLE leihgabe (
      id INT AUTO_INCREMENT PRIMARY KEY,
      objekt VARCHAR(255) NOT NULL,
      leihnehmer VARCHAR(255) NOT NULL,
      ausgeliehen DATE NOT NULL,
      zurueck DATE NULL
    );
    INSERT INTO leihgabe (objekt, leihnehmer, ausgeliehen, zurueck) VALUES
      ('Antique WissKI Ceramic Travelling Jug with Network Motifs', 'Germanic National Museum', '2026-03-01', NULL),
      ('Jug', 'Department of Museum and Cultural Informatics', '2025-10-15', '2026-01-31');
    ```

    ![Reiter SQL mit CREATE TABLE und INSERT](../images/guides/db-sql-create.png)

- **Struktur** listet die Tabellen. Ohne SQL legst du dort unter **Neue Tabelle erstellen** eine Tabelle an: Name, Zahl der Spalten, dann für jede Spalte Name, Typ (`INT`, `VARCHAR`, `DATE` …) und ob sie leer sein darf.
- **Anzeigen** (in einer Tabelle) zeigt ihre Zeilen. **Bearbeiten** neben einer Zeile ändert sie, **Löschen** löscht sie.

    ![Tabelle leihgabe mit zwei Zeilen](../images/guides/db-anzeigen.png)

- **Einfügen** fügt eine Zeile über ein Formular hinzu.
- **Importieren** lädt eine `.sql`- oder `.csv`-Datei. Eine CSV aus dem Team-Ordner lädst du vorher aus dem Drive herunter, zum Beispiel `materials_gnd.csv` aus der Demo.
- **Exportieren** sichert die Datenbank oder eine Tabelle, Format **SQL** für eine Sicherung oder **CSV** für eine Tabellenkalkulation.

    ![Reiter Exportieren](../images/guides/db-exportieren.png)

Eine Abfrage im Reiter **SQL**, zum Beispiel alle noch nicht zurückgegebenen Leihgaben:

```sql
SELECT * FROM leihgabe WHERE zurueck IS NULL;
```

![Ergebnis der Abfrage: eine Leihgabe ohne Rückgabedatum](../images/guides/db-abfrage.png)

**Details** auf der Karte der Datenbank öffnet ihre Seite im SCS Manager. Dort sichert **Snapshots** den Stand der Datenbank und listet frühere Snapshots.

!!! info "Triplestore: demnächst"
    Die Auswahl zeigt schon **Triplestore** (OpenGDB). Triplestores als eigene Anwendungen sind in Vorbereitung. Bis dahin hält der Triplestore einer WissKI-Umgebung ihre Linked Data.
