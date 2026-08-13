# oidc-sso

## What is patched

OIDC authorization-code login on top of upstream WebProtégé (local username/password stays available unless hidden).

**New**

- `webprotege-server-core/.../auth/oidc/*` — discovery, token exchange, ID-token validation, config, user provisioning
- `webprotege-server/.../auth/oidc/OidcAuthServlet.java` — `GET /webprotege/oidc/login` and `.../callback`
- `webprotege-server/.../auth/oidc/OidcRedirectUriResolver.java`
- `webprotege-client/.../auth/ClientOidcConfig.java`
- Nimbus JOSE JWT on `webprotege-server-core/pom.xml` (`uuid` pinned to 4.x)

**Changed**

- Login GWT view/presenter: SSO link, optional hide of the password form
- `WebProtege.jsp` injects OIDC flags for the client
- `WebProtegeServletContextListener` maps the OIDC servlet
- `ApplicationModule` / `ServerComponent` expose `OidcRuntimeConfig`
- `readme.md` documents the environment variables

## New function

Users sign in with Keycloak (or any OIDC IdP). Flow:

1. Browser hits `/webprotege/oidc/login`
2. Server loads `{issuer}/.well-known/openid-configuration` and redirects to the IdP
3. Callback exchanges the code, validates the ID token, maps `preferred_username` (configurable) to a local `UserId`
4. Missing users are created with an unusable password (SSO-only; CHAP login will not work for them)

Username sanitization (same algorithm SCS Manager must use): lowercase, keep `[a-z0-9_.-]`, replace other characters with `_`, max 200 chars.

Enable with all three of `WEBPROTEGE_OIDC_ISSUER_URI`, `WEBPROTEGE_OIDC_CLIENT_ID`, `WEBPROTEGE_OIDC_CLIENT_SECRET`. Optional: `WEBPROTEGE_OIDC_HIDE_LOCAL_LOGIN=true`. If any required variable is missing, OIDC stays off.
