#!/usr/bin/env bash

API="http://127.0.0.1:3001"

echo "Testing Minecraft API..."
echo

echo "== Test endpoint =="
curl -s "$API/api/test" | jq
echo
echo


echo "== Get whitelist =="
curl -s "$API/api/whitelist" | jq
echo
echo


USERNAME="Notch"

echo "== Adding player: $USERNAME =="

ADD_RESPONSE=$(curl -s \
    -X POST "$API/api/whitelist" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\"}")

echo "$ADD_RESPONSE" | jq

echo
echo


echo "== Current whitelist =="

WHITELIST=$(curl -s "$API/api/whitelist")

echo "$WHITELIST" | jq

echo
echo


UUID=$(echo "$WHITELIST" | jq -r '.[0].uuid')


if [ "$UUID" != "null" ] && [ -n "$UUID" ]; then

    echo "== Removing UUID: $UUID =="

    curl -s \
        -X DELETE \
        "$API/api/whitelist/$UUID" | jq

else

    echo "No UUID found, skipping delete."

fi


echo
echo "== Final whitelist =="

curl -s "$API/api/whitelist" | jq

echo
echo "API test complete."