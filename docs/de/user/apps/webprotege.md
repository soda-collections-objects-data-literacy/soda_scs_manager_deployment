# WebProtégé

<figure class="scs-figure">
  <img src="../../assets/images/apps/webprotege.svg" alt="Logo of the Protégé application.">
</figure>

## Übersicht

WebProtégé ist eine kostenlose, quelloffene, webbasierte Plattform für die kollaborative Ontologieentwicklung, die es Benutzern ermöglicht, OWL-2-Ontologien direkt über einen Webbrowser zu erstellen, zu bearbeiten und zu teilen. Die Plattform macht lokale Softwareinstallationen überflüssig und bietet gleichzeitig umfassende Werkzeuge für die Wissensmodellierung und das kollaborative Ontologie-Engineering.

## Möglichkeiten

WebProtégé ermöglicht die kollaborative Ontologieentwicklung, bei der mehrere Benutzer über eine gemeinsame Weboberfläche gleichzeitig an OWL-2-Ontologien arbeiten können. Die Plattform unterstützt den gesamten Ontologie-Lebenszyklus – von der anfänglichen Konzeptmodellierung bis hin zur komplexen Wissensdarstellung – und bietet Tools für die Zusammenarbeit in Echtzeit, die Änderungen nachverfolgen und die Beiträge der Benutzer in verteilten Teams verwalten.

Das System bietet umfassende Funktionen zur Ontologiebearbeitung, mit denen Benutzer Klassen, Eigenschaften und Individuen erstellen und gleichzeitig komplexe Beziehungen und Einschränkungen definieren können. Fachexperten können über anpassbare Webformulare beitragen, die auf bestimmte Wissensdomänen zugeschnitten sind, wodurch die Ontologieentwicklung auch für Benutzer zugänglich wird, die keine tiefgreifenden technischen Kenntnisse in formaler Logik oder OWL-Syntax besitzen.

Die Zusammenarbeit wird durch integrierte Diskussionsstränge, detaillierte Änderungsverfolgung und einen Revisionsverlauf erleichtert, der einen vollständigen Prüfpfad der Ontologieentwicklung aufbewahrt. Benutzer können bestimmte Ontologieelemente kommentieren, Änderungen vorschlagen und direkt innerhalb der Plattform strukturierte Diskussionen über Modellierungsentscheidungen führen.

Die Plattform unterstützt mehrere Ontologieformate, darunter RDF/XML, Turtle, OWL/XML und OBO, und gewährleistet so die Interoperabilität mit bestehenden Tools und Arbeitsabläufen. Ihre Import-/Exportfunktionalität erleichtert die Integration mit Desktop-Ontologie-Editoren und anderen Semantic-Web-Tools und gewährleistet gleichzeitig die Formatkompatibilität zwischen verschiedenen Systemen.

## Eine bestehende Ontologie importieren

Um mit einer bestehenden Ontologie zu beginnen, öffnen Sie die WebProtégé-Anwendung im SCS Manager und wählen den Reiter **Ontologie importieren**. Laden Sie eine Datei in RDF/XML (`.owl`, `.rdf`), Turtle (`.ttl`) oder OWL Functional Syntax (`.ofn`) hoch, auf Wunsch mit einer Revisionsnachricht. Die Klassen, Properties und übrigen Axiome der Datei werden dem Projekt hinzugefügt; im Projekt wird nichts entfernt. Der Import erscheint als neue Revision in der Historie des Projekts. Importieren kann nur der Projekteigentümer.

- **Importe:** Die Ontologien, die die Datei importiert (`owl:imports`), werden mitgeladen, und ihre Axiome kommen ebenfalls ins Projekt. Jeder Import muss eine öffentliche `http`- oder `https`-Adresse sein, die jeder herunterladen kann; eine Datei, die eine Adresse im SCS-Netz, eine lokale Datei oder einen relativen Pfad importiert, wird abgelehnt. Importe der importierten Ontologien lädt WebProtégé unverändert.
- **OWL/XML:** Eine `.owl`-Datei muss RDF/XML sein. Hat Protégé Ihre Ontologie als OWL/XML gespeichert, speichern Sie sie erneut als RDF/XML oder Turtle (**File → Save as**) und laden diese Datei hoch.
- **Größe:** Dateien bis 50 MB.

Verwenden Sie dafür nicht **Apply external edits** in WebProtégé: Es übernimmt nur eine Datei, deren Ontologie-IRI der des Projekts entspricht. Bei einem vom SCS Manager angelegten Projekt importiert es deshalb nichts, meldet aber trotzdem Erfolg.

## Links

- [Link zur Webprotégé Website](https://protegewiki.stanford.edu/wiki/WebProtege)
- [Homepage des SODa SCS Webprotégé](https://webprotege.scs.sammlungen.io/)
