#!/bin/bash
set -euo pipefail

script_source="${BASH_SOURCE[0]}"
while [[ -h "$script_source" ]]; do
  script_directory="$(cd -P "$(dirname "$script_source")" && pwd)"
  script_source="$(readlink "$script_source")"
  [[ "$script_source" = /* ]] || script_source="$script_directory/$script_source"
done
repository_root="$(cd -P "$(dirname "$script_source")/.." && pwd)"

layer="${1:-}"
case "$layer" in
  "") overlay_url='keyboard-overlay://show' ;;
  0|1|2) overlay_url="keyboard-overlay://show?layer=$layer" ;;
  *) printf 'Layer must be 0, 1, or 2.\n' >&2; exit 1 ;;
esac

app_path="$HOME/Applications/Keyboard Overlay.app"
if [[ ! -x "$app_path/Contents/MacOS/KeyboardOverlay" ]]; then
  app_path="$repository_root/dist/Keyboard Overlay.app"
fi
if [[ ! -x "$app_path/Contents/MacOS/KeyboardOverlay" ]]; then
  printf 'Run scripts/install.sh in the Keyboard Overlay repository first.\n' >&2
  exit 1
fi

# Sending a URL also reaches an already-running app; open --args does not.
exec /usr/bin/open -g -a "$app_path" "$overlay_url"
