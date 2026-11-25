# Grundlegende Aufgaben

Schritt-für-Schritt-Anleitungen für die ersten Handgriffe in jeder Anwendung. Alle Beispiele nutzen das Demoprojekt. Die Bilder zeigen die Demo des Kontos `demo_user`, **demo_user Demo**; deine hat denselben Inhalt unter deinem Namen. Siehe [Projekt anlegen](../projekt-anlegen.md#demo-projekt).

In der Demo kannst du gefahrlos ausprobieren. **Demo zurücksetzen** auf der Projektseite stellt den Ausgangszustand wieder her. Dabei werden alle Änderungen in der WissKI, den Datenbanken, im Jupyter-Home-Verzeichnis, im Team-Ordner und in der WebProtégé-Ontologie der Demo überschrieben. Anwendungen, die du selbst hinzugefügt hast, etwa eine zusätzliche SQL-Datenbank, bleiben.

| Anleitung | Was du lernst |
|---|---|
| [SCS Drive (Nextcloud)](drive.md) | Dokumente anlegen und bearbeiten, gemeinsam daran arbeiten, freigeben, den Team-Ordner nutzen |
| [Diagramme mit draw.io](drawio.md) | Ein Diagramm im Drive anlegen, ein einfaches Flussdiagramm zeichnen, gemeinsam bearbeiten, teilen |
| [JupyterHub](jupyter.md) | Notebooks anlegen und ausführen, im gemeinsamen Lab zusammenarbeiten, über die API in die WissKI schreiben |
| [WissKI](wisski.md) | Ein Objekt erfassen, den Referenzdialog nutzen, Datumsangaben in EDTF, Bundles, Feldtypen, Widgets, Formatter und den Pathbuilder verstehen |
| [WebProtégé](webprotege.md) | Klassen und Properties anlegen, Labels und Scope Notes, Domain und Range, Hierarchie, Literale, gemeinsam arbeiten |
| [Datenbanken](datenbanken.md) | Eine SQL-Datenbank anlegen und in phpMyAdmin verwalten |

Diese Demo-Inhalte nutzen die Anleitungen:

- **WissKI:** das Objekt *Antique WissKI Ceramic Travelling Jug with Network Motifs* (ein antiker Keramik-Wanderkrug) mit seinen Materialien (Ceramic, Clay, Terracotta …), Orten (Nuremberg, Bonn), Akteuren (Germanic National Museum, Mark Fichtner) und der Erwerbung 2008.
- **Team-Ordner:** das Notebook `import_materials_gnd.ipynb` und die Tabelle `materials_gnd.csv` mit 50 Materialien und ihren GND-Normdaten.
- **WebProtégé:** die Ontologie hinter der WissKI: CIDOC CRM mit seinen Erweiterungen, LRMoo und die WissKI-Default-Ontologie.
