# Maintenance

This section covers ongoing maintenance tasks for the SODa SCS Manager deployment.

## Topics

- **[Updates and maintenance](updates.md)** — How to update services (especially Nextcloud), handle post-update tasks, troubleshoot common issues, and use backup/restore scripts.

## Overview

The deployment includes multiple services (Nextcloud, Keycloak, JupyterHub, Drupal, etc.) that may need updates, backups, and regular maintenance. Each service has its own update process and requirements.

Key maintenance tasks:

- **Updates** — Keeping services up to date with security patches and new features.
- **Backups** — Regular database and volume backups to prevent data loss. Automated backup scripts available for Nextcloud.
- **Monitoring** — Checking logs, admin panels, and Traefik dashboard for errors or warnings.
- **Database maintenance** — Cleaning up old data, running repair/optimize commands.
- **Volume cleanup** — Removing unused Docker images and volumes.

Always back up before major changes. See the [Updates](updates.md) page for detailed procedures.

## Quick reference

### Nextcloud backup and restore

**Backup** (creates timestamped backups in `/srv/backups/nextcloud/`):
```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**Restore** (interactive, lists available backups):
```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

### Nextcloud maintenance

**Run all post-update maintenance** (repair, DB indices, columns, primary keys):
```bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
```

**Apply proxy and region settings** (for existing installs):
```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

**Configure email** (from env vars, for existing installs):
```bash
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash
```
