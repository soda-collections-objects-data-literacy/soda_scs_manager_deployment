# WissKI Environment

<figure class="scs-figure">
  <img src="../../assets/images/apps/wisski.svg" alt="Logo of the WissKI stack, with triplestore and database.">
</figure>

## Description

**WissKI** (Wissenschaftliche Kommunikationsinfrastruktur – Scientific Communication Infrastructure) is a specialised system for managing and publishing research and cultural heritage data, built on [WissKI](https://wiss-ki.eu/) and the open-source CMS [Drupal](https://new.drupal.org/home). As a digital platform, it is suited to museum and (university) collections and other settings where objects and metadata need to be described and made available over the long term.

WissKI is presented as a [virtual research environment](https://wiss-ki.eu/) and software for *Linked Open Data*: content can be entered through familiar web forms, while semantic modelling and open standards support RDF and ontologies. Data modelling follows an ontological approach, preferentially but not exclusively in the [CIDOC CRM](https://cidoc-crm.org/) ecosystem. Authors can maintain **revisions** and **translations**, expose data through a **wide range of interfaces**, and apply **fine-grained access control** for who may view or edit what. WissKI also supports goals around **findable, accessible, interoperable and reusable (FAIR)** research data across the research data lifecycle.

From a technical perspective, linked data is typically stored in a dedicated **external triple store** with its own endpoints, so the RDF layer remains largely **independently addressable from the Drupal site**. In *this* deployment, WissKI is preconfigured for collection use cases and ships with an **OpenGDB triple store**, a **MariaDB** database (for Drupal), and a coordinated **default data model** and **module setup** in the sense of the [WissKI Barrel](https://wisski-barrels.de/) approach: ready-to-use, field-tested [curation and publication environments](https://wisski-barrels.de/introduction) with appropriate modules, forms, and views (see the [approach and methodology](https://wisski-barrels.de/approach) of the Barrel project).

Background and community: information on history, funding, and the wider community is on [wiss-ki.eu](https://wiss-ki.eu/) (including [documentation](https://wiss-ki.eu/documentation) as linked from the project site) and in the [WissKI Zotero library](https://www.zotero.org/groups/4528320/wisski-library). For questions, use [email](mailto:info@wiss-ki.eu) or [chat.wiss-ki.eu](http://chat.wiss-ki.eu/).

## Links

- [Website of the WissKI module](https://wiss-ki.eu)
- [Website of the Drupal content management system](https://drupal.org)
- [Repository of the recipe module for the WissKI default data model](https://www.drupal.org/project/wisski_default_data_model)
- [Overview of the WissKI default barrel](https://wisski-barrels.de/barrels/default)
- [Repository of the Open GDB triplestore](https://github.com/FAU-CDI/open_gdb)
- [Website of the MariaDB relational database](https://mariadb.org/)
