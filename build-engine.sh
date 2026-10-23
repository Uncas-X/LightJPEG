#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
MOZJPEG_VERSION=4.1.5
MOZJPEG_SHA256=9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
ARCHIVE="$TASK_ROOT/vendor/mozjpeg-v$MOZJPEG_VERSION.tar.gz"
SOURCE="$TASK_ROOT/vendor/mozjpeg-$MOZJPEG_VERSION"
mkdir -p "$TASK_ROOT/vendor" "$TASK_ROOT/Resources/bin" "$TASK_ROOT/Resources/Licenses"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --retry 2 "https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v$MOZJPEG_VERSION" -o "$ARCHIVE"
fi
printf '%s  %s\n' "$MOZJPEG_SHA256" "$ARCHIVE" | shasum -a 256 -c -
if [[ ! -d "$SOURCE" ]]; then tar -xzf "$ARCHIVE" -C "$TASK_ROOT/vendor"; fi
TASK_SDK="$(xcrun --sdk macosx --show-sdk-path)"
for TASK_ARCH in x86_64 arm64; do
  TASK_BUILD="$TASK_ROOT/vendor/build-$TASK_ARCH"
  cmake -S "$SOURCE" -B "$TASK_BUILD" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$TASK_ARCH" \
    -DCMAKE_OSX_SYSROOT="$TASK_SDK" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_SIMD=OFF \
    -DPNG_SUPPORTED=OFF -DWITH_TURBOJPEG=OFF -DWITH_JAVA=OFF
  cmake --build "$TASK_BUILD" --target cjpeg-static --parallel 4
done
xcrun lipo -create "$TASK_ROOT/vendor/build-x86_64/cjpeg-static" \
  "$TASK_ROOT/vendor/build-arm64/cjpeg-static" -output "$TASK_ROOT/Resources/bin/cjpeg"
chmod 755 "$TASK_ROOT/Resources/bin/cjpeg"
codesign --force --sign - "$TASK_ROOT/Resources/bin/cjpeg"
cp "$SOURCE/LICENSE.md" "$TASK_ROOT/Resources/Licenses/MozJPEG-LICENSE.md"
cp "$SOURCE/README.ijg" "$TASK_ROOT/Resources/Licenses/MozJPEG-README.ijg"
cp "$SOURCE/README.md" "$TASK_ROOT/Resources/Licenses/MozJPEG-README.md"
xcrun lipo -info "$TASK_ROOT/Resources/bin/cjpeg"
otool -L "$TASK_ROOT/Resources/bin/cjpeg"
"$TASK_ROOT/Resources/bin/cjpeg" -version
