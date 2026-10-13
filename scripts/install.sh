#!/bin/zsh
# Builds Void Echo in Release and puts it in /Applications, in place of the copy there; quits
# the app first if it is running, and opens the new one.
#   ./scripts/install.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Release/Void Echo.app"
TARGET="/Applications/Void Echo.app"

echo "→ Compilation Release…"
# The target, not the scheme: the scheme's post-action would copy the app a second time.
xcodebuild -project VoidEcho.xcodeproj -target VoidEcho -configuration Release \
  SYMROOT="$DERIVED/Build/Products" OBJROOT="$DERIVED/Build/Intermediates.noindex" build -quiet

"$ROOT/scripts/copy-to-applications.sh" "$APP"
# Right after the old copy quits, Launch Services may still refuse (error -600): once more.
open "$TARGET" 2>/dev/null || { sleep 1; open "$TARGET"; }
