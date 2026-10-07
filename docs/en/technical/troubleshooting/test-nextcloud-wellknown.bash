#!/bin/bash

# Test Nextcloud .well-known URLs
# Run from anywhere. Pass your Nextcloud domain as argument.

DOMAIN="${1:-drive.scs.localhost}"

echo "========================================"
echo "Testing Nextcloud .well-known URLs"
echo "Domain: $DOMAIN"
echo "========================================"
echo ""

test_url() {
    local url="$1"
    local name="$2"
    
    echo "Testing: $name"
    echo "URL: $url"
    
    response=$(curl -sI "$url" 2>&1)
    status=$(echo "$response" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
    location=$(echo "$response" | grep -i "^Location:" | cut -d' ' -f2 | tr -d '\r')
    
    if [ -n "$status" ]; then
        echo "Status: $status"
        if [ -n "$location" ]; then
            echo "Location: $location"
        fi
        
        if [ "$status" = "301" ] || [ "$status" = "302" ] || [ "$status" = "200" ]; then
            echo "✓ OK"
        else
            echo "✗ FAILED"
        fi
    else
        echo "✗ No response (check if server is reachable)"
    fi
    
    echo ""
}

test_url "https://$DOMAIN/.well-known/webfinger" "Webfinger"
test_url "https://$DOMAIN/.well-known/nodeinfo" "Nodeinfo"
test_url "https://$DOMAIN/.well-known/carddav" "CardDAV"
test_url "https://$DOMAIN/.well-known/caldav" "CalDAV"

echo "========================================"
echo "Test complete"
echo "========================================"
echo ""
echo "All .well-known URLs should return 301/302 or 200 status."
echo "Check Nextcloud admin panel: Settings → Administration → Overview"
echo "The .well-known warning should disappear after nginx restart."
