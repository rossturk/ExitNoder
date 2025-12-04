# Quick Release Guide

## Creating a New Release

### 1. Update Version Number (Optional)
Update the version in your Xcode project if needed.

### 2. Commit Your Changes
```bash
git add .
git commit -m "Release v1.0.0"
git push origin main
```

### 3. Create and Push a Tag
```bash
# Create a tag for your release
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push the tag to GitHub
git push origin v1.0.0
```

### 4. Watch the Action Run
- Go to your repository on GitHub
- Click the "Actions" tab
- Watch your workflow run

### 5. Check Your Release
- Once complete, go to the "Releases" tab
- Your new release will be there with downloadable files!

## Version Numbering

Use semantic versioning: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (v2.0.0)
- **MINOR**: New features, backwards compatible (v1.1.0)
- **PATCH**: Bug fixes (v1.0.1)

For pre-releases:
- Beta: `v1.0.0-beta.1`
- Alpha: `v1.0.0-alpha.1`
- RC: `v1.0.0-rc.1`

## Editing or Deleting a Release

### To re-release with the same version:
```bash
# Delete the tag locally
git tag -d v1.0.0

# Delete the tag on GitHub
git push origin :refs/tags/v1.0.0

# Delete the release on GitHub (via web interface)
# Then create the tag again
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Testing Before Release

Before creating a tag, you can manually trigger a build:
1. Go to Actions tab
2. Select "Build on Main" workflow
3. Click "Run workflow"

This builds the app without creating a release.

## Automated Every Merge

The `build.yml` workflow already runs on every merge to main, so you'll always know if your code builds successfully!
