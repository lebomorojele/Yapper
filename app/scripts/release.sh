#!/usr/bin/env bash
set -euo pipefail

# Yapper Release Script
# Run from the repo root: ./app/scripts/release.sh
#
# Prerequisites:
#   - macOS with Xcode installed
#   - gh CLI authenticated (gh auth status)
#   - Sparkle private key in macOS keychain (run generate-sparkle-key.sh once)
#   - Clean git status (no uncommitted changes)
#
# Usage:
#   ./app/scripts/release.sh          — releases current version
#   ./app/scripts/release.sh patch    — bumps patch (0.1.0 → 0.1.1) then releases
#   ./app/scripts/release.sh minor    — bumps minor (0.1.0 → 0.2.0) then releases
#   ./app/scripts/release.sh major    — bumps major (0.1.0 → 1.0.0) then releases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
INFO_PLIST="$APP_ROOT/Yapper/Support/Info.plist"

BUMP="${1:-}"

# Ensure we're in the repo root
cd "$REPO_ROOT"

# Check prerequisites
if ! git diff --quiet; then
  echo "❌ Uncommitted changes. Commit or stash first."
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "❌ gh CLI not found. Install it: brew install gh"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "❌ gh not authenticated. Run: gh auth login"
  exit 1
fi

# Read current version
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")

echo "📦 Yapper v$VERSION (build $BUILD_NUM)"

# Bump version if requested
if [[ -n "$BUMP" ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
  case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
    *) echo "❌ Unknown bump type: $BUMP (use: major, minor, patch)"; exit 1 ;;
  esac
  VERSION="$MAJOR.$MINOR.$PATCH"
  BUILD_NUM=$((BUILD_NUM + 1))

  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" "$INFO_PLIST"
  echo "🔖 Bumped to v$VERSION (build $BUILD_NUM)"

  git add "$INFO_PLIST"
  git commit -m "chore: bump version to v$VERSION"
  git push
  echo "✅ Version bump committed and pushed"
fi

echo ""
echo "🔨 Building..."

cd "$APP_ROOT"
swift build -c release

echo ""
echo "📀 Packaging DMG..."
ALLOW_PLACEHOLDER_SPARKLE_KEY=1 ./scripts/package-dmg.sh

echo ""
echo "🚀 Creating GitHub Release..."
cd "$REPO_ROOT"
TAG="v$VERSION"

if gh release view "$TAG" --repo lebomorojele/Yapper &>/dev/null; then
  echo "Release $TAG already exists, uploading DMG..."
  gh release upload "$TAG" "app/dist/Yapper-$VERSION.dmg" "app/dist/Yapper-$VERSION.dmg.sha256" \
    --repo lebomorojele/Yapper --clobber
else
  gh release create "$TAG" "app/dist/Yapper-$VERSION.dmg" "app/dist/Yapper-$VERSION.dmg.sha256" \
    --title "Yapper $VERSION" \
    --notes "Release Yapper $VERSION" \
    --repo lebomorojele/Yapper
  echo "✅ Release $TAG created"
fi

echo ""
echo "📝 Generating signed appcast..."
DOWNLOAD_URL_PREFIX="https://github.com/lebomorojele/Yapper/releases/download/v$VERSION" \
  cd "$APP_ROOT" && ./scripts/generate-appcast.sh

echo ""
echo "📋 Copying appcast to website..."
cp "$APP_ROOT/dist/sparkle/appcast.xml" "$REPO_ROOT/website/public/appcast.xml"

echo ""
echo "📤 Committing and pushing appcast..."
cd "$REPO_ROOT"
git add website/public/appcast.xml
git commit -m "chore: update appcast for v$VERSION"
git push

echo ""
echo "✅ Done! Yapper v$VERSION released."
echo "   Release: https://github.com/lebomorojele/Yapper/releases/tag/v$VERSION"
echo "   Appcast: https://yapper.party/appcast.xml"
echo ""
echo "   Coolify will auto-deploy the updated appcast."