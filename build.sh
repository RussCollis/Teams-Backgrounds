#!/bin/bash
#
# Builds the Teams Backgrounds app from the command line.
#
# Usage:
#   ./build.sh                 Release build into ./build/
#   ./build.sh --debug         Debug build
#   ./build.sh --zip           Also create a zip of the app for distribution
#   ./build.sh --clean         Remove previous build output first
#
# Options can be combined, e.g. ./build.sh --clean --zip

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$PROJECT_DIR/Untitled Project.xcodeproj"
SCHEME="MyApp"
APP_NAME="Teams Backgrounds"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
MAKE_ZIP=0
CLEAN=0

for arg in "$@"; do
    case "$arg" in
        --debug) CONFIGURATION="Debug" ;;
        --zip) MAKE_ZIP=1 ;;
        --clean) CLEAN=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

if [ "$CLEAN" -eq 1 ]; then
    echo "==> Cleaning $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    build

APP_SOURCE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_OUTPUT="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Build succeeded but $APP_SOURCE was not found." >&2
    exit 1
fi

rm -rf "$APP_OUTPUT"
ditto "$APP_SOURCE" "$APP_OUTPUT"
echo "==> App: $APP_OUTPUT"

if [ "$MAKE_ZIP" -eq 1 ]; then
    ZIP_OUTPUT="$BUILD_DIR/$APP_NAME.zip"
    rm -f "$ZIP_OUTPUT"
    ditto -c -k --keepParent "$APP_OUTPUT" "$ZIP_OUTPUT"
    echo "==> Zip: $ZIP_OUTPUT"
fi
