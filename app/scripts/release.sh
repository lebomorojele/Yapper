#!/usr/bin/env bash
set -euo pipefail

# Yapper Release Script
# Run from the repo root: ./app/scripts/release.sh
#
# Prerequisites:
#   - macOS with Xcode installed
#   - Sparkle private key in macOS keychain (run generate-sparkle-key.sh once)
#   - Clean git status (no uncommitted changes)
#   - gh CLI authenticated only when using --release
#
# Usage:
#   ./app/scripts/release.sh             — build, copy DMG to website, commit, push
#   ./app/scripts/release.sh patch       — bump patch, then build/copy/commit/push
#   ./app/scripts/release.sh minor       — bump minor, then build/copy/commit/push
#   ./app/scripts/release.sh major       — bump major, then build/copy/commit/push
#   ./app/scripts/release.sh --release   — same + GitHub Release tagging
#   ./app/scripts/release.sh --release patch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
INFO_PLIST="$APP_ROOT/Yapper/Support/Info.plist"

WEBSITE_DMG_DIR="$REPO_ROOT/website/public/downloads"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://yapper.party/downloads}"
RELEASE_MODE=false
BUMP=""

if [[ "${1:-}" == "--release" ]]; then
  RELEASE_MODE=true
  BUMP="${2:-}"
else
  BUMP="${1:-}"
fi

cd "$REPO_ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Uncommitted changes. Commit or stash first."
  exit 1
fi

if [[ "$RELEASE_MODE" == true ]]; then
  # gh CLI prefers its own stored credentials. If a GITHUB_TOKEN env var is set
  # by the agent environment, unset it so gh uses your stored auth.
  unset GITHUB_TOKEN

  if ! command -v gh &> /dev/null; then
    echo "❌ gh CLI not found. Install it: brew install gh"
    exit 1
  fi

  if ! gh auth status &> /dev/null; then
    echo "❌ gh not authenticated. Run: gh auth login"
    exit 1
  fi
fi

sync_with_upstream() {
  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [[ -z "$upstream" ]]; then
    echo "ℹ️  No upstream configured for this branch; skipping pull."
    return
  fi

  echo "🔄 Fetching latest $upstream..."
  git fetch --prune

  local_head="$(git rev-parse HEAD)"
  remote_head="$(git rev-parse "$upstream")"

  if [[ "$local_head" == "$remote_head" ]]; then
    echo "✅ Branch is up to date with $upstream."
  elif git merge-base --is-ancestor "$upstream" HEAD; then
    echo "✅ Branch already contains $upstream; local commits are ahead."
  elif git merge-base --is-ancestor HEAD "$upstream"; then
    echo "🔄 Fast-forwarding to $upstream..."
    git merge --ff-only "$upstream"
  else
    echo "🔄 Rebasing local commits onto $upstream..."
    git rebase "$upstream"
  fi
}

sync_with_upstream

# Read current version
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")

echo "📦 Yapper v$VERSION (build $BUILD_NUM)"

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
echo "📝 Generating signed appcast..."
DOWNLOAD_URL_PREFIX="$DOWNLOAD_URL_PREFIX" ./scripts/generate-appcast.sh

echo ""
echo "📋 Copying artifacts to website..."
mkdir -p "$WEBSITE_DMG_DIR"
cp "$APP_ROOT/dist/Yapper-$VERSION.dmg" "$WEBSITE_DMG_DIR/Yapper-$VERSION.dmg"
cp "$APP_ROOT/dist/Yapper-$VERSION.dmg.sha256" "$WEBSITE_DMG_DIR/Yapper-$VERSION.dmg.sha256"
cp "$APP_ROOT/dist/Yapper-$VERSION.dmg" "$WEBSITE_DMG_DIR/Yapper-latest.dmg"
cp "$APP_ROOT/dist/sparkle/appcast.xml" "$REPO_ROOT/website/public/appcast.xml"

if [[ "$RELEASE_MODE" == true ]]; then
  echo ""
  echo "🚀 Creating GitHub Release..."
  cd "$REPO_ROOT"
  TAG="v$VERSION"

  if gh release view "$TAG" --repo lebomorojele/Yapper &>/dev/null; then
    echo "Release $TAG already exists, skipping."
  else
    gh release create "$TAG" \
      --title "Yapper $VERSION" \
      --notes "Release Yapper $VERSION" \
      --repo lebomorojele/Yapper
    echo "✅ Release $TAG created"
  fi
fi

echo ""
echo "📤 Committing DMG and appcast to main..."
cd "$REPO_ROOT"
git add website/public/appcast.xml website/public/downloads/

if git diff --cached --quiet; then
  echo "ℹ️  Website release artifacts are already up to date; no commit needed."
else
  git commit -m "chore: release v$VERSION"
fi

sync_with_upstream
git push

echo ""
echo "✅ Done!"
echo "   DMG:     https://yapper.party/downloads/Yapper-$VERSION.dmg"
echo "   Latest:  https://yapper.party/downloads/Yapper-latest.dmg"
echo "   Appcast: https://yapper.party/appcast.xml"
echo "   Coolify will auto-deploy the committed website artifacts."

if [[ "$RELEASE_MODE" == true ]]; then
  echo "   Release: https://github.com/lebomorojele/Yapper/releases/tag/v$VERSION"
fi
