# docker-build

## What is patched

`Dockerfile` only (vs protegeproject/webprotege).

| Upstream | This patch |
|----------|------------|
| `maven:3.6.0-jdk-11-slim`, installs git + MongoDB in the build image | `maven:3.8.6-eclipse-temurin-11`, no MongoDB in the build image |
| Starts `mongod` during `mvn clean package` so tests can run | `mvn -B -Dmaven.test.skip=true clean package` (does not compile or run tests) |
| `WEBPROTEGE_VERSION` must be passed as a build-hook arg | Default `5.0.0-SNAPSHOT`, overridable from Compose |

MongoDB remains a **separate** compose service (`webprotege-mongodb` / `wpmongo`).

## New function

The SCS image (`webprotege:scs`) builds without a database in the Maven stage. Tests belong in CI or a local Maven run, not in every `docker compose build`.

`-DskipTests` is not enough: Maven still runs `testCompile`. That is why this patch uses `-Dmaven.test.skip=true`.
