#!/usr/bin/env bash
set -euo pipefail
app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift package --package-path "$app_root" resolve
xcodegen generate --spec "$app_root/project.yml" --project "$app_root"
resolved_dir="$app_root/Yapper.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$resolved_dir"
cp "$app_root/Package.resolved" "$resolved_dir/Package.resolved"
