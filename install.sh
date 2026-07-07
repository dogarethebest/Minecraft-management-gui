#!/usr/bin/env bash
#!/usr/bin/env bash

MIN_RAM_GB=8

# Check for RAM bypass flag
if [[ " $* " == *" --BYRR "* ]]; then
    echo "RAM check bypassed with --BYRR"
else
    MIN_RAM_BYTES=$((MIN_RAM_GB * 1024 * 1024 * 1024))

    TOTAL_RAM_BYTES=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)

    if [ "$TOTAL_RAM_BYTES" -lt "$MIN_RAM_BYTES" ]; then
        TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))

        echo "ERROR: Not enough RAM."
        echo "Required: ${MIN_RAM_GB}GB"
        echo "Detected: ${TOTAL_RAM_GB}GB"
        echo ""
        echo "If you want to bypass this check, run:"
        echo "./install.sh --BYRR"
        exit 1
    fi

    echo "RAM check passed."
fi

echo "Continuing installation..."

echo "RAM check passed: ${TOTAL_RAM_GB}GB available"

sudo add-apt-repository universe -y
sudo apt update
sudo apt install openjdk-25-jdk -y

# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

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

cp preset/eula.txt mc/eula.txt
cp preset/server.properties mc/server.properties

echo "Final configuration will be in gui"