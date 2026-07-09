#!/bin/bash

rm -rf build

mkdir -p build/DEBIAN
mkdir -p build/opt/Minecraft-management-gui
mkdir -p build/lib/systemd/system

cp resources/control build/DEBIAN/control
cp resources/postinst build/DEBIAN/postinst
cp resources/minecraft-manager.service build/lib/systemd/system/minecraft-manager.service
cd ..

#!/bin/bash

CONTROL_FILE="./compiler/resources/control"

sed -i -E 's/^Version: ([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/echo "Version: \1-$((\2+1))"/e' "$CONTROL_FILE"

echo "Version updated:"
grep "^Version:" "$CONTROL_FILE"
PACKAGE=$(grep "^Package:" "$CONTROL_FILE" | awk '{print $2}')

VERSION=$(grep "^Version:" "$CONTROL_FILE" | awk '{print $2}')

ARCH=$(grep "^Architecture:" "$CONTROL_FILE" | awk '{print $2}')

DEB_NAME="${PACKAGE}_${VERSION}_${ARCH}.deb"

echo "$DEB_NAME"

rsync -av --exclude-from=.gitignore --exclude=build --exclude=.git ./ compiler/build/opt/Minecraft-management-gui/

cd compiler
rm -rf build/opt/Minecraft-management-gui/compiler

dpkg-deb --build build $DEB_NAME