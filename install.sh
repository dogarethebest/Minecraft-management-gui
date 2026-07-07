#!/usr/bin/env bash
sudo add-apt-repository universe -y
sudo apt update
sudo apt install openjdk-25-jdk -y
set -e

API="https://fill.papermc.io/v3/projects/paper"

MC_VERSION=$(
    curl -fsSL "$API" |
    jq -r '
        .versions
        | keys
        | map(select(startswith("1.")))
        | sort_by(split(".") | map(tonumber))
        | last
    '
)

echo "Minecraft version: $MC_VERSION"

echo "Finding latest Paper build..."

curl -fsSL "$API/versions/$MC_VERSION/builds" -o response.json

DOWNLOAD_URL=$(jq -r '.. | objects | .url? // empty' response.json | head -n1)
echo "Downloading:"
echo "$DOWNLOAD_URL"

curl -L \
    -A "MinecraftManagement/1.0" \
    -o paper.jar \
    "$DOWNLOAD_URL"

rm response.json

mkdir -p mc
mv paper.jar mc/paper.jar

cd mc
echo "Starting Paper..."

java -Xms4G -Xmx4G -jar paper.jar --nogui
cp preset/eula.txt mc/eula.txt

echo "Final configuration will be in gui"