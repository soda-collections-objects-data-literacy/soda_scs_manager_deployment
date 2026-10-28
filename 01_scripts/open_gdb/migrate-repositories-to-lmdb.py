#!/usr/bin/env python3
"""Move RDF4J repositories to the LMDB store, one repository at a time.

RDF4J can't change the store of a repository in place. For each repository this script exports
all statements (N-Quads) and namespaces to the dump directory, recreates the repository with the
LMDB config authproxy uses for new repositories, imports the dump and compares a fingerprint of
the content before and after. It stops at the first mismatch; the dump of that repository stays
in the dump directory for a manual restore.

Stop authproxy first, so no client writes during the export. The script only talks to RDF4J;
afterwards set authproxy's stored turtle_template of the migrated repositories to
Repository.DEFAULT_TEMPLATE with a queryset update (save() would trigger the RDF4J signals).

Usage (from a container that reaches RDF4J, standard library only):
    migrate-repositories-to-lmdb.py --base-url http://localhost:8080/rdf4j-server \
        --dump-dir /dumps [--dry-run] (--all | REPOSITORY_ID ...)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

LMDB_SAIL_TYPE = "rdf4j:LmdbStore"
TRIPLE_INDEXES = "spoc,posc,ospc"
REQUEST_TIMEOUT_SECONDS = 300

# Same as authproxy's Repository.DEFAULT_TEMPLATE, so the stored template matches the live config.
# The triple indexes must use the lmdb# namespace: without them, RDF4J 6.0 and 6.1 can't reopen
# the store after a restart.
LMDB_CONFIG_TEMPLATE = """@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix config: <tag:rdf4j.org,2023:config/>.
@prefix lmdb: <http://rdf4j.org/config/sail/lmdb#>.
[] a config:Repository ;
config:rep.id "{repository_id}" ;
rdfs:label "{label}" ;
config:rep.impl [
    config:rep.type "openrdf:SailRepository" ;
    config:sail.impl [
        config:sail.type "rdf4j:LmdbStore" ;
        lmdb:tripleIndexes "{indexes}"
    ]
]."""


class MigrationError(RuntimeError):
    """A repository could not be migrated safely."""


@dataclass(frozen=True)
class Fingerprint:
    """Content summary that survives blank node relabelling."""

    statement_count: int
    ground_digest: str
    blank_node_statement_count: int


class Rdf4jClient:
    """Minimal RDF4J REST client."""

    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")

    def request(
        self,
        method: str,
        path: str,
        *,
        body: bytes | None = None,
        content_type: str | None = None,
        accept: str | None = None,
    ) -> bytes:
        headers = {}
        if content_type:
            headers["Content-Type"] = content_type
        if accept:
            headers["Accept"] = accept
        request = urllib.request.Request(
            f"{self.base_url}{path}", data=body, method=method, headers=headers
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:300]
            raise MigrationError(f"{method} {path}: HTTP {error.code}: {detail}") from error

    def repositories(self) -> dict[str, str]:
        """Repository IDs with their labels."""
        payload = json.loads(
            self.request("GET", "/repositories", accept="application/sparql-results+json")
        )
        return {
            binding["id"]["value"]: binding.get("title", {}).get("value", "")
            for binding in payload["results"]["bindings"]
        }

    def config_values(self, repository_id: str, *predicate_names: str) -> list[str]:
        """Literal values of the stored repository config whose predicate ends with a name."""
        config = self.request(
            "GET", f"/repositories/{repository_id}/config", accept="text/turtle"
        ).decode("utf-8")
        return [
            line.split('"')[1]
            for line in config.splitlines()
            if '"' in line and any(name in line for name in predicate_names)
        ]

    def sail_types(self, repository_id: str) -> list[str]:
        return self.config_values(repository_id, "sail.type", "sailType")

    def triple_indexes(self, repository_id: str) -> list[str]:
        return self.config_values(repository_id, "tripleIndexes")

    def export_statements(self, repository_id: str) -> bytes:
        return self.request(
            "GET",
            f"/repositories/{repository_id}/statements?infer=false",
            accept="application/n-quads",
        )

    def export_namespaces(self, repository_id: str) -> dict[str, str]:
        payload = json.loads(
            self.request(
                "GET",
                f"/repositories/{repository_id}/namespaces",
                accept="application/sparql-results+json",
            )
        )
        return {
            binding["prefix"]["value"]: binding["namespace"]["value"]
            for binding in payload["results"]["bindings"]
        }

    def size(self, repository_id: str) -> int:
        return int(self.request("GET", f"/repositories/{repository_id}/size"))

    def recreate_as_lmdb(self, repository_id: str, label: str) -> None:
        config = LMDB_CONFIG_TEMPLATE.format(
            repository_id=repository_id,
            label=label.replace("\\", "\\\\").replace('"', '\\"'),
            indexes=TRIPLE_INDEXES,
        )
        self.request("DELETE", f"/repositories/{repository_id}")
        self.request(
            "PUT",
            f"/repositories/{repository_id}",
            body=config.encode("utf-8"),
            content_type="text/turtle",
        )

    def import_dump(
        self, repository_id: str, statements: bytes, namespaces: dict[str, str]
    ) -> None:
        if statements.strip():
            self.request(
                "POST",
                f"/repositories/{repository_id}/statements",
                body=statements,
                content_type="application/n-quads",
            )
        for prefix, namespace in namespaces.items():
            self.request(
                "PUT",
                f"/repositories/{repository_id}/namespaces/{urllib.parse.quote(prefix)}",
                body=namespace.encode("utf-8"),
                content_type="text/plain",
            )


def fingerprint(statements: bytes) -> Fingerprint:
    """Fingerprint of an N-Quads dump; blank node labels differ between exports."""
    lines = [line for line in statements.decode("utf-8").splitlines() if line.strip()]
    ground = sorted(line for line in lines if "_:" not in line)
    digest = hashlib.sha256("\n".join(ground).encode("utf-8")).hexdigest()
    return Fingerprint(len(lines), digest, len(lines) - len(ground))


def migrate(
    client: Rdf4jClient, repository_id: str, label: str, dump_dir: Path, dry_run: bool
) -> str:
    if LMDB_SAIL_TYPE in client.sail_types(repository_id) and client.triple_indexes(
        repository_id
    ) == [TRIPLE_INDEXES]:
        return "already LMDB, skipped"

    statements = client.export_statements(repository_id)
    namespaces = client.export_namespaces(repository_id)
    (dump_dir / f"{repository_id}.nq").write_bytes(statements)
    (dump_dir / f"{repository_id}.namespaces.json").write_text(json.dumps(namespaces, indent=2))

    before = fingerprint(statements)
    if before.statement_count != client.size(repository_id):
        raise MigrationError(f"{repository_id}: export is incomplete, repository left unchanged")
    if dry_run:
        return f"would migrate {before.statement_count} statements, {len(namespaces)} namespaces"

    restore_hint = f"restore from {dump_dir / repository_id}.nq and .namespaces.json"
    try:
        client.recreate_as_lmdb(repository_id, label)
        if client.triple_indexes(repository_id) != [TRIPLE_INDEXES]:
            raise MigrationError("RDF4J did not take the triple indexes from the config")
        client.import_dump(repository_id, statements, namespaces)
    except MigrationError as error:
        raise MigrationError(f"{repository_id}: {error}; {restore_hint}") from error

    after = fingerprint(client.export_statements(repository_id))
    if after != before or client.export_namespaces(repository_id) != namespaces:
        raise MigrationError(
            f"{repository_id}: content differs after import (before {before}, after {after}); "
            f"{restore_hint}"
        )
    return f"migrated {after.statement_count} statements, {len(namespaces)} namespaces"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base-url", required=True, help="e.g. http://localhost:8080/rdf4j-server")
    parser.add_argument("--dump-dir", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true", help="Only export and check.")
    parser.add_argument("--all", action="store_true", help="Migrate every repository.")
    parser.add_argument("repository_ids", nargs="*")
    arguments = parser.parse_args()
    if arguments.all == bool(arguments.repository_ids):
        parser.error("name repositories or use --all")

    client = Rdf4jClient(arguments.base_url)
    labels = client.repositories()
    repository_ids = sorted(labels) if arguments.all else arguments.repository_ids
    unknown = [repository_id for repository_id in repository_ids if repository_id not in labels]
    if unknown:
        parser.error(f"unknown repositories: {', '.join(unknown)}")

    arguments.dump_dir.mkdir(parents=True, exist_ok=True)
    for repository_id in repository_ids:
        try:
            outcome = migrate(
                client, repository_id, labels[repository_id], arguments.dump_dir, arguments.dry_run
            )
        except MigrationError as error:
            print(f"FAILED {error}", file=sys.stderr)
            return 1
        print(f"{repository_id}: {outcome}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
