# Default Redirect for Unregistered Subdomains

This service catches HTTP requests to unregistered subdomains under `*.scs.sammlungen.io` and redirects them to `manager.scs.sammlungen.io` to avoid SSL security warnings.

## How It Works

1. **Traefik Priority System**: The service uses Traefik's priority system to act as a fallback.
   - Regular services have default priority (or higher).
   - This default page has priority `1` (lowest).
   - When a request comes in, Traefik routes to the most specific match first.

2. **Routing Rules**:

   **Bare Domain Redirect (Priority 100):**
   - `http://scs.sammlungen.io` → 308 → `https://manager.scs.sammlungen.io`
   - `https://scs.sammlungen.io` → 308 → `https://manager.scs.sammlungen.io`

   **Unregistered Subdomain Redirect (Priority 1, HTTP only):**
   ```
   HostRegexp(`^.+\.scs\.sammlungen\.io$`)
   ```
   - Catches: `http://random.scs.sammlungen.io`
   - Redirects to: `https://manager.scs.sammlungen.io`
   - Works for any depth: `http://deep.nested.test.scs.sammlungen.io`

3. **SSL Security Warning Avoidance:**
   - HTTP requests are caught and redirected **before** SSL/TLS
   - No wildcard certificate needed
   - Users typing `random.scs.sammlungen.io` (without https://) get seamless redirect
   - Direct HTTPS requests (`https://random...`) will show security warning (rare case)

3. **Static HTML**: Serves a clean, informative page listing all available services.

## Integration

The service is defined in the main `docker-compose.yml` as `scs--default-page`. It reads configuration files from this directory:
- `index.html` - The static page content.
- `nginx.conf` - Nginx web server configuration.

## Deployment

The service is part of the main stack. To deploy or update:

```bash
# Deploy the entire stack.
docker-compose up -d

# Or deploy just the default page.
docker-compose up -d scs--default-page
```

## Customization

### Update the Service List

Edit `index.html` to add/remove services or change links. Update the service cards in the grid section.

### Change Styling

The page uses Tailwind CSS via CDN. Modify classes in `index.html` to customize the appearance.

### SSL Certificates

Traefik will automatically provision Let's Encrypt SSL certificates for any subdomain that resolves to your server, including unregistered ones caught by this service.

## Troubleshooting

### Default page not showing

1. Check that the service is running:
   ```bash
   docker ps | grep scs--default-page
   ```

2. Verify Traefik can see the service:
   ```bash
   docker logs scs--reverse-proxy | grep default-page
   ```

3. Check priority settings - specific services should have higher priority than 1.

### Wrong service showing for unregistered domains

Ensure other services don't use wildcard routes that might conflict. Specific Host rules should always take precedence over HostRegexp.
