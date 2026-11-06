# OpenGDB

<figure class="scs-figure">
  <img src="../../assets/images/apps/opengdb.svg" alt="Logo of the Open GDB triplestore.">
</figure>

## Übersicht

OpenGDB ist ein RDF4J-basierter Triplestore, der den Standard-RDF4J-Server um umfassende Benutzerverwaltungs- und Sicherheitsfunktionen erweitert. Das System baut auf der Kernfunktionalität von RDF4J auf, indem es eine Django-basierte Authentifizierungsschicht, Repository-Verwaltungsfunktionen und Netzwerksicherheitskontrollen über einen spezialisierten Proxy hinzufügt, der den Zugriff auf interne Netzwerke über SPARQL-Abfragen verhindert. Die gesamte Lösung ist für die Bereitstellung mit Docker-Containern paketiert.

## Möglichkeiten

OpenGDB ermöglicht Mehrbenutzerspeicherung von RDF-Daten, bei der Sie RDF-Daten mit Standard-SPARQL speichern und abfragen können, während Sie mehrere Repositories mit granularen Zugriffskontrollen pro Repository verwalten. Benutzer authentifizieren sich entweder über eine Weboberfläche oder API-Token, was Flexibilität für interaktiven und programmatischen Zugriff bietet.

Die Plattform bietet umfassende Repository-Verwaltungsfunktionen, die es Administratoren ermöglichen, RDF-Repositories zu erstellen und zu konfigurieren, während sie spezifische Benutzerberechtigungen für den Repository-Zugriff festlegen. Alle Verwaltungsoperationen sind über REST-API-Endpunkte zugänglich, was programmatische Administration und Integration in bestehende Systeme ermöglicht.

Sicherheit steht im Mittelpunkt: Das System blockiert SPARQL-SERVICE-Abfragen vom Zugriff auf localhost oder interne Netzwerke – wodurch eine häufige Schwachstelle in Triplestore-Bereitstellungen behoben wird. Die Leistung wird durch Token-basierte Authentifizierung optimiert, die die API-Antwortzeiten im Vergleich zur traditionellen sitzungsbasierten Authentifizierung erheblich verbessert. Benutzersitzungen und -berechtigungen werden über die Admin-Oberfläche von Django verwaltet.

Der API-Zugriff folgt Industriestandards und bietet GraphDB-kompatible REST-Endpunkte unter /rest/security/users und /rest/repositories/, während die volle Unterstützung für Standard-RDF4J-Protokolle beibehalten wird. Die Authentifizierung kann je nach Leistungsanforderungen entweder über Basic Authentication oder Token-basierte Methoden erfolgen.

## Links

- [Repository der OpenGDB](https://github.com/FAU-CDI/open_gdb)
- [Website der RDF4J-Triplestore-Software](https://rdf4j.org/)
