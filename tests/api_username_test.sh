#!/usr/bin/env bash

set -e

API="https://$(hostname -I | awk '{print $1}')"

LOG_FILE="${1:-tests/whitelist-api.log}"

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

    echo "FULL RAW RESPONSE:"
    echo "$RESPONSE"

    echo
    echo "JSON PARSED:"
    echo "$RESPONSE" | sed -n '/^\r\{0,1\}$/,$p' | jq 2>/dev/null || echo "Invalid JSON"

    echo "===================================="
    echo
}


curl_request() {
    curl -k -i -s "$@"
}


echo "===================================="
echo "Testing Minecraft API"
echo "API: $API"
echo "Log: $LOG_FILE"
echo "Started: $(date)"
echo "===================================="


echo
echo "== Test endpoint =="

RAW=$(curl_request "$API/api/test")

log_response "GET /api/test" "$RAW"



echo
echo "== Get whitelist =="

RAW=$(curl_request "$API/api/whitelist")

log_response "GET /api/whitelist" "$RAW"



USERNAME="Notch"

echo
echo "== Adding player: $USERNAME =="

RAW=$(curl_request \
    -X POST "$API/api/whitelist" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\"}")

log_response "POST /api/whitelist username=$USERNAME" "$RAW"



echo
echo "== Current whitelist =="

WHITELIST=$(curl_request "$API/api/whitelist")

log_response "GET /api/whitelist after add" "$WHITELIST"



UUID=$(echo "$WHITELIST" | sed -n '/^\r\{0,1\}$/,$p' | jq -r '.[0].uuid' 2>/dev/null || echo "")


if [ "$UUID" != "null" ] && [ -n "$UUID" ]; then

    echo
    echo "== Removing UUID: $UUID =="

    RAW=$(curl_request \
        -X DELETE \
        "$API/api/whitelist/$UUID")

    log_response "DELETE /api/whitelist/$UUID" "$RAW"

else

    echo "No UUID found, skipping delete."

fi



echo
echo "== Final whitelist =="

RAW=$(curl_request "$API/api/whitelist")

log_response "GET final whitelist" "$RAW"



echo
echo "===================================="
echo "API test complete."
echo "Finished: $(date)"
echo "===================================="