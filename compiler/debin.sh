#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dis"
RESOURCES_DIR="$SCRIPT_DIR/resources"
CONTROL_FILE="$RESOURCES_DIR/control"
APP_DIR="$BUILD_DIR/opt/Minecraft-management-gui"

command -v rsync >/dev/null 2>&1 || {
    echo "ERROR: rsync is required to build the Debian package." >&2
    exit 1
}
command -v dpkg-deb >/dev/null 2>&1 || {
    echo "ERROR: dpkg-deb is required to build the Debian package." >&2
    exit 1
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN" \
         "$APP_DIR" \
         "$BUILD_DIR/lib/systemd/system" \
         "$DIST_DIR"

sed -i -E 's/^Version: ([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/echo "Version: \1-$((\2+1))"/e' "$CONTROL_FILE"

PACKAGE=$(awk '/^Package:/ {print $2; exit}' "$CONTROL_FILE")
VERSION=$(awk '/^Version:/ {print $2; exit}' "$CONTROL_FILE")
ARCH=$(awk '/^Architecture:/ {print $2; exit}' "$CONTROL_FILE")
DEB_NAME="${PACKAGE}_${VERSION}_${ARCH}.deb"

cp "$CONTROL_FILE" "$BUILD_DIR/DEBIAN/control"
cp "$RESOURCES_DIR/postinst" "$BUILD_DIR/DEBIAN/postinst"
chmod 0755 "$BUILD_DIR/DEBIAN/postinst"
cp "$RESOURCES_DIR/minecraft-manager.service" "$BUILD_DIR/lib/systemd/system/minecraft-manager.service"

RSYNC_EXCLUDES=(
    --exclude=.git
    --exclude=compiler/build
    --exclude=compiler/dis
)
if [[ -f "$REPO_ROOT/.gitignore" ]]; then
    RSYNC_EXCLUDES+=(--exclude-from="$REPO_ROOT/.gitignore")
fi

rsync -a "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/" "$APP_DIR/"
rm -rf "$APP_DIR/compiler"

dpkg-deb --build "$BUILD_DIR" "$DIST_DIR/$DEB_NAME"

echo "Version updated: $VERSION"
echo "Built $DIST_DIR/$DEB_NAME"
