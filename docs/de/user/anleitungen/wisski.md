# WissKI

WissKI erfasst Objekte und alles um sie herum (Personen, Orte, Ereignisse, Materialien) als Linked Data. Was der Dienst ist: [WissKI-Umgebung](../apps/wisski.md).

## Öffnen und anmelden

Du öffnest die WissKI über ihre Karte auf der Projektseite. Die Demo-WissKI hat das Default-Datenmodell und ein Beispielobjekt: *Antique WissKI Ceramic Travelling Jug with Network Motifs*.

Zum Bearbeiten meldest du dich an: **Log in → Mit SCS SSO anmelden**. Die SCS-Anmeldung fragt dabei eventuell noch einmal nach deinem Passwort.

![WissKI-Anmeldung mit dem Knopf Mit SCS SSO anmelden](../images/guides/wisski-anmelden.png)

Die Person, der das Projekt gehört, ist Administrator der WissKI. Das Menü links (**Erstellen**, **WissKI**, **Struktur**, **Konfiguration** …) sehen angemeldete Personen; das Menü oben (**Browse**, **Erstellen**) gehört zur Website selbst.

## Das Demo-Objekt ansehen

1. Öffne die Liste der Objekte: **Browse → Objekt** oder die Adresse `/wisski/navigate/bb48a22d36f1c15cd16b143d23466812/list`.
2. Öffne *Antique WissKI Ceramic Travelling Jug with Network Motifs*.

![Objektseite des Wanderkrugs mit den Reitern Allgemein, Details, Medien, Provenienz und Datensatz](../images/guides/wisski-objekt.png)

Die Seite ist in Reiter geteilt. **Allgemein** zeigt Titel, weitere Titel, den Objekttyp (*Jug*), den Standort, die Inventarnummer, die Beschreibung, ein Schlagwort und den derzeitigen Verwalter (*Germanic National Museum*). **Details** enthält Abmessungen, Materialien (*Ceramic*, *Clay*, *Terracotta*) und die Herstellung durch *Mark Fichtner*, **Provenienz** die Schenkung 2008 in *Nuremberg*.

Jeder dieser Einträge, zum Beispiel *Clay* oder *Nuremberg*, ist ein eigener Datensatz mit eigener Seite. Das Objekt verweist nur darauf. Das ist der Unterschied zu einer Tabelle: *Clay* gibt es einmal, und jedes Objekt aus Ton verweist auf denselben Datensatz.

## Ein Objekt erfassen

1. Öffne **Erstellen → Objekt** oder die Adresse `/wisski/create/bb48a22d36f1c15cd16b143d23466812`.
2. Füll im Reiter **Allgemein** **Präferierter Titel** aus, zum Beispiel `Wanderkrug, Kopie`, und **Inventarnummer**, zum Beispiel `DEMO-0002`.

    ![Formular Neu erstellen Objekt, Reiter Allgemein](../images/guides/wisski-formular.png)

3. Füge im Reiter **Details** über den Referenzdialog ein **Material** hinzu, siehe [unten](#datensatze-verknupfen-der-referenzdialog). Wähle *Clay*.
4. Leg unter **Produktion** mit **+** ein Herstellungsereignis an und gib ihm ein Datum, siehe [Datumsangaben in EDTF](#datumsangaben-in-edtf).
5. Wähle unten **Speichern**.

Das Objekt steht jetzt in der Objektliste. Auf seiner Seite öffnet **Bearbeiten** das Formular wieder.

## Datensätze verknüpfen: der Referenzdialog

Die meisten Felder des Default-Datenmodells nehmen keinen Text, sondern einen Verweis auf einen anderen Datensatz: Material, Ort, Akteur, Ereignis, Datum. Diese Felder nutzen den **Referenzdialog**. Unter jedem solchen Feld stehen zwei Knöpfe:

- die **Lupe** (*Search existing*) öffnet das Fenster **Suche**,
- das **+** (*Neu erstellen*) öffnet das Formular des verknüpften Datensatzes in einem Fenster, zum Beispiel ein neues Material. Ausfüllen, speichern: Der neue Datensatz wird in einem Schritt angelegt und verknüpft. Der Link unter dem Feld, etwa *Erstelle neues Material.*, macht dasselbe.

![Feld Material im Reiter Details mit Lupe und +](../images/guides/wisski-referenzfeld.png)

In **Suche** tippst du ein paar Buchstaben in **Title contains**. Schon beim Tippen erscheinen Vorschläge; **Suche** listet alle Treffer unter **Suchergebnisse**. Ein Klick auf einen Treffer verknüpft ihn, und das Fenster schließt sich. Der Stern neben einem Treffer merkt ihn vor; vorgemerkte und schon verknüpfte Datensätze stehen im Fenster, bevor du tippst.

![Fenster Suche mit den Treffern Clay und Clay slip](../images/guides/wisski-referenzfeld-gewaehlt.png)

Neben einem verknüpften Datensatz bearbeitet **Bearbeiten** diesen Datensatz im Fenster, und **Entfernen** löst die Verknüpfung. Entfernen trennt nur: Der Datensatz selbst bleibt.

Erst suchen, dann anlegen. Ein zweiter Datensatz *Clay* spaltet die Daten: Manche Objekte verweisen auf den einen, manche auf den anderen.

## Datumsangaben in EDTF

Datumsangaben gibst du in EDTF ein (Extended Date/Time Format), einer genormten Schreibweise, die auch *um*, *zwischen* und *unsicher* ausdrücken kann. Im Default-Datenmodell ist ein Datum ein eigener Datensatz, ein **Time expression**. Du legst ihn mit dem **+** eines Datumsfelds an, zum Beispiel am Herstellungsereignis. Sein Feld **Text** nimmt den EDTF-Wert auf; der Hilfetext darunter nennt Beispiele.

![Formular Neu erstellen Time expression mit dem EDTF-Wert 1900/1910](../images/guides/wisski-edtf.png)

| Du schreibst | Bedeutung |
|---|---|
| `2008` | das Jahr 2008 |
| `2008-05-14` | 14. Mai 2008 |
| `1900~` | um 1900 |
| `1900?` | vielleicht 1900 |
| `1900/1910` | von 1900 bis 1910 |
| `[1900,1904]` | 1900 oder 1904 |
| `(../1900)/2000` | spätestens 1900 begonnen, 2000 geendet |

Die Erwerbung der Demo ist auf `2008` datiert. WissKI macht aus dem EDTF-Wert eine Zeitspanne mit frühestem und spätestem Anfang und Ende. Ereignislisten sortieren und filtern nach diesen Grenzen, sodass eine Suche nach 1905 auch `1900/1910` findet. Die Anzeige zeigt das Datum lesbar an.

## Bundles, Felder und der Pathbuilder

Diese Teile dienen dazu, das Datenmodell einzurichten. Sie brauchen Administrationsrechte in der WissKI; die Person, der das Projekt gehört, hat sie.

### Bundles und Entitäten

Ein **Bundle** ist eine Art von Datensatz, zum Beispiel *Object*, *Material*, *Place*, *Actor* oder *Event*. Eine **Entität** ist ein einzelner Datensatz dieser Art: Der Wanderkrug ist eine Entität des Bundles *Object*, *Clay* eine Entität des Bundles *Material*.

Die Liste der Bundles steht unter **Struktur → WissKI-Bundles und Objektklassen** (`/admin/structure/wisski_core`).

![WissKI-Bundles und Objektklassen](../images/guides/wisski-bundles.png)

**Bearbeiten** neben einem Bundle und die Reiter auf seiner Seite führen zu:

- **Felder verwalten** — seine Felder,
- **Formularanzeige verwalten** — das Formular: Reihenfolge, Reiter und Widgets,
- **Anzeige verwalten** — die Seite: Reihenfolge und Formatter.

### Feldtypen, Widgets und Formatter

Jedes Feld hat drei Einstellungen:

| Einstellung | Legt fest | Beispiele in der Demo |
|---|---|---|
| **Feldtyp** | was gespeichert wird | *Text* (`string`) für Titel und Inventarnummer, *Langer Text* für die Beschreibung, *Entitätsreferenz* für Material, Ort oder Herstellung, *Datei* und *Bild* für Medien, *Link* für URLs |
| **Widget** | wie es im Formular eingegeben wird | *Textfeld* für den Titel, *Textbereich* für die Beschreibung, *WissKI reference dialog* für das Material, *Auswahlliste* für den Typ eines Ereignisses |
| **Formatter** | wie es auf der Seite erscheint | *Reiner Text* für den Titel, *WissKI entity reference label* für das Material (der Name, verlinkt auf den Datensatz), *Colorbox* für Bilder |

Ein Widget änderst du unter **Formularanzeige verwalten** des Bundles: in der Zeile des Felds das Widget wählen, das Zahnrad öffnet seine Einstellungen. Beim **WissKI reference dialog** sind das **Reference existing entities** (die Lupe), **Create new entities** (das **+**) und **Dialog width**. Dann **Aktualisieren** und unten **Speichern**. Formatter funktionieren genauso unter **Anzeige verwalten**.

![Einstellungen des WissKI reference dialog für das Feld Material](../images/guides/wisski-widget-einstellungen.png)

### Der Pathbuilder

Der Pathbuilder verbindet die Formulare mit der Ontologie. Du findest ihn unter **Konfiguration → WissKI → Pathbuilder** (`/admin/config/wisski/pathbuilder`); das Default-Datenmodell nutzt den Pathbuilder **default**.

![Pathbuilder bearbeiten: default, Reiter Path tree](../images/guides/wisski-pathbuilder.png)

Der Reiter **Path tree** zeigt einen Baum:

- Eine **Gruppe** gehört zu einem Bundle und nennt die Ontologie-Klasse seiner Entitäten. Die Gruppe *Object* hat die Klasse `wisski:Cultural_Heritage_Item`, eine Unterklasse von CIDOC CRM `E22_Human-Made_Object`.
- Ein **Pfad** gehört zu einem Feld. Er ist eine Kette aus Klassen und Properties von der Klasse der Gruppe bis zum Wert.

Zwei Pfade des Demo-Objekts:

| Feld | Pfad | Endet in |
|---|---|---|
| Inventarnummer | `Cultural_Heritage_Item` → `P48_has_preferred_identifier` → `Inventory_Identifier` | einem Text: Datatype Property `P3_has_note`, Feldtyp *Text*, Widget *Textfeld* |
| Material | `Cultural_Heritage_Item` → `P45_consists_of` → `E57_Material` | einem anderen Datensatz: dem Bundle *Material*, Feldtyp *Entitätsreferenz*, Widget *WissKI reference dialog* |

Beim Speichern des Objekts schreibt WissKI diese Ketten als Tripel in den Triplestore. Beim Öffnen liest es sie entlang derselben Pfade wieder aus.

Der Pfeil vor einer Gruppe klappt ihre Pfade auf. **Bearbeiten** neben einem Pfad öffnet ihn; dort wählst du Klassen und Properties Schritt für Schritt aus der Ontologie. **+ Pfad hinzufügen** legt einen Pfad an, **Speichern und Bundles und Felder generieren** speichert den Baum und erzeugt die zugehörigen Bundles und Felder.

Die Klassen und Properties kommen aus den Ontologien, die in der WissKI geladen sind. Sie stehen unter **Konfiguration → WissKI → Ontologie**: in der Demo CIDOC CRM, CRMdig, CRMinf, CRMsci, LRMoo und die WissKI-Default-Ontologie.

![Ontologie: die geladenen Ontologien der Demo-WissKI](../images/guides/wisski-ontologie.png)

!!! warning "Das Default-Datenmodell mit Vorsicht ändern"
    Wer einen Pfad des Default-Datenmodells ändert oder löscht, kann bereits erfasste Daten verbergen: Die Tripel liegen weiter im Triplestore, aber kein Feld liest sie mehr. Probier Änderungen zuerst in der Demo aus. **Demo zurücksetzen** stellt die Demo wieder her.
