#!/bin/bash
set -euo pipefail

script_source="${BASH_SOURCE[0]}"
while [[ -h "$script_source" ]]; do
  script_directory="$(cd -P "$(dirname "$script_source")" && pwd)"
  script_source="$(readlink "$script_source")"
  [[ "$script_source" = /* ]] || script_source="$script_directory/$script_source"
done
repository_root="$(cd -P "$(dirname "$script_source")/.." && pwd)"

case "${1:-}" in
  "") "$repository_root/scripts/build.sh" ;;
  --skip-build) ;;
  -h|--help)
    printf 'Usage: %s [--skip-build]\nInstalls Keyboard Overlay in ~/Applications.\n' "$0"
    exit 0
    ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
esac

source_app="$repository_root/dist/Keyboard Overlay.app"
applications_directory="$HOME/Applications"
installed_app="$applications_directory/Keyboard Overlay.app"
if [[ ! -x "$source_app/Contents/MacOS/KeyboardOverlay" ]]; then
  printf 'Build the app first with scripts/build.sh.\n' >&2
  exit 1
fi

if [[ -e "$installed_app" ]]; then
  installed_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_app/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$installed_identifier" != "dev.leandro.keyboard-overlay" ]]; then
    printf 'A different app already exists at %s. Move it before installing.\n' "$installed_app" >&2
    exit 1
  fi
fi

mkdir -p "$applications_directory"
staging_directory="$(mktemp -d "$applications_directory/.keyboard-overlay.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
/usr/bin/ditto "$source_app" "$staging_directory/Keyboard Overlay.app"
rm -rf "$installed_app"
mv "$staging_directory/Keyboard Overlay.app" "$installed_app"
launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$launch_services" -f "$installed_app"

printf '\nInstalled %s\n' "$installed_app"
printf 'In Raycast Settings → Extensions → + → Add Script Directory, select:\n%s/raycast\n' "$repository_root"
printf 'Then assign a hotkey to “Show Keyboard Overlay” or an individual layer command.\n'
