#!/usr/bin/env bash

set -e

API="https://$(hostname -I | awk '{print $1}')/api/antixray"

LOG_FILE="${1:-tests/antixray-api.log}"

mkdir -p "$(dirname "$LOG_FILE")"

exec > >(tee -a "$LOG_FILE")
exec 2>&1


log_response() {
    NAME="$1"
    BODY="$2"
    STATUS="$3"
    HEADERS="$4"

    echo
    echo "================================="
    echo "Response: $NAME"
    echo "Time: $(date)"
    echo "HTTP Status: $STATUS"
    echo "================================="

    echo "HEADERS:"
    echo "$HEADERS"

    echo
    echo "BODY:"
    echo "$BODY"

    echo
    echo "JSON PARSED:"
    echo "$BODY" | jq . 2>/dev/null || echo "Invalid JSON"

    echo "================================="
    echo
}


curl_request() {
    TMP_HEADERS=$(mktemp)
    TMP_BODY=$(mktemp)

    STATUS=$(curl \
        -k \
        -s \
        -D "$TMP_HEADERS" \
        -o "$TMP_BODY" \
        -w "%{http_code}" \
        "$@")

    BODY=$(cat "$TMP_BODY")
    HEADERS=$(cat "$TMP_HEADERS")

    rm -f "$TMP_HEADERS" "$TMP_BODY"

    echo "$STATUS"
    echo "$BODY"
    echo "$HEADERS"
}


request() {
    NAME="$1"
    shift

    TMP=$(mktemp)

    curl \
        -k \
        -s \
        -D "$TMP.headers" \
        -o "$TMP.body" \
        -w "%{http_code}" \
        "$@" > "$TMP.status"

    STATUS=$(cat "$TMP.status")
    BODY=$(cat "$TMP.body")
    HEADERS=$(cat "$TMP.headers")

    rm -f "$TMP.status" "$TMP.body" "$TMP.headers"

    log_response "$NAME" "$BODY" "$STATUS" "$HEADERS"
}


echo "================================="
echo " Paper Anti-Xray API Test"
echo " API: $API"
echo " Log: $LOG_FILE"
echo " Started: $(date)"
echo "================================="


echo "[1] Checking current Anti-Xray status..."

request \
    "GET /api/antixray" \
    "$API"



echo "[2] Enabling Anti-Xray..."

request \
    "PUT enabled=true" \
    -X PUT \
    "$API" \
    -H "Content-Type: application/json" \
    -d '{"enabled":true}'



echo "[3] Checking after enable..."

request \
    "GET after enable" \
    "$API"



echo "[4] Disabling Anti-Xray..."

request \
    "PUT enabled=false" \
    -X PUT \
    "$API" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}'



echo "[5] Checking after disable..."

request \
    "GET after disable" \
    "$API"


echo
echo "================================="
echo " Anti-Xray API test complete"
echo " Finished: $(date)"
echo "================================="