# Webprotégé

<figure class="scs-figure">
  <img src="../../assets/images/apps/webprotege.svg" alt="Logo of the Protégé application.">
</figure>

## Overview

WebProtégé is a free, open-source, web-based platform for collaborative ontology development that enables users to create, edit, and share OWL 2 ontologies directly through a web browser. The platform eliminates the need for local software installations while providing comprehensive tools for knowledge modeling and collaborative ontology engineering.

## Possibilities

WebProtégé enables collaborative ontology development where multiple users can work simultaneously on OWL 2 ontologies via a shared web interface. The platform supports the entire ontology lifecycle—from initial concept modeling to complex knowledge representation—featuring real-time collaboration tools that track changes and manage user contributions across distributed teams.

The system provides comprehensive ontology editing capabilities, allowing users to create classes, properties, and individuals while defining complex relationships and constraints. Domain experts can contribute through customizable web forms tailored to specific knowledge domains, making ontology development accessible even to users without deep technical expertise in formal logic or OWL syntax.

Collaboration is facilitated through integrated discussion threads, detailed change tracking, and a revision history that preserves a complete audit trail of the ontology's evolution. Users can comment on specific ontology elements, propose changes, and engage in structured discussions about modeling decisions directly within the platform.

The platform supports multiple ontology formats, including RDF/XML, Turtle, OWL/XML, and OBO, ensuring interoperability with existing tools and workflows. Its import/export functionality facilitates integration with desktop ontology editors and other semantic web tools while maintaining format compatibility across different systems.

## Import an existing ontology

To start from an existing ontology, open the WebProtégé application in the SCS Manager and choose the **Import ontology** tab. Upload an RDF/XML (`.owl`, `.rdf`), Turtle (`.ttl`) or OWL functional syntax (`.ofn`) file and, if you like, a revision message. The classes, properties and other axioms of the file are added to the project; nothing in it is removed. The import shows up as a new revision in the project's history. Only the project owner can import.

- **Imports:** the ontologies the file imports (`owl:imports`) are loaded too, and their axioms are added as well. Every import must be a public `http` or `https` address that anyone can download; a file that imports an address inside the SCS network, a local file or a relative path is refused. Imports of the imported ontologies are loaded by WebProtégé as they are.
- **OWL/XML:** an `.owl` file must be RDF/XML. If Protégé saved your ontology as OWL/XML, save it again as RDF/XML or Turtle (**File → Save as**) and upload that file.
- **Size:** files up to 50 MB.

Do not use **Apply external edits** in WebProtégé for this: it only merges a file whose ontology IRI is the same as the project's, so for a project created by the SCS Manager it imports nothing, even though it reports success.

## Links

- [Link to the Webprotégé website](https://protegewiki.stanford.edu/wiki/WebProtege)
- [Homepage of the Webprotégé SCS instance](https://webprotege.scs.sammlungen.io/)
