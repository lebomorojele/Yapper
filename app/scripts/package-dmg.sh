#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Yapper"
BUNDLE_ID="com.yapper.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$(swift build -c release --package-path "$APP_ROOT" --show-bin-path)"
DIST_DIR="$APP_ROOT/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
SOURCE_INFO_PLIST="$APP_ROOT/Yapper/Support/Info.plist"
ENTITLEMENTS="$APP_ROOT/Yapper/Support/Yapper.entitlements"
RESOURCE_BUNDLE="$BUILD_DIR/Yapper_Yapper.bundle"
SPARKLE_FRAMEWORK="$BUILD_DIR/Sparkle.framework"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
ALLOW_PLACEHOLDER_SPARKLE_KEY="${ALLOW_PLACEHOLDER_SPARKLE_KEY:-0}"

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" && "$ALLOW_PLACEHOLDER_SPARKLE_KEY" != "1" ]]; then
  cat >&2 <<'EOF'
SPARKLE_PUBLIC_ED_KEY is required for release packaging.

Generate it once with:
  app/scripts/generate-sparkle-key.sh

For unsigned local smoke builds only:
  ALLOW_PLACEHOLDER_SPARKLE_KEY=1 app/scripts/package-dmg.sh
EOF
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_INFO_PLIST")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

rm -rf "$APP_PATH" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR" "$STAGING_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$SOURCE_INFO_PLIST" "$INFO_PLIST"
cp -R "$RESOURCE_BUNDLE"/. "$RESOURCES_DIR/"
cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST"
fi

ICONSET="$DIST_DIR/$APP_NAME.iconset"
ICNS_PATH="$RESOURCES_DIR/$APP_NAME.icns"
PNG_ICON_PATH="$RESOURCES_DIR/$APP_NAME.png"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" "$ICONSET/icon_16x16.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png" "$ICONSET/icon_16x16@2x.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" "$ICONSET/icon_32x32.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png" "$ICONSET/icon_32x32@2x.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" "$ICONSET/icon_128x128.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" "$ICONSET/icon_128x128@2x.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" "$ICONSET/icon_256x256.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" "$ICONSET/icon_256x256@2x.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" "$ICONSET/icon_512x512.png"
cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" "$ICONSET/icon_512x512@2x.png"
if iconutil -c icns "$ICONSET" -o "$ICNS_PATH"; then
  icon_file="$APP_NAME"
else
  cp "$APP_ROOT/Yapper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png" "$PNG_ICON_PATH"
  icon_file="$APP_NAME.png"
fi
rm -rf "$ICONSET"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$INFO_PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $icon_file" "$INFO_PLIST"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
fi

SIGN_IDENTITY="-"
SIGN_OPTIONS=("--force" "--options" "runtime" "--sign" "$SIGN_IDENTITY")
if [[ -n "$IDENTITY" ]]; then
  SIGN_IDENTITY="$IDENTITY"
  SIGN_OPTIONS=("--force" "--options" "runtime" "--timestamp" "--sign" "$SIGN_IDENTITY")
fi

while IFS= read -r executable; do
  codesign "${SIGN_OPTIONS[@]}" "$executable"
done < <(find "$RESOURCES_DIR/LocalInference" -type f \( -perm -111 -o -name '*.dylib' \))

codesign "${SIGN_OPTIONS[@]}" "$FRAMEWORKS_DIR/Sparkle.framework"
codesign "${SIGN_OPTIONS[@]}" --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

cat <<EOF
Built $APP_NAME $VERSION ($BUILD_NUMBER)
App: $APP_PATH
DMG: $DMG_PATH
SHA256: $(cut -d ' ' -f 1 "$DMG_PATH.sha256")
EOF
