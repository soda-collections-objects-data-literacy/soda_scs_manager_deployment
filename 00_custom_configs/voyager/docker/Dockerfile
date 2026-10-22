# Smithsonian DPO Voyager (3D viewer), built from the voyager/ submodule.
# Build context: ${SCS_ROOT_PATH}/voyager (see docker-compose.override.yml).

ARG NODE_VERSION=22
ARG NGINX_VERSION=1.30

FROM node:${NODE_VERSION}-bookworm-slim AS build

# Public base URL of this service (trailing slash). Replaces the jsDelivr
# @latest default for fonts, Draco and Basis decoders, so embeds stay
# self-hosted without a resourceRoot attribute.
ARG VOYAGER_ASSET_URL

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

# Self-host system assets and drop the hard-coded Google Analytics tag
# (only rendered when VOYAGER_ANALYTICS_ID is set).
RUN set -eu; \
    test -n "${VOYAGER_ASSET_URL}"; \
    reader=source/client/components/CVAssetReader.ts; \
    grep -q 'https://cdn.jsdelivr.net/gh/smithsonian/dpo-voyager@latest/assets/' "$reader"; \
    sed -i "s#https://cdn.jsdelivr.net/gh/smithsonian/dpo-voyager@latest/assets/#${VOYAGER_ASSET_URL}#" "$reader"; \
    grep -q '{{#unless htmlWebpackPlugin.options.isDevelopment}}' source/client/explorer.hbs; \
    sed -i \
      -e 's#{{\#unless htmlWebpackPlugin.options.isDevelopment}}#{{\#if htmlWebpackPlugin.options.analyticsId}}#' \
      -e 's#{{/unless}}#{{/if}}#' \
      source/client/explorer.hbs

ENV NODE_OPTIONS=--max-old-space-size=4096 \
    VOYAGER_OFFLINE=true
RUN cd source/client && npx webpack --mode=production --env=app=all \
 && cd /app/dist && for f in *-offline.html; do mv "$f" "${f%-offline.html}.html"; done

FROM nginx:${NGINX_VERSION}-alpine

COPY --from=build /app/dist /usr/share/nginx/html
RUN mkdir -p /usr/share/nginx/html/files
