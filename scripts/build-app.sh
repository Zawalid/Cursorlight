#!/usr/bin/env bash
# Builds Cursorlight.app into build/. Ad hoc signed unless SIGN_IDENTITY is set (a "Developer ID Application: ..." name).
# The marketing version comes from App/project.yml; the build number is the number of commits, so every build of a
# different commit is distinguishable and the number only ever goes up.
# usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:--}"
BUILD_NUMBER="$(git rev-list --count HEAD)"
(cd App && xcodegen generate)
rm -rf build/Cursorlight.xcarchive build/Cursorlight.app
xcodebuild archive \
  -project App/Cursorlight.xcodeproj -scheme Cursorlight -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/Cursorlight.xcarchive \
  CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" | tail -3
cp -R build/Cursorlight.xcarchive/Products/Applications/Cursorlight.app build/Cursorlight.app
codesign --verify --deep --strict build/Cursorlight.app
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Cursorlight.app/Contents/Info.plist)"
echo "built build/Cursorlight.app: version $VERSION, build $BUILD_NUMBER (identity: $IDENTITY)"
