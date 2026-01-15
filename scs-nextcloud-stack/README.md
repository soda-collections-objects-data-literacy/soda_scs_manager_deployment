# SCS Nextcloud Stack

This Docker Compose stack provides a complete Nextcloud installation with OnlyOffice integration.

## Services

- **nextcloud**: Nextcloud FPM server (31.0)
- **nextcloud-reverse-proxy**: Nginx reverse proxy for Nextcloud
- **onlyoffice-document-server**: OnlyOffice Document Server (8.3)
- **onlyoffice-reverse-proxy**: Nginx reverse proxy for OnlyOffice
- **redis**: Redis cache for Nextcloud

## Prerequisites

1. External networks must exist:
   - `reverse-proxy` (Traefik network)

2. Volumes must be created:
   ```bash
   docker volume create soda_scs_manager_deployment_nextcloud-data
   docker volume create soda_scs_manager_deployment_onlyoffice-data
   docker volume create soda_scs_manager_deployment_onlyoffice-log
   ```

3. Database (MariaDB) must be running and accessible at hostname `database`

## Setup

1. Copy the environment file:
   ```bash
   cp .env.sample .env
   ```

2. Edit `.env` and set your passwords and domain:
   ```bash
   nano .env
   ```

3. Ensure the Nextcloud hooks directory exists with scripts:
   ```bash
   ls -la hooks/post-installation/
   ```

4. Create the nginx configuration files:
   - `reverse-proxy/nginx.conf` - Main Nextcloud proxy
   - `onlyoffice-proxy/nginx.conf` - OnlyOffice proxy

## Usage

### Start the stack:
```bash
docker compose up -d
```

### View logs:
```bash
docker compose logs -f
```

### Stop the stack:
```bash
docker compose down
```

### Execute Nextcloud occ commands:
```bash
docker compose exec --user www-data nextcloud php occ status
```

### Create Nextcloud databases:
From the parent directory, run:
```bash
../scripts/nextcloud/create-databases.bash
```

### Configure OnlyOffice integration:
From the parent directory, run:
```bash
../scripts/nextcloud/only-office.bash
```

## Access

- **Nextcloud**: https://nextcloud.${SCS_DOMAIN}
- **OnlyOffice**: https://office.${SCS_DOMAIN}

## Traefik Integration

This stack is designed to work behind Traefik reverse proxy with:
- Automatic HTTPS via Let's Encrypt
- HTTP to HTTPS redirect
- Special middlewares for Nextcloud .well-known endpoints

## Volumes

- `nextcloud-data`: All Nextcloud files and configuration
- `onlyoffice-data`: OnlyOffice application data
- `onlyoffice-log`: OnlyOffice logs

## Environment Variables

See `.env.sample` for all available configuration options.

### Required:
- `SCS_DOMAIN`: Your domain name
- `NEXTCLOUD_DB_PASSWORD`: Database password for Nextcloud user
- `NEXTCLOUD_ADMIN_PASSWORD`: Admin password for Nextcloud
- `ONLYOFFICE_JWT_SECRET`: JWT secret for OnlyOffice security

### Optional:
- `NEXTCLOUD_DB_NAME`: Database name (default: nextcloud)
- `NEXTCLOUD_DB_USER`: Database username (default: nextcloud)
- `NEXTCLOUD_ADMIN_USER`: Admin username (default: admin)

## Post-Installation Hooks

The stack includes post-installation hooks that run after Nextcloud initialization:
- Configure trusted domains
- Set up OnlyOffice integration
- Install additional apps (Draw.io, Social Login)

Place your hook scripts in `hooks/post-installation/` with `.sh` extension and executable permissions.

## Troubleshooting

### Check container status:
```bash
docker compose ps
```

### View container logs:
```bash
docker compose logs nextcloud
docker compose logs nextcloud-reverse-proxy
docker compose logs onlyoffice-document-server
```

### Restart services:
```bash
docker compose restart nextcloud
```

### Access container shell:
```bash
docker compose exec nextcloud bash
```

## Security Notes

1. Always use strong passwords for `NEXTCLOUD_ADMIN_PASSWORD` and `NEXTCLOUD_DB_PASSWORD`
2. Keep `ONLYOFFICE_JWT_SECRET` secure and don't share it
3. The `.env` file should never be committed to version control
4. Regular backups of the `nextcloud-data` volume are recommended

## Maintenance

### Update containers:
```bash
docker compose pull
docker compose up -d
```

### Backup data:
```bash
docker run --rm -v soda_scs_manager_deployment_nextcloud-data:/data -v $(pwd):/backup alpine tar czf /backup/nextcloud-backup.tar.gz /data
```

### Restore data:
```bash
docker run --rm -v soda_scs_manager_deployment_nextcloud-data:/data -v $(pwd):/backup alpine tar xzf /backup/nextcloud-backup.tar.gz -C /
```
