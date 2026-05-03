#!/usr/bin/env bash
set -euo pipefail

# Yapper Release Script
# Run from the repo root: ./app/scripts/release.sh
#
# Prerequisites:
#   - macOS with Xcode installed
#   - gh CLI authenticated (gh auth status)
#   - Sparkle private key in macOS keychain (run generate-sparkle-key.sh once)
#
# Usage:
#   ./app/scripts/release.sh             — build, copy DMG to website, commit, push
#   ./app/scripts/release.sh --release   — same + GitHub Release tagging (requires clean git)
#   ./app/scripts/release.sh --release patch   — bump + release
#   ./app/scripts/release.sh --release minor   — bump + release
#   ./app/scripts/release.sh --release major   — bump + release

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
INFO_PLIST="$APP_ROOT/Yapper/Support/Info.plist"

WEBSITE_DMG_DIR="$REPO_ROOT/website/public/downloads"
WEBSITE_DMG_PATH="$WEBSITE_DMG_DIR/Yapper-latest.dmg"

RELEASE_MODE=false
BUMP="${2:-}"

if [[ "${1:-}" == "--release" ]]; then
  RELEASE_MODE=true
  BUMP="${2:-}"

  unset GITHUB_TOKEN

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
fi

cd "$REPO_ROOT"

# Read current version
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")

echo "📦 Yapper v$VERSION (build $BUILD_NUM)"

# Bump version if requested (only in release mode)
if [[ "$RELEASE_MODE" == true && -n "$BUMP" ]]; then
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
echo "📝 Generating signed appcast..."
DOWNLOAD_URL_PREFIX="https://yapper.party/downloads" \
  cd "$APP_ROOT" && ./scripts/generate-appcast.sh

echo ""
echo "📋 Copying DMG and appcast to website..."
mkdir -p "$WEBSITE_DMG_DIR"
cp "$APP_ROOT/dist/Yapper-$VERSION.dmg" "$WEBSITE_DMG_PATH"
cp "$APP_ROOT/dist/sparkle/appcast.xml" "$REPO_ROOT/website/public/appcast.xml"

if [[ "$RELEASE_MODE" == true ]]; then
  echo ""
  echo "🚀 Creating GitHub Release..."
  cd "$REPO_ROOT"
  TAG="v$VERSION"

  DMG_PATH="app/dist/Yapper-$VERSION.dmg"
  SHA_PATH="app/dist/Yapper-$VERSION.dmg.sha256"

  if gh release view "$TAG" --repo lebomorojele/Yapper &>/dev/null; then
    gh release upload "$TAG" "$DMG_PATH" "$SHA_PATH" \
      --repo lebomorojele/Yapper --clobber
  else
    gh release create "$TAG" "$DMG_PATH" "$SHA_PATH" \
      --title "Yapper $VERSION" \
      --notes "Release Yapper $VERSION" \
      --repo lebomorojele/Yapper
    echo "✅ Release $TAG created"
  fi
fi

echo ""
echo "📤 Committing DMG and appcast to main..."
cd "$REPO_ROOT"
git add website/public/downloads/Yapper-latest.dmg website/public/appcast.xml
git commit -m "chore: update DMG and appcast for v$VERSION"
git push

echo ""
echo "✅ Done!"
echo "   DMG:  https://yapper.party/downloads/Yapper-latest.dmg"
echo "   DMGs are now committed to the repo — Coolify will auto-deploy"

if [[ "$RELEASE_MODE" == true ]]; then
  echo "   Release: https://github.com/lebomorojele/Yapper/releases/tag/v$VERSION"
fi

echo "   Appcast: https://yapper.party/appcast.xml"