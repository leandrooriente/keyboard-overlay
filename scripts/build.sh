#!/bin/bash
set -euo pipefail

script_source="${BASH_SOURCE[0]}"
while [[ -h "$script_source" ]]; do
  script_directory="$(cd -P "$(dirname "$script_source")" && pwd)"
  script_source="$(readlink "$script_source")"
  [[ "$script_source" = /* ]] || script_source="$script_directory/$script_source"
done
repository_root="$(cd -P "$(dirname "$script_source")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'Keyboard Overlay requires macOS.\n' >&2
  exit 1
fi

swift build --package-path "$repository_root" -c release
build_directory="$(swift build --package-path "$repository_root" -c release --show-bin-path)"
output_directory="$repository_root/dist"
app_path="$output_directory/Keyboard Overlay.app"
mkdir -p "$output_directory"
staging_directory="$(mktemp -d "$output_directory/.build.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
staging_app="$staging_directory/Keyboard Overlay.app"
mkdir -p "$staging_app/Contents/MacOS" "$staging_app/Contents/Resources"
cp "$build_directory/KeyboardOverlay" "$staging_app/Contents/MacOS/KeyboardOverlay"

# SwiftPM resources remain data files, so a future Oryx importer can replace them.
# The app resolves this packaged bundle before using SwiftPM's development path.
for resource_bundle in "$build_directory"/*.bundle; do
  [[ -d "$resource_bundle" ]] || continue
  /usr/bin/ditto "$resource_bundle" "$staging_app/Contents/Resources/$(basename "$resource_bundle")"
done

cat > "$staging_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>Keyboard Overlay</string>
  <key>CFBundleExecutable</key><string>KeyboardOverlay</string>
  <key>CFBundleIdentifier</key><string>dev.leandro.keyboard-overlay</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Keyboard Overlay</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>CFBundleURLName</key><string>dev.leandro.keyboard-overlay</string>
      <key>CFBundleURLSchemes</key><array><string>keyboard-overlay</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$staging_app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$staging_app"
rm -rf "$app_path"
mv "$staging_app" "$app_path"
printf '\nBuilt %s\n' "$app_path"
