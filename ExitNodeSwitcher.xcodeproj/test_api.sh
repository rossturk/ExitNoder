#!/bin/bash

# Test script to verify Tailscale Local API is accessible

echo "Testing Tailscale Local API connectivity..."
echo ""

# Test status endpoint
echo "1. Testing GET /localapi/v0/status"
STATUS=$(curl -s http://localhost:41641/localapi/v0/status 2>&1)

if [ $? -eq 0 ]; then
    echo "   ✅ Successfully connected to Tailscale Local API"
    echo "   Response length: ${#STATUS} bytes"
    
    # Try to parse and show some basic info
    VERSION=$(echo "$STATUS" | grep -o '"Version":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$VERSION" ]; then
        echo "   Tailscale version: $VERSION"
    fi
else
    echo "   ❌ Failed to connect to Tailscale Local API"
    echo "   Error: $STATUS"
    echo ""
    echo "Troubleshooting:"
    echo "  - Is Tailscale running?"
    echo "  - Try: open -a Tailscale"
fi

echo ""
echo "2. Checking if Tailscale is running"
if pgrep -x "Tailscale" > /dev/null; then
    echo "   ✅ Tailscale process is running"
else
    echo "   ❌ Tailscale process is not running"
    echo "   Please start Tailscale from Applications"
fi

echo ""
echo "Done!"
