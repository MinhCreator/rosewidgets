#!/usr/bin/env bash
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
conf="${XDG_CONFIG_HOME:-$HOME/.config}"
dest="$conf/quickshell/rosewidgets"
data="$conf/rosewidgets"

if ! command -v qs >/dev/null 2>&1 && ! command -v quickshell >/dev/null 2>&1; then
  echo "quickshell is not installed" >&2
  exit 1
fi

mkdir -p "$dest" "$data/widgets" "$data/themes"

if [ "$src" != "$dest" ]; then
  cp -f "$src"/*.qml "$src"/*.js "$dest"/
fi

if [ ! -f "$data/config.toml" ] && [ -f "$src/config.example.toml" ]; then
  cp "$src/config.example.toml" "$data/config.toml"
fi

echo "installed to $dest"
echo "run: qs -c rosewidgets"
