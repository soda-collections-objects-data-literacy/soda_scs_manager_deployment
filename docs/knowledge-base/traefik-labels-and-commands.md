# Traefik labels and command reference (wisdom base)
## How Traefik labels work
Traefik’s Docker provider reads container labels. Any label whose key starts with `traefik.` is treated as Traefik configuration. Labels are the main way to define routers, services, and middlewares per container without editing Traefik’s own config files. Traefik discovers running containers (on the same Docker host) and builds its dynamic configuration from these labels.
## Label notation (dot-separated hierarchy)
Labels use a dot-separated path: `traefik.<scope>.<resource-type>.<resource-name>.<property>[.<subproperty>]=<value>`. Each segment has a fixed meaning: the first is always the `traefik` prefix, then protocol/scope, then the kind of resource (routers, services, middlewares), then a unique name, then the option and optional sub-options. Example: `traefik.http.routers.scs--phpmyadmin.rule=Host(...)` sets the `rule` property of the HTTP router named `scs--phpmyadmin`.
## Meaning of the single terms (example: `traefik.http.routers.scs--phpmyadmin.rule=Host(...)`)
**traefik** — Label namespace. Only labels starting with `traefik.` are read by Traefik’s Docker provider; other labels are ignored.
**http** — Protocol scope. Options are `http` (HTTP/HTTPS, layer 7) or `tcp` (raw TCP, e.g. MySQL). Determines whether the router/service is for HTTP rules (Host, Path, etc.) or TCP (e.g. HostSNI).
**routers** — Resource type: a router. A router matches incoming requests (by rule and entrypoint) and sends them to a service. You define routers with `traefik.http.routers.<name>.*` or `traefik.tcp.routers.<name>.*`.
**scs--phpmyadmin** — Router name. Must be unique in the same protocol. Often matches the service/container name (e.g. `scs--phpmyadmin`). All labels that share this name configure the same router.
**rule** — Router property: the matching rule. For HTTP, common forms are `Host(`domain`)`, `Path(`path`)`, or combined (e.g. `Host(...) && Path(...)`). For TCP you use e.g. `HostSNI(`domain`)`. The request must match the rule for this router to be chosen.
## Other label terms used in this stack
**traefik.enable** — Top-level: `true` or `false`. If `false`, Traefik ignores all other Traefik labels on that container (e.g. `scs--access-proxy`).
**traefik.docker.network** — Top-level: the Docker network name Traefik must use to reach this container (e.g. `reverse-proxy`). Required when the container is on multiple networks so Traefik knows which IP to use.
**traefik.http.services.<name>** — Defines an HTTP service (backend). The name is the service name; routers reference it with `traefik.http.routers.<router>.service=<name>`.
**traefik.http.services.<name>.loadbalancer.server.port** — Backend port inside the container (e.g. `80` for phpMyAdmin). Traefik forwards to this port.
**traefik.http.routers.<name>.entrypoints** — Comma-separated list of entrypoints (e.g. `web`, `websecure`). The router only applies to requests that arrive on these entrypoints.
**traefik.http.routers.<name>.middlewares** — Comma-separated list of middleware names (e.g. `rate-limit`). Applied in order before forwarding to the service.
**traefik.http.routers.<name>.tls** — Enable TLS for this router (`true`/`false`).
**traefik.http.routers.<name>.tls.certresolver** — Name of the certificate resolver (e.g. `le` for Let’s Encrypt) used to get the certificate.
**traefik.http.routers.<name>.service** — Links the router to the service name. If omitted, Traefik often infers it from the container/service name, but setting it explicitly is clearer (e.g. when one service has multiple routers).
**traefik.http.middlewares.<name>.*** — Defines a middleware (e.g. `basicauth`, `redirectscheme`, `headers`, `ratelimit`). Routers reference them in `traefik.http.routers.<name>.middlewares`.
**traefik.tcp.routers / traefik.tcp.services** — Same idea as HTTP but for TCP: e.g. `traefik.tcp.routers.scs--database.rule=HostSNI(...)`, `traefik.tcp.services.scs--database.loadbalancer.server.port=3306`.
## Other ways to configure Traefik
**Static configuration file (YAML/TOML)** — You can define entrypoints, certificates resolvers, and the Docker provider in a static file (e.g. `traefik.yml`) and use `--configFile=traefik.yml`. Routers/services can still come from Docker labels (dynamic config).
**Dynamic configuration files** — You can point Traefik at YAML/JSON files (or a directory) for routers, services, middlewares instead of (or in addition to) Docker labels, via the file provider.
**CLI flags** — Everything in the `command` section could be moved into a static config file; CLI and config file are equivalent for static options.
**Kubernetes IngressRoute CRDs** — If running on Kubernetes, you use IngressRoute and related CRDs instead of Docker labels.
## Command section (Traefik process arguments)
The `command` block under `scs--reverse-proxy` is the list of arguments passed to the Traefik process. Each list item is one flag. Below, “section” refers to the logical part of Traefik config (providers, entrypoints, etc.).
**--providers.docker** — Enables the Docker provider so Traefik discovers containers and reads their `traefik.*` labels.
**--providers.docker.exposedbydefault=false** — Containers are not exposed by default; only containers that have Traefik labels (and typically `traefik.enable=true`) get a router/service.
**--entrypoints.web.address=:80** — Defines the entrypoint named `web` listening on port 80 (HTTP). Labels use this name in `traefik.http.routers.<name>.entrypoints=web,...`.
**--entrypoints.websecure.address=:443** — Defines the entrypoint `websecure` on port 443 (HTTPS).
**--entrypoints.web.forwardedHeaders.trustedIPs=172.18.0.0/16** — (ONLY NEEDED IF TRAEFIK IS BEHIND ANOTHER PROXY) Trust `X-Forwarded-*` headers only from this CIDR. When Traefik is the edge proxy (first contact with clients), it automatically creates X-Forwarded-* headers from the real connection and this setting is not needed. Only use this if Traefik itself is behind another proxy (e.g., CloudFlare, AWS ALB).
**--entrypoints.websecure.forwardedHeaders.trustedIPs=172.18.0.0/16** — Same as above for the HTTPS entrypoint.
**--entrypoints.mysql.address=:3306** — TCP entrypoint `mysql` on port 3306 for MySQL. Used by `traefik.tcp.routers.scs--database.entrypoints=mysql`.
**--certificatesresolvers.le.acme.email=...** — Email used for Let’s Encrypt (ACME) account and expiry notifications.
**--certificatesresolvers.le.acme.httpchallenge.entrypoint=web** — Use the `web` entrypoint (port 80) for HTTP-01 challenges. Do not enable `tlschallenge` on the same resolver: Traefik then skips HTTP-01 while `allowACMEByPass` still expects it, which produces `HTTP challenge is not enabled` / missing resolver `le` symptoms. For TLS-ALPN-01 only (port 443), omit `httpchallenge` and `allowACMEByPass` instead.
**--certificatesresolvers.le.acme.storage=/certificates/acme.json** — Path inside the container where ACME state and certificates are stored. This stack uses the named volume `scs--reverse-proxy-certificates` mounted at `/certificates` so `acme.json` is created with mode 600.
**--accesslog** — Enable access logging (each request logged).
**--log** — Enable general application logging.
**--api** — Enable the Traefik API (used by the dashboard and health checks).
**--api.dashboard=true** — Serve the built-in dashboard UI; it is then exposed via the router that has `service=api@internal` (and optional auth middleware).
## Summary
Labels: `traefik` = namespace, `http`/`tcp` = protocol, `routers`/`services`/`middlewares` = resource type, next segment = resource name, then property and value. The `rule` is the condition that selects the router; entrypoints, middlewares, TLS and service link define how and where the request is handled. The `command` section configures the Traefik process (providers, entrypoints, certificate resolver, logging, API) and is equivalent to static config; the actual routes and backends come from Docker labels in this setup.
