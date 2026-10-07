# SCS Manager URLs contain `/index.php`

## Symptom

Drupal links and redirects include `index.php` in the path, for example:

- `https://manager.example.org/index.php/de/admin/structure`
- instead of `https://manager.example.org/de/admin/structure`

The site still works; only URL appearance and “clean URL” behaviour are affected.

## Cause

The Nginx config inside the `scs-manager--drupal` container used a **Drupal 7** rewrite:

```nginx
rewrite ^/(.*)$ /index.php?q=$1 last;
```

Drupal 8+ expects the original path in `REQUEST_URI`. With the legacy rewrite, PHP sees
`REQUEST_URI=/index.php?q=de/...`, Drupal sets `baseUrl` to `/index.php`, and generated links
keep the `index.php` prefix.

## Fix (deployment repo)

This repository mounts a corrected config from
`scs-manager-stack/configs/nginx/drupal.conf`:

```nginx
location @drupal {
  rewrite ^ /index.php last;
}
```

Apply after pulling the change:

```bash
cd /var/deploy/soda_scs_manager_deployment
docker compose up -d --force-recreate scs-manager--drupal
docker compose exec scs-manager--drupal drush cr
```

## Verify

```bash
curl -sL "https://${SCS_MANAGER_DOMAIN}/de/user/login" | grep -o 'href="[^"]*index\.php[^"]*"' | head
```

No output means links no longer use `index.php`. You can also inspect `drupal-settings-json` in
the page source: `currentQuery` should not contain a `q` key for normal page requests.

## Permanent fix in the image

The bind mount is a deployment workaround until `scs-manager-image` ships the same
`drupal.conf`. Once the image is updated, the mount can remain (it overrides the image file) or
be removed if the image matches.

## Related

- [Service infrastructure — SCS Manager](../service-infrastructure/index.md#scs-manager)
- Project website stack uses the same Nginx pattern:
  `scs-project-website-stack/configs/nginx/drupal.conf`
