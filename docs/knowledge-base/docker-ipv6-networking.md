# Docker IPv6 Networking: Key Concepts and Configuration

## Overview

This document explains the key concepts behind IPv6 networking in Docker, specifically focusing on the `reverse-proxy` network configuration. Understanding these concepts helps you make informed decisions about network configuration and troubleshooting.

## Table of Contents

1. [IPAM (IP Address Management)](#ipam-ip-address-management)
2. [ULA (Unique Local Address)](#ula-unique-local-address)
3. [Gateway](#gateway)
4. [IPv6 Subnetting (/64)](#ipv6-subnetting-64)
5. [Why Specific Subnets Are Chosen](#why-specific-subnets-are-chosen)
6. [Network Configuration in docker-compose.yml](#network-configuration-in-docker-composeyml)

---

## IPAM (IP Address Management)

### What is IPAM?

**IPAM** stands for **IP Address Management**. It's Docker's system for managing IP addresses in networks.

### What IPAM Does

IPAM handles:
- **Subnet assignment** (both IPv4 and IPv6)
- **Gateway configuration**
- **IP address allocation** to containers
- **Address range management**

### IPAM in docker-compose.yml

In `docker-compose.yml`, the `ipam` block defines which subnets and gateways the network should use. Without explicit configuration, Docker automatically selects appropriate values.

**Note:** In this deployment, we use auto-assignment (no explicit IPAM configuration), allowing Docker to automatically assign appropriate subnets. This is the recommended approach for portability across different systems.

---

## ULA (Unique Local Address)

### What is ULA?

**ULA** stands for **Unique Local Address**. These are IPv6 addresses for local networks, similar to private IPv4 addresses (like `192.168.x.x` or `10.x.x.x`).

### ULA Characteristics

- **Prefix**: `fd00::/8` (or `fc00::/8` for future use)
- **Not routable** on the public Internet
- **Unique** through a random 40-bit Global ID
- **Format**: `fdXX:XXXX:XXXX:XXXX::/64`

### Examples

- `fd5e:e17b:ef02:1::/64` is a ULA subnet
- `fd00:dead:beef::1` is a ULA address

### Why Use ULA for Docker?

- **No conflicts** with public IPv6 addresses
- **Huge address space** (2^64 addresses per subnet)
- **Automatic assignment** by Docker
- **Security**: Containers are not directly reachable from the Internet

### ULA vs. Public IPv6

| Type | Example | Routable | Use Case |
|------|---------|----------|----------|
| Public IPv6 | `2a01:4f9:3081:3204::2` | Yes | Internet-facing services |
| ULA | `fd5e:e17b:ef02:1::1` | No (local only) | Internal container communication |

---

## Gateway

### What is a Gateway?

A **gateway** is the address containers use to leave the network and communicate with other networks. It's the interface between the container network and the host system.

### How Gateways Work in Docker Networks

When Docker creates a bridge network:
1. It creates a virtual network interface on the host
2. Assigns a gateway address to this interface
3. All containers in the network use this address as their default route

### Gateway Address Format

For the subnet `fd5e:e17b:ef02:1::/64`:
- `fd5e:e17b:ef02:1::/64` = Subnet (first 64 bits)
- `::1` = The first address in the subnet (gateway)
- `fd5e:e17b:ef02:1::1` = Gateway address

### How Traffic Flows

```
Container (e.g., fd5e:e17b:ef02:1::2)
    ↓
    | wants to reach Internet or other networks
    ↓
Gateway: fd5e:e17b:ef02:1::1
    ↓
    | forwards traffic
    ↓
Host System (your Linux server)
    ↓
    | routes to Internet or other networks
```

### Why the First Address (`::1`)?

- **Convention**: The first address in a subnet is typically the gateway
- **IPv4 equivalent**: `172.21.0.1` is the gateway for `172.21.0.0/16`
- **IPv6 equivalent**: `fd5e:e17b:ef02:1::1` is the gateway for `fd5e:e17b:ef02:1::/64`

---

## IPv6 Subnetting (/64)

### What is a /64 Subnet?

A `/64` subnet provides:
- **64 bits** for the network prefix (left side)
- **64 bits** for host addresses (right side)

### Address Capacity

**2^64 = 18,446,744,073,709,551,616 addresses**

That's approximately **18.4 quintillion addresses**.

### Practically Usable Addresses

Some addresses are reserved:
- `fd5e:e17b:ef02:1::` - Subnet router anycast (reserved)
- `fd5e:e17b:ef02:1::1` - Gateway (used, but counts as host address)

**Practically usable**: Approximately 2^64 - 1 addresses (still ~18.4 quintillion).

### Comparison with IPv4

| Subnet | Addresses | Usable |
|--------|-----------|--------|
| IPv4 `/24` | 256 | 254 |
| IPv4 `/16` | 65,536 | 65,534 |
| IPv6 `/64` | 18,446,744,073,709,551,616 | ~18.4 quintillion |

### Why /64 for Docker Containers?

Even with millions of containers, the address space is more than sufficient. A `/64` subnet is standard for Docker networks and provides more than enough addresses.

### Why /64 is Standard

- **Standard size** for IPv6 subnets
- **Supports SLAAC** (Stateless Address Autoconfiguration)
- **More than sufficient** for practically all use cases
- **Easy to manage**

---

## Why Specific Subnets Are Chosen

### Current Configuration

The `reverse-proxy` network uses:
- **Subnet**: `fd5e:e17b:ef02:1::/64`
- **Gateway**: `fd5e:e17b:ef02:1::1`

### Why This Subnet?

Docker chose `fd5e:e17b:ef02:1::/64` because:
1. **Already exists on the host** (`fd5e:e17b:ef02:1::1/64`)
2. **It's a `/64` subnet** (standard for Docker networks)
3. **Docker tries to use existing networks** to avoid conflicts

### Default Docker Network

The default Docker bridge network (`bridge`) uses:
- **Subnet**: `fd00:dead:beef::/48` (configured in `/etc/docker/daemon.json`)
- **Gateway**: `fd00:dead:beef::1`
- **Interface**: `docker0` on the host

### Why Two Different Subnets?

- `fd00:dead:beef::/48` = Default Docker network (for containers without explicit network)
- Auto-assigned `/64` subnet = Your custom `reverse-proxy` network (e.g., `fdXX:XXXX:XXXX:XXXX::/64`)

Docker automatically assigns a unique `/64` subnet for the `reverse-proxy` network, separate from the default bridge network.

### Why /48 Instead of /64 for Default Network?

A `/48` subnet contains many `/64` subnets:
- `/48` = 65,536 possible `/64` subnets
- Docker can automatically create `/64` subnets for new networks from this pool
- This allows Docker to assign unique subnets to each custom network

---

## Network Configuration in docker-compose.yml

### Recommended Configuration

```yaml
networks:
  reverse-proxy:
    name: reverse-proxy
    enable_ipv6: true
    driver: bridge
```

**Why use auto-assignment?**
- **Simple**: No need to specify subnets manually
- **Automatic**: Docker assigns appropriate ULA subnets based on the host system
- **No conflicts**: Each system gets its own unique subnet
- **Portable**: Works on any system without modification
- **Best practice**: Avoids subnet conflicts when deploying to different systems

Docker will automatically assign an appropriate ULA subnet (e.g., `fdXX:XXXX:XXXX:XXXX::/64`) based on the host system's configuration. This ensures each deployment has a unique subnet, preventing conflicts if networks are later connected.

### Why `enable_ipv6: true` is Required

For the `reverse-proxy` network, IPv6 is **critical** because:
- **Preserves real client IP addresses** when forwarding requests through Traefik
- Without IPv6, Docker may use NAT/MASQUERADE rules that replace client IPs with gateway IPs
- The combination of IPv6-enabled bridge network + standard port bindings preserves client IPs

### Verifying Network Configuration

```bash
# Check if IPv6 is enabled
docker network inspect reverse-proxy --format '{{.EnableIPv6}}'
# Should return: true

# Check IPAM configuration (subnets)
docker network inspect reverse-proxy --format '{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{"\n"}}{{end}}'
# Should show both IPv4 and IPv6 subnets
```

---

## Summary

### Key Takeaways

1. **IPAM** manages IP address allocation in Docker networks
2. **ULA** addresses (`fd00::/8`) are private IPv6 addresses for local networks
3. **Gateway** (`::1`) is the exit point for containers to reach other networks
4. **/64 subnets** provide 18.4 quintillion addresses (more than sufficient)
5. **Auto-assignment** is recommended for portability across different systems
6. **IPv6 is required** for the reverse-proxy network to preserve client IPs

### Network Comparison

| Network | Subnet Assignment | Purpose |
|---------|-------------------|---------|
| Default (`bridge`) | Auto-assigned (e.g., `fd00:dead:beef::/48`) | Default Docker network |
| `reverse-proxy` | Auto-assigned (e.g., `fdXX:XXXX:XXXX:XXXX::/64`) | Custom reverse proxy network |

**Note:** Subnets are automatically assigned by Docker and will differ per system. This ensures each deployment has unique subnets, preventing conflicts.

### Related Documentation

- [Network Creation Guide](../initial-setup/network-creation.md) - Detailed network setup instructions
- [Reverse Proxy Backend Config](../reverse-proxy-backend-config-knowledge-base.md) - How the network enables client IP forwarding
- [Troubleshooting](../troubleshooting/index.md) - Network verification and testing

---

## Glossary

- **IPAM**: IP Address Management - Docker's system for managing IP addresses
- **ULA**: Unique Local Address - Private IPv6 addresses (fd00::/8)
- **Gateway**: The network exit point (typically `::1` in a subnet)
- **/64**: Standard IPv6 subnet size (2^64 addresses)
- **/48**: Larger IPv6 subnet containing 65,536 /64 subnets
- **Bridge**: Docker network driver that creates a virtual network interface
- **SLAAC**: Stateless Address Autoconfiguration - IPv6 address auto-configuration
