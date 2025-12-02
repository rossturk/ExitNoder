# Tailscale Local API Integration

This implementation uses Tailscale's Local API instead of executing CLI commands, which allows it to work within the macOS App Sandbox.

## How It Works

1. **TailscaleLocalAPI.swift** - Communicates with Tailscale's local HTTP API server
   - Listens on `http://localhost:41641`
   - No subprocess execution required
   - Works within App Sandbox with network client entitlement

2. **TailscaleService.swift** - Updated to use the API instead of CLI

## Setup in Xcode

1. **Add the new files to your project:**
   - Add `TailscaleLocalAPI.swift` to your target
   - The file should already be in the project

2. **Configure Entitlements:**
   - Go to your target's "Signing & Capabilities"
   - Ensure "App Sandbox" is enabled
   - Ensure "Outgoing Connections (Client)" is checked under Network
   - Or use the provided `ExitNodeSwitcherAPI.entitlements` file

## API Endpoints Used

### GET /localapi/v0/status
Returns the current Tailscale status including:
- All peers (nodes in your tailnet)
- Exit node information
- Current connection status

### PATCH /localapi/v0/prefs  
Updates Tailscale preferences including:
- Exit node selection
- Other configuration options

## Benefits over CLI Approach

✅ **No sandbox issues** - HTTP requests are allowed in sandbox  
✅ **No process execution** - More secure and cleaner  
✅ **Better error handling** - HTTP status codes are clearer  
✅ **Faster** - No process spawning overhead  
✅ **More reliable** - Direct communication with daemon

## Troubleshooting

If you get connection errors:

1. **Check Tailscale is running:**
   ```bash
   curl http://localhost:41641/localapi/v0/status
   ```

2. **Check permissions:**
   - Ensure network client entitlement is enabled
   - Verify App Sandbox settings

3. **Check Tailscale version:**
   - Local API requires Tailscale 1.14.0 or later
   - Update if you have an older version

## API Documentation

For more details on Tailscale's Local API:
https://tailscale.com/kb/1080/cli/#local-api

## Notes

- The Local API only accepts requests from localhost
- No authentication required for localhost requests
- API is automatically available when Tailscale is running
- Same functionality as CLI but via HTTP
