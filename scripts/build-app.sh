#!/usr/bin/env bash
# Builds Beacon.app into build/. Ad hoc signed unless SIGN_IDENTITY is set (a "Developer ID Application: ..." name).
# The marketing version comes from App/project.yml; the build number is the number of commits, so every build of a
# different commit is distinguishable and the number only ever goes up.
# usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:--}"
BUILD_NUMBER="$(git rev-list --count HEAD)"
(cd App && xcodegen generate)
rm -rf build/Beacon.xcarchive build/Beacon.app
xcodebuild archive \
  -project App/Beacon.xcodeproj -scheme Beacon -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/Beacon.xcarchive \
  CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" | tail -3
cp -R build/Beacon.xcarchive/Products/Applications/Beacon.app build/Beacon.app
codesign --verify --deep --strict build/Beacon.app
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Beacon.app/Contents/Info.plist)"
echo "built build/Beacon.app: version $VERSION, build $BUILD_NUMBER (identity: $IDENTITY)"
