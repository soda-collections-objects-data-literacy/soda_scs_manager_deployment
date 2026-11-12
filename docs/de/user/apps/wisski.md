# WissKI-Umgebung

<figure class="scs-figure">
  <img src="../../assets/images/apps/wisski.svg" alt="Logo of the WissKI stack, with triplestore and database.">
</figure>

## Description

**WissKI** (Wissenschaftliche Kommunikationsinfrastruktur) ist ein spezialisiertes System zur Verwaltung und Publikation von Forschungs- und Kulturgutdaten, das auf [WissKI](https://wiss-ki.eu/) und dem Open-Source-CMS [Drupal](https://new.drupal.org/home) basiert. Als digitale Plattform eignet es sich u. a. für Museumssammlungen, (Universitäts-)Sammlungen und andere kontexte, in denen Objekte und Metadaten langfristig erschlossen und bereitgestellt werden sollen.

WissKI versteht sich als [virtuelle Forschungsumgebung](https://wiss-ki.eu/) und Software für *Linked Open Data*: Inhalte lassen sich über gewohnte Eingabemasken erfassen, während die semantische Modellierung und Anbindung an offene Standards die Nutzung von RDF und Ontologien ermöglichen. Die Datenmodellierung folgt einem ontologischen Ansatz, vorzugsweise, aber nicht ausschließlich, im Umfeld von [CIDOC CRM](https://cidoc-crm.org/). Nutzerinnen und Nutzer können dabei u. a. **Revisionen** und **Übersetzungen** führen, Zugang über **vielfältige Schnittstellen** öffnen und zugleich **fein abgestufte Rechte** setzen, um Sichtbarkeit und Bearbeitung zu steuern. WissKI unterstützt zudem Ziele rund um **auffindbare, zugängliche, interoperable und wiederverwendbare (FAIR)** Forschungsdaten entlang des Forschungsdaten-Lebenszyklus.

Technisch ist das verlinkte Wissen typischerweise in einem **externen Triplestore** mit eigenen Endpunkten abgelegt und damit in seiner RDF-Schicht weitgehend **unabhängig von der Drupal-Installation** adressierbar. In *dieser* Auslieferung ist WissKI für Sammlungskontexte vorkonfiguriert und kommt mit einem **OpenGDB-Triplestore**, einer **MariaDB-Datenbank** (Drupal) sowie einem abgestimmten **Standard-Datenmodell** und **Modul- und Setup** im Sinne des [WissKI Barrel](https://wisski-barrels.de/)-Ansatzes: vorgefertigte, praxiserprobte [Erschließungs- und Publikationsumgebungen](https://wisski-barrels.de/introduction) mit passenden Modulen, Eingabemasken und Ansichten (siehe [Vorgehen und Methodik](https://wisski-barrels.de/approach) am Barrel-Projekt).

Das Standard-Datenmodell ist optional: Im Formular zum Anlegen gibt es die Checkbox **Mit WissKI Default Data Model**, die standardmäßig angehakt ist. Ohne Haken startet eine reine Drupal/WissKI-Site: Sie ist mit ihrem Triplestore verbunden, hat aber keine WissKI-Ontologie, kein Default Data Model und keine Eingabemasken oder Ansichten daraus. Eigene Ontologien und Pathbuilder legen Sie selbst an. Die Wahl lässt sich nach dem Anlegen nicht mehr ändern.

Hintergrund und Community: Informationen zu Geschichte, Förderung und Vernetzung finden sich auf [wiss-ki.eu](https://wiss-ki.eu/) (u. a. [Dokumentation](https://wiss-ki.eu/documentation) sofern verlinkt) und in der [WissKI-Bibliothek (Zotero)](https://www.zotero.org/groups/4528320/wisski-library). Fragen an die Community: [E-Mail](mailto:info@wiss-ki.eu) oder [chat.wiss-ki.eu](http://chat.wiss-ki.eu/).

## Links

- [Webseite des WissKI-Drupal-Moduls](https://wiss-ki.eu)
- [Webseite des Drupal Content Management Systems](https://drupal.org)
- [Repository des Drupal Rezeptmoduls für das WissKI Default Data Models](https://www.drupal.org/project/wisski_default_data_model)
- [Überblick über das WissKI Default Barrel](https://wisski-barrels.de/barrels/default)
- [Repository des Open GDB Triplestores](https://github.com/FAU-CDI/open_gdb)
- [Webseite der Relationalen Database MariaDB](https://mariadb.org/)
