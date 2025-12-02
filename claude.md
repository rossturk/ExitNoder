# Development Notes

## Tailscale Integration - IMPORTANT

**Status 5 Error with Mac App Store Version:**
- The Mac App Store version of Tailscale does NOT expose a local API
- Exit status 5 means the command requires authentication/elevation
- The bundled CLI at `/Applications/Tailscale.app/Contents/MacOS/Tailscale` cannot be used directly from a sandboxed app
- We CANNOT use the Local API approach - it doesn't work with the Mac App Store version

**What we tried that DOESN'T work:**
- ❌ Running `/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json` - Returns exit status 5
- ❌ Using the Tailscale Local API (port 41112) - Not available in Mac App Store version
- ❌ Process/CLI approach - Requires elevated permissions that sandboxed apps can't get

**What we need to do instead:**
- Use the official Tailscale API (cloud-based)
- OR use XPC/inter-process communication if Tailscale exposes it
- OR use AppleScript/shell scripts with proper entitlements
- OR require users to install the non-App Store version
- OR explore if Tailscale has a System Extension or Network Extension we can communicate with

**Key insight:** The Mac App Store version is sandboxed and can't execute external binaries that require elevated permissions. Exit status 5 typically means "permission denied" or "authentication required".

---

_Last updated: 2025-12-01_
