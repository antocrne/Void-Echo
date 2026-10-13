#!/bin/zsh
# Puts a built Void Echo.app in /Applications, in place of the copy there. If that copy is
# running, it is quit first (politely, so pending changes are saved) and not reopened.
# Called after every build of the VoidEcho scheme (Xcode or xcodebuild), and by install.sh.
#   ./scripts/copy-to-applications.sh "<path>/Void Echo.app"
set -euo pipefail

APP=${1:?"usage: $0 <path>/Void Echo.app"}
TARGET="/Applications/Void Echo.app"
RUNNING="$TARGET/Contents/MacOS/Void Echo"

[[ -d "$APP" ]] || { echo "Pas d'app à $APP"; exit 1; }
[[ "$APP" -ef "$TARGET" ]] && exit 0
# Nothing new (a build that failed, or changed nothing): leave the running copy alone.
if [[ -d "$TARGET" ]] && diff -rq "$APP" "$TARGET" > /dev/null 2>&1; then
  echo "= $TARGET déjà à jour"
  exit 0
fi

if pgrep -f "$RUNNING" > /dev/null; then
  echo "→ Fermeture de la copie de /Applications…"
  osascript -e "tell application \"$TARGET\" to quit" || true
  for _ in {1..50}; do
    pgrep -f "$RUNNING" > /dev/null || break
    sleep 0.1
  done
fi

echo "→ Copie dans /Applications…"
rm -rf "$TARGET"
ditto "$APP" "$TARGET"
echo "✓ $TARGET ($(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$TARGET/Contents/Info.plist"), $(date '+%H:%M:%S'))"
