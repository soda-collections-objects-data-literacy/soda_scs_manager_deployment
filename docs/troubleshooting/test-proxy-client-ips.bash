#!/bin/bash

# Test Traefik reverse proxy client IP forwarding.
# Verifies that real client IPs are being forwarded correctly to backend services.
# Run from anywhere. Pass your echo service domain as argument.

DOMAIN="${1:-echo.scs.sammlungen.io}"

echo "========================================"
echo "Testing Reverse Proxy Client IP Forwarding"
echo "Domain: $DOMAIN"
echo "========================================"
echo ""

# Check network IPv6 configuration.
echo "Checking network configuration..."
echo "---"
ipv6Enabled=$(docker network inspect reverse-proxy --format '{{.EnableIPv6}}' 2>/dev/null)
if [ "$ipv6Enabled" = "true" ]; then
    echo "✓ OK: IPv6 is enabled on reverse-proxy network"
else
    echo "⚠ WARNING: IPv6 is NOT enabled on reverse-proxy network"
    echo "  This may cause issues with client IP preservation."
    echo "  Enable IPv6 in docker-compose.yml networks section:"
    echo "    networks:"
    echo "      reverse-proxy:"
    echo "        enable_ipv6: true"
fi
echo ""

echo "Testing IPv4 connection..."
echo "---"
ipv4Response=$(curl -4 -s "https://$DOMAIN" 2>&1)

if [ $? -eq 0 ]; then
    echo "Response received:"
    echo "$ipv4Response" | grep -E "(RemoteAddr|X-Forwarded-For|X-Real-Ip)"
    echo ""
    
    forwardedFor=$(echo "$ipv4Response" | grep "X-Forwarded-For:" | awk '{print $2}')
    realIp=$(echo "$ipv4Response" | grep "X-Real-Ip:" | awk '{print $2}')
    
    echo "Extracted IPs:"
    echo "  X-Forwarded-For: $forwardedFor"
    echo "  X-Real-Ip: $realIp"
    echo ""
    
    # Check if IPs are Docker internal (bad) or public (good).
    if [[ "$forwardedFor" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$forwardedFor" =~ ^10\. ]] || [[ "$forwardedFor" =~ ^192\.168\. ]]; then
        echo "✗ FAILED: X-Forwarded-For contains Docker internal IP ($forwardedFor)"
        echo "  This means real client IPs are NOT being preserved."
    else
        echo "✓ OK: X-Forwarded-For contains public IP ($forwardedFor)"
    fi
else
    echo "✗ FAILED: Could not connect to $DOMAIN"
fi

echo ""
echo "Testing IPv6 connection..."
echo "---"
ipv6Response=$(curl -6 -s "https://$DOMAIN" 2>&1)

if [ $? -eq 0 ]; then
    echo "Response received:"
    echo "$ipv6Response" | grep -E "(RemoteAddr|X-Forwarded-For|X-Real-Ip)"
    echo ""
    
    forwardedFor6=$(echo "$ipv6Response" | grep "X-Forwarded-For:" | awk '{print $2}')
    realIp6=$(echo "$ipv6Response" | grep "X-Real-Ip:" | awk '{print $2}')
    
    echo "Extracted IPs:"
    echo "  X-Forwarded-For: $forwardedFor6"
    echo "  X-Real-Ip: $realIp6"
    echo ""
    
    # Check if IPv6 looks like Docker internal (fd00::/8, fc00::/7) or public.
    if [[ "$forwardedFor6" =~ ^fd[0-9a-f]{2}: ]] || [[ "$forwardedFor6" =~ ^fc[0-9a-f]{2}: ]]; then
        echo "✗ FAILED: X-Forwarded-For contains Docker internal IPv6 ($forwardedFor6)"
        echo "  This means real client IPs are NOT being preserved."
    else
        echo "✓ OK: X-Forwarded-For contains public IPv6 ($forwardedFor6)"
    fi
else
    echo "⚠ SKIPPED: IPv6 connection not available or not configured"
fi

echo ""
echo "========================================"
echo "Test complete"
echo "========================================"
echo ""
echo "Expected behavior:"
echo "  - X-Forwarded-For should contain your real public IP address"
echo "  - X-Real-Ip should match X-Forwarded-For"
echo "  - Neither should contain Docker internal IPs (172.x.x.x, 10.x.x.x, 192.168.x.x)"
echo ""
echo "If real IPs are not being preserved, check:"
echo "  1. Traefik port bindings in docker-compose.yml"
echo "  2. Network configuration (IPv6 enabled on reverse-proxy network)"
echo "  3. No forwardedHeaders.trustedIPs configured (only needed if behind another proxy)"
echo ""
echo "See: docs/reverse-proxy-backend-config-knowledge-base.md"
