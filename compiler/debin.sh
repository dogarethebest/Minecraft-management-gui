#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dis"
RESOURCES_DIR="$SCRIPT_DIR/resources"

CONTROL_FILE="$RESOURCES_DIR/control"
APP_DIR="$BUILD_DIR/opt/Minecraft-management-gui"

#--------------------------------------------------
# Requirements
#--------------------------------------------------

command -v rsync >/dev/null 2>&1 || {
    echo "ERROR: rsync is required."
    exit 1
}

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "ERROR: dpkg-deb is required."
    exit 1
}

#--------------------------------------------------
# Clean build
#--------------------------------------------------

rm -rf "$BUILD_DIR"

mkdir -p \
    "$BUILD_DIR/DEBIAN" \
    "$BUILD_DIR/lib/systemd/system" \
    "$DIST_DIR" \
    "$APP_DIR"

#--------------------------------------------------
# Increment package revision
#
# Example:
# 1.0.0-5 -> 1.0.0-6
#--------------------------------------------------

sed -i -E \
's/^Version: ([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/echo "Version: \1-$((\2+1))"/e' \
"$CONTROL_FILE"

PACKAGE=$(awk '/^Package:/ {print $2; exit}' "$CONTROL_FILE")
VERSION=$(awk '/^Version:/ {print $2; exit}' "$CONTROL_FILE")
ARCH=$(awk '/^Architecture:/ {print $2; exit}' "$CONTROL_FILE")

DEB_NAME="${PACKAGE}_${VERSION}_${ARCH}.deb"

#--------------------------------------------------
# Debian control files
#--------------------------------------------------

cp "$CONTROL_FILE" \
   "$BUILD_DIR/DEBIAN/control"

cp "$RESOURCES_DIR/postinst" \
   "$BUILD_DIR/DEBIAN/postinst"

chmod 0755 "$BUILD_DIR/DEBIAN/postinst"

cp "$RESOURCES_DIR/minecraft-manager.service" \
   "$BUILD_DIR/lib/systemd/system/"

#--------------------------------------------------
# GUI
#--------------------------------------------------

mkdir -p "$APP_DIR/gui"

rsync -a \
    --exclude=".git" \
    --exclude="node_modules" \
    "$REPO_ROOT/gui/" \
    "$APP_DIR/gui/"

#--------------------------------------------------
# Minecraft files
#--------------------------------------------------

mkdir -p \
    "$APP_DIR/mc" \
    "$APP_DIR/mc/plugins" \
    "$APP_DIR/mc/plugins/BlueMap"

cp "$REPO_ROOT/mc/paper.jar" \
   "$APP_DIR/mc/"

cp "$REPO_ROOT/mc/eula.txt" \
   "$APP_DIR/mc/"

cp "$REPO_ROOT/mc/plugins/bluemap-5.22-paper.jar" \
   "$APP_DIR/mc/plugins/"

cp "$REPO_ROOT/mc/plugins/BlueMap/webserver.conf" \
   "$APP_DIR/mc/plugins/BlueMap/"

#--------------------------------------------------
# Other project files
#--------------------------------------------------

for item in \
    code \
    caddy \
    config \
    database \
    routes \
    scripts \
    preset \
    start.sh \
    install.sh \
    package.json \
    package-lock.json \
    README.md
do
    if [[ -e "$REPO_ROOT/$item" ]]; then
        rsync -a "$REPO_ROOT/$item" "$APP_DIR/"
    fi
done

#--------------------------------------------------
# Permissions
#--------------------------------------------------

find "$BUILD_DIR" -type d -exec chmod 755 {} \;
find "$BUILD_DIR" -type f -exec chmod 644 {} \;

chmod 755 "$BUILD_DIR/DEBIAN/postinst"
chmod 755 "$APP_DIR/start.sh" 2>/dev/null || true
chmod 755 "$APP_DIR/caddy/caddy" 2>/dev/null || true

#--------------------------------------------------
# Build package
#--------------------------------------------------

echo "Building Debian package..."

dpkg-deb --build "$BUILD_DIR" "$DIST_DIR/$DEB_NAME"

echo
echo "Package: $PACKAGE"
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Output:"
echo "  $DIST_DIR/$DEB_NAME"