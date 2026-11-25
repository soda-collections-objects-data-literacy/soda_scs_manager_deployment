# WebProtégé

WebProtégé bearbeitet Ontologien im Browser. Was der Dienst ist: [WebProtégé](../apps/webprotege.md).

Du öffnest es über die Karte **WebProtégé** auf der Projektseite. Es öffnet die Ontologie dieses Projekts. Die Demo-Ontologie ist die hinter der Demo-WissKI: CIDOC CRM mit seinen Erweiterungen (CRMdig, CRMsci, CRMinf), LRMoo und die WissKI-Default-Ontologie, rund 260 Klassen und 550 Properties.

Die Oberfläche von WebProtégé ist englisch. Hat eine Klasse ein deutsches Label, zeigt der Baum es an, zum Beispiel *E1 CRM Entität*.

## Die Ontologie eines Projekts

Jedes Projekt hat eine Ontologie in WebProtégé. Sie entsteht mit dem Projekt; du legst sie nicht selbst an. Du füllst sie auf zwei Wegen:

- **Aufbauen**, Klasse für Klasse, wie unten beschrieben.
- **Importieren** aus einer vorhandenen Ontologie-Datei, siehe [Eine bestehende Ontologie importieren](../apps/webprotege.md#eine-bestehende-ontologie-importieren).

Die Beispiele unten erweitern die Demo-Ontologie. Die Demo ist der richtige Ort zum Ausprobieren: **Demo zurücksetzen** auf der Projektseite stellt die Ontologie wieder her.

## Klassen und Hierarchie

Der Reiter **Classes** zeigt links die **Class Hierarchy**: Jede Klasse steht unter ihrer Oberklasse. Die Wurzel ist `owl:Thing`. Die drei Knöpfe über dem Baum legen eine Klasse an, löschen die ausgewählte und suchen.

Um eine Klasse zu finden, wähle die Lupe und tipp ein paar Buchstaben, zum Beispiel `Cultural`. **Search for Class** listet die Treffer; wähle einen aus und dann **Select**.

Der Editor in der Mitte zeigt die ausgewählte Klasse: **IRI**, **Annotations**, **Parents** und **Relationships**. `Cultural_Heritage_Item` aus der WissKI-Default-Ontologie steht unter CIDOC CRM `E22_Human-Made_Object`; ihr `rdfs:comment` sagt, was hineingehört.

![Klasse Cultural_Heritage_Item mit Label, Scope Note und Oberklasse E22_Human-Made_Object](../images/guides/webprotege-klasse.png)

### Eine Klasse anlegen

Leg als Beispiel eine Klasse für Wanderkrüge unter `Cultural_Heritage_Item` an:

1. Wähle `Cultural_Heritage_Item` im Baum aus.
2. Wähle den ersten Knopf über dem Baum (Klasse anlegen).
3. Gib in **Create Classes** unter **Class names** `Wanderkrug` ein. Ein Name pro Zeile legt mehrere Klassen auf einmal an. **Language Tag** `de` macht den Namen zum deutschen Label.
4. Wähle **Create**.

![Dialog Create Classes mit dem Namen Wanderkrug und dem Language Tag de](../images/guides/webprotege-klasse-anlegen.png)

Die neue Klasse erscheint im Baum unter `Cultural_Heritage_Item`, mit dem Label *Wanderkrug*@de. Ihre IRI erzeugt WebProtégé selbst. Um eine Klasse unter eine andere Oberklasse zu hängen, zieh sie im Baum dorthin oder ändere **Parents** im Editor.

### Labels und Scope Note

Unter **Annotations** im Editor ist jede Zeile eine Property, ein Wert und eine Sprache:

1. Tipp in der leeren Zeile unter **Enter property** `rdfs:label` und wähle es aus der Liste. Unter **Enter value** schreibst du `Travelling jug`, unter **lang** `en`.
2. Füge in der nächsten leeren Zeile `rdfs:comment` als Scope Note hinzu: was in diese Klasse gehört und was nicht, zum Beispiel *Ein Krug mit engem Hals und Henkel, gemacht, um Flüssigkeiten auf Reisen zu tragen. Krüge, die nur bei Tisch benutzt wurden, gehören zu Cultural_Heritage_Item.*, Sprache `de`.

![Klasse Wanderkrug mit zwei Labels und einer Scope Note](../images/guides/webprotege-scope-note.png)

Jede Änderung wird sofort gespeichert und erscheint rechts im **Project Feed**.

Die Scope Note entscheidet, wie andere die Klasse verwenden. Sieh dir CIDOC CRM als Vorbild an: Das `rdfs:comment` seiner Klassen und Properties beginnt mit *Scope note:*.

## Properties: Domain und Range

Der Reiter **Properties** listet die Properties in drei Unterreitern:

- **Object Properties** verbinden zwei Individuen, zum Beispiel ein Objekt und sein Material.
- **Data Properties** verbinden ein Individuum mit einem Literal, einem Wert wie einem Text, einer Zahl oder einem Datum.
- **Annotation Properties** versehen Klassen und Properties mit Notizen, etwa `rdfs:label`, `rdfs:comment` oder `skos:prefLabel`.

Die **Domain** einer Property ist die Klasse der Dinge, von denen sie ausgeht. Die **Range** ist die Klasse (oder der Datentyp) dessen, worauf sie zeigt. In der Demo hat *P45 besteht aus* (`P45_consists_of`) die Domain `E18 Materielles` und die Range `E57 Material`; ihre Scope Note erklärt die Property.

![Object Property P45 besteht aus mit Labels in mehreren Sprachen, Scope Note und Domain](../images/guides/webprotege-property-p45.png)

### Eine Object Property anlegen

Als Beispiel eine Property, die einen Wanderkrug mit dem Typ seines Motivs verbindet:

1. Wähle in **Properties → Object Properties** den Anlegen-Knopf über dem Baum. Die neue Property wird Unter-Property der ausgewählten; ist keine ausgewählt, entsteht sie oben.
2. Gib `hat Motivtyp` ein, Language Tag `de`, und wähle **Create**.
3. Tipp unter **Domain** in **Enter a class name** `Wanderkr` und wähle *Wanderkrug* aus der Liste.
4. Tipp unter **Range** `E55` und wähle *E55 Typus* aus der Liste.

![Vorschläge zu E55: die Klasse E55 Typus oder New Class named E55](../images/guides/webprotege-range-vorschlag.png)

Wähle immer aus der Liste. Der letzte Eintrag, **New Class named …**, würde eine neue Klasse anlegen, statt die vorhandene zu nutzen. Ein Name, der nicht in der Liste steht, wird als *does not exist* markiert und nicht gespeichert.

![Object Property hat Motivtyp mit Domain Wanderkrug und Range E55 Typus](../images/guides/webprotege-domain-range.png)

### Eine Data Property mit Literal anlegen

Eine Data Property zeigt auf ein Literal, nicht auf eine Klasse:

1. Wähle in **Properties → Data Properties** den Anlegen-Knopf und gib `hat Fassungsvermögen` ein.
2. Wähle unter **Domain** `Wanderkrug`.
3. Tipp unter **Range** in **Enter a datatype name** und wähle den Datentyp `xsd:string`.

![Data Property hat Fassungsvermögen mit Domain Wanderkrug und Range xsd:string](../images/guides/webprotege-data-property.png)

Andere Ranges sind `xsd:integer` für ganze Zahlen, `xsd:decimal` für Zahlen mit Nachkommastellen, `xsd:date` für ein Datum und `xsd:anyURI` für eine Adresse. **Functional** unter **Characteristics** heißt: höchstens ein Wert pro Individuum. Das WissKI-Default-Datenmodell nutzt für die meisten Werte `P3_has_note` mit Text, zum Beispiel für die Inventarnummer.

Auch Annotationen sind Literale: Ein Label wie `"Wanderkrug"@de` ist ein Text mit Sprachkennung.

## Gemeinsam arbeiten

Jedes Projektmitglied kann die Ontologie öffnen, sobald es die Einladung angenommen hat.

- Zwei Personen können gleichzeitig bearbeiten. Jede Änderung wird sofort gespeichert; der **Project Feed** zeigt, wer was geändert hat.
- **Kommentare:** Wähle eine Klasse oder Property und dann den Knopf im Bereich **Comments** rechts, um einen Thread zu beginnen, zum Beispiel *Brauchen wir die Klasse Wanderkrug, oder reicht ein Objekttyp?* Andere antworten mit **Reply**; **Resolve** schließt den Thread. Eine Sprechblase mit Zahl im Baum markiert Einträge mit Kommentaren.
- **Änderungen:** Der dritte Knopf über dem Editor (**Changes**) listet jede Revision der ausgewählten Klasse oder Property mit Person, Zeit und den hinzugefügten (grün) und entfernten (rot) Axiomen.

![Kommentar-Thread zu hat Motivtyp mit Reply und Resolve](../images/guides/webprotege-kommentar.png)

![Änderungen der Klasse Wanderkrug, Revision für Revision](../images/guides/webprotege-aenderungen.png)

## Die Ontologie herunterladen

**Home** oben listet deine Projekte. Das Menü **≡** am Ende einer Zeile hat **Download**: Es speichert die Ontologie als Datei, zum Beispiel in RDF/XML oder Turtle.

![Projektmenü auf der Startseite mit Open, Download und Move to trash](../images/guides/webprotege-projektmenue.png)

Die Ontologie in WebProtégé und die Ontologien in der WissKI sind getrennte Kopien: Klassen, die du in WebProtégé anlegst, erscheinen nicht von selbst im WissKI-Pathbuilder. Die Ontologie einer WissKI auszutauschen ist eine Aufgabe für Administratoren, siehe [Der Pathbuilder](wisski.md#der-pathbuilder).
