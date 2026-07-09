#!/usr/bin/env bash

set -e

API="https://$(hostname -I | awk '{print $1}')/api/server/properties"

LOG_FILE="${1:-tests/server-property-api.log}"

mkdir -p "$(dirname "$LOG_FILE")"

exec > >(tee -a "$LOG_FILE")
exec 2>&1


log_response() {
    NAME="$1"
    RESPONSE="$2"

    echo
    echo "===================================="
    echo "Response: $NAME"
    echo "Time: $(date)"
    echo "===================================="

    echo "$RESPONSE"

    echo
    echo "Parsed JSON:"
    echo "$RESPONSE" | jq 2>/dev/null || echo "Not valid JSON"

    echo "===================================="
}


require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$1 is required."
        exit 1
    }
}


require curl
require jq


echo "===================================="
echo "Minecraft Properties API Test"
echo "Started: $(date)"
echo "Log file: $LOG_FILE"
echo "===================================="


echo
echo "GET /api/server/properties"

RAW=$(curl -s -L "$API")

log_response "GET all properties" "$RAW"



echo
echo "GET /api/server/properties/max-players"

RAW=$(curl -s -L "$API/max-players")

log_response "GET max-players" "$RAW"

ORIGINAL=$(echo "$RAW" | jq -r '.value')

echo "Original value: $ORIGINAL"



echo
echo "PUT /api/server/properties/max-players"

RAW=$(curl -s -L \
    -X PUT \
    -H "Content-Type: application/json" \
    -d '{"value":50}' \
    "$API/max-players")

log_response "PUT max-players=50" "$RAW"



echo
echo "Verifying max-players"

RAW=$(curl -s -L "$API/max-players")

log_response "Verify max-players" "$RAW"

CURRENT=$(echo "$RAW" | jq -r '.value')


if [[ "$CURRENT" == "50" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi



echo
echo "Restoring original value"

RAW=$(curl -s -L \
    -X PUT \
    -H "Content-Type: application/json" \
    -d "{\"value\":\"$ORIGINAL\"}" \
    "$API/max-players")

log_response "Restore max-players" "$RAW"



echo
echo "PATCH test"

RAW=$(curl -s -L \
    -X PATCH \
    -H "Content-Type: application/json" \
    -d '{
        "motd":"API Test Server",
        "difficulty":"hard",
        "allow-flight":true
    }' \
    "$API")

log_response "PATCH properties" "$RAW"



echo
echo "Reading final values"


for PROP in motd difficulty allow-flight; do

    RAW=$(curl -s "$API/$PROP")

    log_response "GET $PROP" "$RAW"

done



echo
echo "===================================="
echo "API tests completed successfully."
echo "Finished: $(date)"
echo "===================================="