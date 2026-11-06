# OpenGDB

<figure class="scs-figure">
  <img src="../../assets/images/apps/opengdb.svg" alt="Logo of the Open GDB triplestore.">
</figure>

## Overview

OpenGDB is an RDF4J-based triplestore that extends the standard RDF4J server with comprehensive user management and security features. The system builds upon RDF4J's core functionality by adding a Django-based authentication layer, repository management capabilities, and network security controls through a specialized proxy that prevents internal network access via SPARQL queries. The entire solution is packaged for deployment using Docker containers.

## Possibilities

OpenGDB enables multi-user RDF storage where you can store and query RDF data using standard SPARQL while managing multiple repositories with granular per-repository access controls. Users authenticate through either a web interface or API tokens, providing flexibility for both interactive and programmatic access.

The platform provides comprehensive repository management functionality, allowing administrators to create and configure RDF repositories while setting specific user permissions for repository access. All management operations are accessible through REST API endpoints, enabling programmatic administration and integration with existing systems.

Security is a core focus, with the system blocking SPARQL SERVICE queries from accessing localhost or internal networks - addressing a common vulnerability in triplestore deployments. Performance is optimized through token-based authentication, which significantly improves API response times compared to traditional session-based authentication. User sessions and permissions are managed through Django's admin interface.

API access follows industry standards, providing GraphDB-compatible REST endpoints at /rest/security/users and /rest/repositories/ while maintaining full support for standard RDF4J protocols. Authentication can be handled through either basic authentication or token-based methods depending on performance requirements.

## Links

- [Repository of the OpenGDB](https://github.com/FAU-CDI/open_gdb)
- [Website of the RDF4J triplestore](https://rdf4j.org/)
