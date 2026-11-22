#!/usr/bin/env bash
# Run the app in Chrome on the port the Solid client profile lists as a redirect URI.
#
# Usage: scripts/dev.sh [flutter run arguments]
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
exec flutter run -d chrome --web-port=4400 "$@"
