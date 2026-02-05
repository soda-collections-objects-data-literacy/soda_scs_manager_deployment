# Knowledge Base

This directory contains detailed explanations of key concepts, technologies, and configurations used in the SCS Manager deployment.

## Available Documents

### [Docker IPv6 Networking](./docker-ipv6-networking.md)

Comprehensive guide covering:
- **IPAM** (IP Address Management) - How Docker manages IP addresses
- **ULA** (Unique Local Address) - Private IPv6 addresses for local networks
- **Gateway** - Network exit points and routing
- **IPv6 Subnetting** - Understanding /64 and /48 subnets
- **Subnet Selection** - Why specific subnets are chosen
- **Network Configuration** - How to configure networks in docker-compose.yml

Essential reading for understanding the `reverse-proxy` network configuration and IPv6 networking in Docker.

---

## Related Documentation

- [Network Creation Guide](../initial-setup/network-creation.md) - Step-by-step network setup
- [Reverse Proxy Backend Config](../reverse-proxy-backend-config-knowledge-base.md) - Client IP forwarding
- [Troubleshooting](../troubleshooting/index.md) - Network verification and testing
