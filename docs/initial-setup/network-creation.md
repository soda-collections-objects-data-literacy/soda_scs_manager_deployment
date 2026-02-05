# Docker Network Creation for reverse-proxy

## Overview

The `reverse-proxy` Docker network is critical for the deployment. It must have **IPv6 enabled** to ensure that real client IP addresses are preserved when forwarding requests through Traefik to backend services.

## Network Configuration

The network is defined in `docker-compose.yml`:

```yaml
networks:
  reverse-proxy:
    name: reverse-proxy
    enable_ipv6: true
    driver: bridge
```

## Current Network Inspection

To inspect the current network configuration:

```bash
docker network inspect reverse-proxy
```

**Key settings to verify:**
```bash
# Check if IPv6 is enabled
docker network inspect reverse-proxy --format '{{.EnableIPv6}}'
# Should return: true

# Check IPAM configuration (subnets)
docker network inspect reverse-proxy --format '{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{"\n"}}{{end}}'
# Should show both IPv4 and IPv6 subnets
```

## Reverse Engineered Network Creation

Based on the current working network, here are the equivalent manual creation commands:

### Method 1: Manual Creation with Auto Subnets (Recommended for Manual)

Let Docker automatically assign subnets:

```bash
docker network create reverse-proxy \
  --driver bridge \
  --ipv6
```

This is simpler and allows Docker to manage subnet allocation. Docker will automatically assign appropriate subnets, ensuring each system has a unique ULA subnet.

### Method 2: Docker Compose Creation (BEST PRACTICE)

**This is the recommended approach** and what the deployment actually uses:

```bash
docker compose up -d
```

Docker Compose will:
1. Read the network definition from `docker-compose.yml`
2. Create the network if it doesn't exist
3. Update the network configuration if it exists but settings differ
4. Apply `enable_ipv6: true` automatically

## How start.sh Handles Network Creation

The `start.sh` script now creates the network with IPv6 enabled:

```bash
docker network create reverse-proxy --driver bridge --ipv6
```

**Why IPv6 is required:**
- Enables proper forwarding of real client IP addresses through Traefik
- Without IPv6, Docker may use NAT/MASQUERADE rules that replace client IPs with gateway IPs
- The combination of IPv6-enabled bridge network + standard port bindings preserves client IPs

## Troubleshooting

### Network Exists Without IPv6

If the network exists but doesn't have IPv6 enabled:

```bash
# Check current status
docker network inspect reverse-proxy --format '{{.EnableIPv6}}'

# If it returns 'false', recreate the network:
# 1. Stop all containers
docker compose down

# 2. Remove the network
docker network rm reverse-proxy

# 3. Recreate with IPv6
docker network create reverse-proxy --driver bridge --ipv6

# 4. Start services
docker compose up -d
```

### Cannot Remove Network (Containers Attached)

If you get "network has active endpoints" error:

```bash
# Stop all containers first
docker compose down

# Then remove the network
docker network rm reverse-proxy

# Recreate with IPv6
docker network create reverse-proxy --driver bridge --ipv6

# Start services
docker compose up -d
```

### Verify Network After Creation

Run the test script to verify everything works:

```bash
./docs/troubleshooting/test-proxy-client-ips.bash
```

Expected output should show:
- ✓ OK: IPv6 is enabled on reverse-proxy network
- ✓ OK: X-Forwarded-For contains public IP (not 172.x.x.x)

## Network Labels

Docker Compose adds labels to networks it manages:

```bash
docker network inspect reverse-proxy --format '{{.Labels}}'
```

You should see labels like:
- `com.docker.compose.network=reverse-proxy`
- `com.docker.compose.project=soda_scs_manager_deployment`
- `com.docker.compose.version=X.X.X`

These labels indicate the network is managed by Docker Compose.

## IPAM (IP Address Management) Configuration

The network uses Docker's default IPAM driver with two subnet configurations:

1. **IPv4 Subnet**: `172.21.0.0/16` (65,536 addresses)
   - Gateway: `172.21.0.1`
   - Used for internal container-to-container communication

2. **IPv6 Subnet**: Auto-assigned ULA subnet (e.g., `fdXX:XXXX:XXXX:XXXX::/64`)
   - Gateway: Auto-assigned (typically `::1` in the subnet)
   - Used for IPv6 connectivity and client IP preservation
   - Docker automatically assigns a unique subnet per system

Each container attached to the network gets both an IPv4 and IPv6 address.

## Related Documentation

- [Reverse Proxy Backend Config](../reverse-proxy-backend-config-knowledge-base.md) - How the network enables client IP forwarding
- [Troubleshooting](../troubleshooting/index.md) - Network verification and testing
- [Pre-start Steps](pre-start-steps.md) - Complete setup process including network creation
