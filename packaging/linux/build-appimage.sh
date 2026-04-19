#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build-appimage"

echo "=== Building iptvxs AppImage ==="

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DIPTVXS_BUILD_TESTS=OFF

cmake --build "$BUILD_DIR" --parallel "$(nproc)"

DESTDIR="$BUILD_DIR/AppDir" cmake --install "$BUILD_DIR"

if ! command -v linuxdeploy &>/dev/null; then
    LINUXDEPLOY="$BUILD_DIR/linuxdeploy-x86_64.AppImage"
    if [ ! -f "$LINUXDEPLOY" ]; then
        echo "Downloading linuxdeploy..."
        curl -L -o "$LINUXDEPLOY" \
            "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
        chmod +x "$LINUXDEPLOY"
    fi
else
    LINUXDEPLOY="linuxdeploy"
fi

if ! command -v linuxdeploy-plugin-qt &>/dev/null; then
    QT_PLUGIN="$BUILD_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
    if [ ! -f "$QT_PLUGIN" ]; then
        echo "Downloading linuxdeploy-plugin-qt..."
        curl -L -o "$QT_PLUGIN" \
            "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"
        chmod +x "$QT_PLUGIN"
    fi
    export PATH="$BUILD_DIR:$PATH"
fi

export OUTPUT="$PROJECT_DIR/iptvxs-$(cat "$PROJECT_DIR/CMakeLists.txt" | grep -oP 'VERSION \K[0-9.]+' | head -1)-x86_64.AppImage"

"$LINUXDEPLOY" \
    --appdir "$BUILD_DIR/AppDir" \
    --desktop-file "$BUILD_DIR/AppDir/usr/share/applications/org.schelstraete.iptvxs.desktop" \
    --icon-file "$BUILD_DIR/AppDir/usr/share/icons/hicolor/scalable/apps/org.schelstraete.iptvxs.svg" \
    --plugin qt \
    --output appimage

echo "=== AppImage created: $OUTPUT ==="
