#!/bin/bash
# Generates WorkoutApp.xcodeproj from project.yml and opens it in Xcode.
# Safe to re-run any time (for example after pulling changes to project.yml).
set -euo pipefail
cd "$(dirname "$0")"

XCODEGEN_VERSION=2.46.0

if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN=xcodegen
else
  XCODEGEN=.tools/xcodegen/bin/xcodegen
  if [ ! -x "$XCODEGEN" ]; then
    echo "Downloading XcodeGen $XCODEGEN_VERSION (one time only)..."
    mkdir -p .tools
    curl -fsSL -o .tools/xcodegen.zip \
      "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
    unzip -q -o .tools/xcodegen.zip -d .tools
    rm .tools/xcodegen.zip
  fi
fi

# Remember your signing team so regenerating the project doesn't make you
# pick it again in Xcode. The team ID is read from the "Apple Development"
# certificate Xcode creates the first time you build to a device.
if [ ! -f Config/Local.xcconfig ]; then
  TEAM_ID=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
  if [ -n "${TEAM_ID:-}" ]; then
    echo "DEVELOPMENT_TEAM = $TEAM_ID" > Config/Local.xcconfig
    echo "Using signing team $TEAM_ID"
  fi
fi

"$XCODEGEN" generate --quiet
echo "Generated WorkoutApp.xcodeproj"
open WorkoutApp.xcodeproj
