# Development Notes

## Tailscale Integration - IMPORTANT

### Mac App Store Version (DOESN'T WORK)
**Status 5 Error with Mac App Store Version:**
- The Mac App Store version of Tailscale does NOT expose a local API
- Exit status 5 means the command requires authentication/elevation
- The bundled CLI at `/Applications/Tailscale.app/Contents/MacOS/Tailscale` cannot be used directly from a sandboxed app
- We CANNOT use the Local API approach - it doesn't work with the Mac App Store version

**What we tried that DOESN'T work:**
- ❌ Running `/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json` - Returns exit status 5
- ❌ Using the Tailscale Local API (port 41112) - Not available in Mac App Store version
- ❌ Process/CLI approach - Requires elevated permissions that sandboxed apps can't get

### Direct Download Version (WORKING!)
**Current Status:**
- ✅ Installed from tailscale.com website (not App Store)
- ✅ Network client entitlements enabled
- ✅ CLI is working and returning valid JSON (19,776 chars)
- ✅ Status parsing is successful
- ℹ️ HTTP Local API not running on port 41112 (connection refused) - using CLI fallback
- 🔍 Finding 0 exit nodes - need to debug why

**What's Working:**
1. App can now execute the Tailscale CLI successfully
2. JSON parsing is working
3. Automatic fallback from HTTP to CLI is working
4. Status information is being retrieved

**Next Steps:**
- Debug why no exit nodes are being found
- Check if exit nodes are configured in Tailscale admin console
- Verify the JSON structure matches our expectations
- May need to enable "Run as exit node" on some devices in your tailnet

---

_Last updated: 2025-12-01_
