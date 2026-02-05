# Testaufgabenkatalog für SCS Manager

Dieser Katalog enthält praktische Testaufgaben zum Austesten des SCS Manager Systems.

Issues bitte mit diesem Formular einreichen.

## Grundlegende Aufgaben

### 1. Account-Verwaltung
- [ ] **Registrierung**: Erstelle einen neuen Account im SCS Manager System (für SODa Internals schon geschehen)
- [ ] **Einloggen**: Logge Dich mit Deinen Zugangsdaten in das System ein
- [ ] **Navigation**: Erkunde die Hauptbereiche (Catalogue, Dashboard, Administration)

### 2. Erste Anwendung deployen
- [ ] **WissKI Environment**: Deploye Dein erstes WissKI Environment über den Catalogue
  - [ ] Gib der Anwendung einen Namen (Label)
  - [ ] Warte auf die vollständige Deployment (Healthcheck zeigt "Running")
  - [ ] Öffne das WissKI
  - [ ] Logge Dich mit Single Sign-On (SODa SCS Client) in das WissKI ein

### 3. Dashboard erkunden
- [ ] **Übersicht**: Öffne das Dashboard und überprüfe Deine deployten Anwendungen
- [ ] **Status prüfen**: Überprüfe den Healthcheck-Status aller Anwendungen
- [ ] **Anwendungsdetails**: Öffne die Detailansicht einer Anwendung
- [ ] **Bearbeitung**: Bearbeite eine Anwendung (z.B. Label oder Projektzuordnung ändern)

## Erweiterte Aufgaben

### 4. Weitere Anwendungen deployen
- [ ] **Nextcloud**:
  - [ ] Logge Dich in Nextcloud ein
- [ ] **JupyterLab**:
  - [ ] Logge Dich in Jupyter ein
- [ ] **MariaDB**:
  - [ ] Erstelle eine Datenbank
  - [ ] Überprüfe, ob Deine Datenbank läuft
  - [ ] Logge Dich in eine Datenbank ein
- [ ] **Open GDB Triplestore**:
  - [ ] Überprüfe ob Dein Triplestore läuft
  - [ ] Erstelle einen neuen Triplestore
- [ ] **Shared Folder**:
  - [ ] Deploye einen Shared Folder
  - [ ] Teste den Zugriff von verschiedenen Anwendungen
  - [ ] Teste den Zugriff auf fremde Ordner
- [ ] **Webprotégé**:
  - [ ] Erstelle einen Account in Webprotege und logge Dich ein

### 5. Projekte verwalten
- [ ] **Standard-Projekt**: Überprüfe Dein automatisch erstelltes Standard-Projekt
- [ ] **Neues Projekt erstellen**:
  - [ ] Navigiere zu Deinen Projekten
  - [ ] Erstelle ein neues Projekt mit Namen und Beschreibung
- [ ] **Projektmitglieder hinzufügen**:
  - [ ] Füge eine andere Person zu Deinem Projekt hinzu
- [ ] **Anwendung zu Projekt zuordnen**:
  - [ ] Ordne eine bestehende Anwendung einem Projekt zu

### 6. Kollaboration testen
- [ ] **Zugriff auf fremde Anwendung**:
  - [ ] Bitte eine andere Person, ein WissKI zu erstellen und Dich zum Projekt hinzuzufügen
  - [ ] Logge Dich in das von der anderen Person erstellte WissKI ein
  - [ ] Überprüfe, dass Du Admin-Rechte im WissKI hast
- [ ] **Shared Folder Kollaboration**:
  - [ ] Erstelle einen Shared Folder in einem gemeinsamen Projekt
  - [ ] Teste, dass beide Projektmitglieder lesen und schreiben können
- [ ] **Nextcloud Kollaboration**:
  - [ ] Erstelle Dateien in Nextcloud und gib sie für andere SCS User frei.
  - [ ] Überprüfe, dass SCS User darauf zugreifen können

### 7. Snapshots verwenden
- [ ] **Snapshot erstellen**:
  - [ ] Navigiere zur Snapshot-Erstellung für WissKI
  - [ ] Erstelle einen Snapshot einer WissKI-Umgebung
  - [ ] Warte auf die erfolgreiche Erstellung
  - [ ] Überprüfe die Snapshot-Details (Datum, Größe, Checksummen)
- [ ] **Snapshot wiederherstellen**:
  - [ ] Stelle einen Snapshot wieder her
  - [ ] Überprüfe, dass alle Daten korrekt wiederhergestellt wurden

## Administrative Aufgaben

### 8. Administration erkunden
- [ ] **Components**: Überprüfe die Liste aller Komponenten
- [ ] **Stacks**: Erkunde die verfügbaren Stacks
- [ ] **Service Keys**: (Nur für Admins) Überprüfe die Verwaltung von Service Keys
- [ ] **Projekt-Übersicht**: Sieh Dir alle Projekte im System an

## Checkliste für Testabschluss

- [ ] Alle grundlegenden Funktionen wurden getestet
- [ ] Kollaboration zwischen mehreren Benutzern funktioniert
- [ ] Snapshots können erstellt und wiederhergestellt werden
- [ ] Projekte können verwaltet werden
- [ ] Alle verfügbaren Anwendungstypen wurden mindestens einmal deployt
- [ ] Single Sign-On funktioniert für Jupyter, Nextcloud, WissKI
- [ ] Dashboard zeigt korrekte Status-Informationen
- [ ] Administration-Bereich ist (nicht-)zugänglich und funktional
