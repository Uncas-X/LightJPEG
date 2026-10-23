#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$TASK_ROOT/vendor/module-cache"
xcrun swiftc -O -swift-version 5 -parse-as-library -module-cache-path "$TASK_ROOT/vendor/module-cache" \
  "$TASK_ROOT/Sources/Engine.swift" "$TASK_ROOT/Tests/EngineTests.swift" -o "$TASK_ROOT/vendor/EngineTests"
"$TASK_ROOT/vendor/EngineTests"
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$TASK_ROOT/vendor/module-cache" \
  "$TASK_ROOT/Sources/Localizer.swift" "$TASK_ROOT/Tests/LocalizationTests.swift" -o "$TASK_ROOT/vendor/LocalizationTests"
"$TASK_ROOT/vendor/LocalizationTests" "$TASK_ROOT/Sources/LocalizationKeys.txt"
xcrun swiftc -O -swift-version 5 -parse-as-library -module-cache-path "$TASK_ROOT/vendor/module-cache" \
  "$TASK_ROOT/Sources/Engine.swift" "$TASK_ROOT/Sources/Localizer.swift" "$TASK_ROOT/Sources/AppModel.swift" \
  "$TASK_ROOT/Tests/ExportTests.swift" -o "$TASK_ROOT/vendor/ExportTests"
"$TASK_ROOT/vendor/ExportTests"
xcrun swiftc -O -swift-version 5 -parse-as-library -module-cache-path "$TASK_ROOT/vendor/module-cache" \
  "$TASK_ROOT/Sources/Engine.swift" "$TASK_ROOT/Sources/Localizer.swift" "$TASK_ROOT/Sources/AppModel.swift" \
  "$TASK_ROOT/Tests/ModelTests.swift" -o "$TASK_ROOT/vendor/ModelTests"
"$TASK_ROOT/vendor/ModelTests"
# The native NSView interaction tests need a logged-in macOS desktop session.
# Set LIGHTJPEG_SKIP_UI_TESTS=1 when running on a headless CI host.
if [[ "${LIGHTJPEG_SKIP_UI_TESTS:-0}" != "1" ]]; then
  xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$TASK_ROOT/vendor/module-cache" \
    "$TASK_ROOT/Sources/Engine.swift" "$TASK_ROOT/Sources/Localizer.swift" "$TASK_ROOT/Sources/AppModel.swift" \
    "$TASK_ROOT/Sources/ContentView.swift" "$TASK_ROOT/Sources/NativeComparisonView.swift" \
    "$TASK_ROOT/Tests/NativePreviewTests.swift" -o "$TASK_ROOT/vendor/NativePreviewTests"
  "$TASK_ROOT/vendor/NativePreviewTests"
fi
