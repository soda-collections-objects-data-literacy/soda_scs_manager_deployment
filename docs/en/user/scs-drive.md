# SCS Drive

Your personal **SCS Drive** is cloud storage powered by Nextcloud. It is the central place for files, documents, and collaboration in the SCS (Scholarly Communication System) platform.

## File storage

Your drive works like any cloud storage: upload, organise, share, and access files from anywhere. Everything stored here belongs to you and is only accessible to people you explicitly share it with.

## OnlyOffice — Office suite

OnlyOffice is integrated directly into your drive. You can create and edit:

- **Text documents** (`.odt`)
- **Spreadsheets** (`.ods`)
- **Presentations** (`.odp`)

Click **+ New** in the Files view to create a document, or open an existing one — OnlyOffice opens in the browser.

## Draw.io — Diagrams & visualisations

Draw.io is available as a built-in app for diagrams, flowcharts, mind maps, and network diagrams. Click **+ New → New diagram**. Diagrams are saved as `.drawio` files in your drive.

## Project folders

Every SCS project has a **Team Folder** with the project's name. All project members see it in their drive and can work in it together. The project's applications use the same folder:

- **WissKI** — semantic data management for cultural heritage and research data
- **JupyterHub** — interactive computing for analysis and notebooks

In JupyterHub, every project has one shared JupyterLab. All members work in it at the same time and see each other's edits live. Open it from the project's **JupyterHub** card in the SCS Manager; it starts on its own and stops after an hour without use. The project folder is under `nextcloud/<project name>`. Your personal files and other folders are not shown there.

- New members can open the Lab right away, no restart needed.
- Members share the Lab: they see each other's terminals and running kernels, and stopping or restarting it affects everyone.
- Changes made in the drive appear in the Lab after about 30 seconds. If someone edits the same file in the drive and in the Lab at once, the last save wins.
- In the drive's activity list, changes made from the Lab appear as **SCS project mounts**.

## The SCS-Share folder

The **`SCS-Share`** folder is a **shared Team Folder** (not a private home folder) for exchanging files across the platform. Files for a project belong in that project's folder, where its applications can use them.

## Need help?

Contact your system administrator for access, sharing, or quota questions. Platform services: [Available services](services.md).
