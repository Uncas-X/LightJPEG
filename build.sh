#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
TASK_BUILD="$TASK_ROOT/build"
TASK_APP="$TASK_BUILD/LightJPEG.app"
mkdir -p "$TASK_BUILD" "$TASK_ROOT/vendor/module-cache"
if [[ ! -x "$TASK_ROOT/Resources/bin/cjpeg" ]]; then
  bash "$TASK_ROOT/build-engine.sh"
fi
TASK_SDK="$(xcrun --sdk macosx --show-sdk-path)"
for TASK_ARCH in x86_64 arm64; do
  xcrun swiftc -O -swift-version 5 -parse-as-library \
    -target "$TASK_ARCH-apple-macos13.0" -sdk "$TASK_SDK" \
    -module-cache-path "$TASK_ROOT/vendor/module-cache" \
    "$TASK_ROOT"/Sources/*.swift -o "$TASK_BUILD/LightJPEG-$TASK_ARCH"
done
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
xcrun lipo -create "$TASK_BUILD/LightJPEG-x86_64" "$TASK_BUILD/LightJPEG-arm64" \
  -output "$TASK_APP/Contents/MacOS/LightJPEG"
cp -R "$TASK_ROOT/Resources/." "$TASK_APP/Contents/Resources/"
cp "$TASK_ROOT/Info.plist" "$TASK_APP/Contents/Info.plist"
printf 'APPL????' > "$TASK_APP/Contents/PkgInfo"
codesign --force --sign - "$TASK_APP/Contents/Resources/bin/cjpeg"
codesign --force --sign - "$TASK_APP"
codesign --verify --deep --strict "$TASK_APP"
xcrun lipo -info "$TASK_APP/Contents/MacOS/LightJPEG"
printf '\nBuilt %s\n' "$TASK_APP"
