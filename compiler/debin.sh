#!/bin/bash

rm -rf build

mkdir -p build/DEBIAN
mkdir -p build/opt/Minecraft-management-gui
mkdir -p build/lib/systemd/system/

cp resources/control build/DEBIAN/control
cp resources/minecraft-manager.service build/lib/systemd/system/minecraft-manager.service
cd ..

rsync -av --exclude-from=.gitignore --exclude=build --exclude=.git ./ compiler/build/opt/Minecraft-management-gui/

cd compiler
rm -rf build/opt/Minecraft-management-gui/compiler

dpkg-deb --build build Minecraft-management-gui.deb