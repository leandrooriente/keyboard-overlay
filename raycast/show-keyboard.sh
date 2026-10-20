#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Show Keyboard Overlay
# @raycast.mode silent
# @raycast.packageName Keyboard Overlay
# @raycast.icon ⌨️
# @raycast.description Show your Moonlander keyboard and switch between its three layers.

set -euo pipefail
script_source="${BASH_SOURCE[0]}"
while [[ -h "$script_source" ]]; do
  script_directory="$(cd -P "$(dirname "$script_source")" && pwd)"
  script_source="$(readlink "$script_source")"
  [[ "$script_source" = /* ]] || script_source="$script_directory/$script_source"
done
repository_root="$(cd -P "$(dirname "$script_source")/.." && pwd)"
exec "$repository_root/scripts/launch.sh"
