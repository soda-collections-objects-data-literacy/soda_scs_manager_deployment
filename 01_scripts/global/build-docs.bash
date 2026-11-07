#!/usr/bin/env bash
# Build DE + EN Zensical documentation into ./site (served by core--docs--app).
# German overlays in docs/de/ win over English docs/en/ for the DE site.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

SITE_DIR="${ROOT_DIR}/site"
DE_BUILD_DIR="${ROOT_DIR}/.docs-build/de"

echo "Preparing German docs tree (en base + de overlays) …"
rm -rf "${DE_BUILD_DIR}"
mkdir -p "${DE_BUILD_DIR}"
rsync -a "${ROOT_DIR}/docs/en/" "${DE_BUILD_DIR}/"
rsync -a "${ROOT_DIR}/docs/de/" "${DE_BUILD_DIR}/"

echo "Cleaning ${SITE_DIR} …"
if [[ -d "${SITE_DIR}" ]]; then
  if rm -rf "${SITE_DIR}" 2>/dev/null; then
    :
  else
    docker run --rm -v "${ROOT_DIR}:/docs" alpine:3.20 rm -rf /docs/site
  fi
fi
mkdir -p "${SITE_DIR}"

echo "Building English → site/en …"
docker run --rm -v "${ROOT_DIR}:/docs" zensical/zensical build -f zensical.en.toml

echo "Building German → site/de …"
docker run --rm -v "${ROOT_DIR}:/docs" zensical/zensical build -f zensical.de.toml

# Language chooser / Accept-Language redirect at site root.
cat > "${SITE_DIR}/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SODa SCS Docs</title>
  <script>
    (function () {
      var langs = (navigator.languages || [navigator.language || "de"]).map(function (l) {
        return String(l).toLowerCase();
      });
      var preferDe = langs.some(function (l) { return l === "de" || l.indexOf("de-") === 0; });
      var target = preferDe ? "/de/" : "/en/";
      location.replace(target);
    })();
  </script>
  <noscript>
    <meta http-equiv="refresh" content="0; url=/de/">
  </noscript>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 32rem; margin: 3rem auto; padding: 0 1rem; }
    a { margin-right: 1rem; }
  </style>
</head>
<body>
  <p>SODa SCS documentation / Dokumentation</p>
  <p><a href="/de/">Deutsch</a> <a href="/en/">English</a></p>
</body>
</html>
EOF

if [[ ! -f "${SITE_DIR}/en/index.html" || ! -f "${SITE_DIR}/de/index.html" ]]; then
  echo "error: site/en/index.html or site/de/index.html missing after build" >&2
  exit 1
fi

echo "Done. Recreate the docs container to pick up changes:"
echo "  docker compose up -d --force-recreate core--docs--app"

# Zensical runs as root in Docker; fix ownership for the next local clean.
if [[ -d "${SITE_DIR}" ]]; then
  docker run --rm -v "${ROOT_DIR}:/docs" alpine:3.20 \
    chown -R "$(id -u):$(id -g)" /docs/site /docs/.docs-build 2>/dev/null || true
fi
