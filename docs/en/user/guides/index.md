# Basic tasks

Step-by-step guides for the first things you do in each application. Every example uses the demo project. The pictures show the demo of the account `demo_user`, **demo_user Demo**; yours has the same content under your own name. See [Create a project](../create-project.md#demo-project).

The demo is a safe place to try things out. **Demo zurücksetzen** on the project page brings back the original state. It overwrites every change in the WissKI, the databases, the Jupyter home directory, the team folder and the WebProtégé ontology of the demo. Applications you added yourself, such as an extra SQL database, stay.

| Guide | What you learn |
|---|---|
| [SCS Drive (Nextcloud)](drive.md) | Create and edit documents, work on them together, share them, use the team folder |
| [Diagrams with draw.io](drawio.md) | Create a diagram in the drive, draw a simple flowchart, work on it together, share it |
| [JupyterHub](jupyter.md) | Create and run notebooks, work together in the shared lab, write to WissKI through its API |
| [WissKI](wisski.md) | Record an object, use the reference dialog, enter dates as EDTF, understand bundles, field types, widgets, formatters and the pathbuilder |
| [WebProtégé](webprotege.md) | Create classes and properties, labels and scope notes, domain and range, hierarchy, literals, work together |
| [Databases](databases.md) | Create an SQL database and manage it in phpMyAdmin |

The demo content these guides use:

- **WissKI:** the object *Antique WissKI Ceramic Travelling Jug with Network Motifs*, with its materials (Ceramic, Clay, Terracotta …), places (Nuremberg, Bonn), actors (Germanic National Museum, Mark Fichtner) and the acquisition in 2008.
- **Team folder:** the notebook `import_materials_gnd.ipynb` and the table `materials_gnd.csv` with 50 materials and their GND authority records.
- **WebProtégé:** the ontology behind the WissKI: CIDOC CRM with its extensions, LRMoo and the WissKI default ontology.
