# ExitNoder CI/CD Setup

This repository includes automated build and release workflows using GitHub Actions.

## Workflows

### 1. Build on Main (`build.yml`)
**Triggers:** Every push to `main` and pull requests

This workflow:
- ✅ Builds the app to ensure it compiles
- ✅ Runs tests (if available)
- ✅ Creates an unsigned development build
- ✅ Uploads the build as an artifact (available for 7 days)

**Use this to:** Verify that code changes build successfully.

### 2. Basic Release (`release.yml`)
**Triggers:** Manual dispatch or when you create a tag starting with `v`

This workflow:
- Builds a release version of the app (unsigned)
- Creates both DMG and ZIP distributions
- Creates a GitHub Release with downloadable files

**Use this to:** Create quick releases for testing or distribution to trusted users.

### 3. Notarized Release (`release-notarized.yml`)
**Triggers:** When you create a tag starting with `v`

This workflow:
- Builds and code signs the app with your Developer ID
- Notarizes the app with Apple
- Creates notarized DMG and ZIP files
- Creates a GitHub Release

**Use this to:** Create production-ready releases that users can download without security warnings.

## Quick Start

### Option 1: Simple Releases (No Code Signing)

If you just want to distribute to developers or trusted testers:

1. Merge your changes to `main`
2. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. The `release.yml` workflow will run automatically
4. Find your release under the "Releases" tab on GitHub

**Note:** Users may see security warnings since the app isn't signed.

### Option 2: Notarized Releases (Recommended for Distribution)

For production releases without security warnings:

#### Prerequisites

You'll need:
- An active Apple Developer Account ($99/year)
- A "Developer ID Application" certificate
- Your Apple Team ID

#### Setup Steps

1. **Export your Developer ID certificate:**
   - Open Keychain Access on your Mac
   - Find your "Developer ID Application" certificate
   - Right-click → Export
   - Save as `.p12` file with a password
   - Convert to base64:
     ```bash
     base64 -i certificate.p12 | pbcopy
     ```

2. **Create an App-Specific Password:**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign in → Security → App-Specific Passwords
   - Generate a new password for "GitHub Actions"

3. **Add GitHub Secrets:**
   - Go to your repository → Settings → Secrets and variables → Actions
   - Add these secrets:
     - `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`: Your base64 certificate
     - `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`: Your .p12 password
     - `APPLE_DEVELOPER_ID`: Your Apple ID email
     - `APPLE_APP_SPECIFIC_PASSWORD`: The app-specific password
     - `APPLE_TEAM_ID`: Your Team ID (find at [developer.apple.com/account](https://developer.apple.com/account))

4. **Create a release:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

The `release-notarized.yml` workflow will:
- Build and sign your app
- Submit to Apple for notarization (takes 1-5 minutes)
- Create a release with fully notarized files

## Workflow Management

### Which workflow should I use?

| Scenario | Workflow | Trigger |
|----------|----------|---------|
| Regular development | `build.yml` | Automatic on push to main |
| Quick test release | `release.yml` | Create a tag like `v1.0.0-beta` |
| Production release | `release-notarized.yml` | Create a tag like `v1.0.0` |

### Disabling unwanted workflows

If you don't want to use all three workflows:

1. **Keep only basic releases:** Delete `release-notarized.yml`
2. **Keep only notarized releases:** Modify `release-notarized.yml` to trigger on any tag, then delete `release.yml`

## Advanced: Homebrew Distribution

To make your app installable via `brew install --cask exitnoder`:

1. Create a notarized release (v1.0.0 or higher)
2. Fork [homebrew-cask](https://github.com/Homebrew/homebrew-cask)
3. Create a cask file at `Casks/exitnoder.rb`:

```ruby
cask "exitnoder" do
  version "1.0.0"
  sha256 "..." # SHA256 of your DMG file

  url "https://github.com/YOUR_USERNAME/exitnoder/releases/download/v#{version}/ExitNoder.dmg"
  name "ExitNoder"
  desc "Menu bar app for managing Tailscale exit nodes"
  homepage "https://github.com/YOUR_USERNAME/exitnoder"

  depends_on macos: ">= :monterey"

  app "ExitNoder.app"
end
```

4. Submit a PR to homebrew-cask

Alternatively, create your own tap:

```bash
# Create a tap repository
brew tap-new your-username/homebrew-tap

# Add your cask
brew create --cask --set-name exitnoder \
  https://github.com/YOUR_USERNAME/exitnoder/releases/download/v1.0.0/ExitNoder.dmg
```

## Troubleshooting

### Build fails with "scheme not found"

Update the `SCHEME` variable in the workflow files to match your Xcode scheme name.

### Notarization fails

- Verify all secrets are set correctly
- Ensure your certificate is "Developer ID Application" (not "Mac App Distribution")
- Check that your Apple Developer account is active

### DMG creation fails

The workflows have a fallback to create simple DMGs if `create-dmg` fails. If issues persist, you can simplify the DMG creation step.

## Testing Locally

Before creating a release, test the build process locally:

```bash
# Build unsigned
xcodebuild clean archive \
  -scheme ExitNoder \
  -archivePath ExitNoder.xcarchive \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

# Build signed (if you have certificates)
xcodebuild clean archive \
  -scheme ExitNoder \
  -archivePath ExitNoder.xcarchive \
  -configuration Release

# Create DMG
brew install create-dmg
create-dmg --volname "ExitNoder" ExitNoder.dmg ExitNoder.xcarchive/Products/Applications/
```

## Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [GitHub Actions for Xcode](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-swift)
- [Distributing Mac Apps Outside the App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
