#!/bin/bash
# bzap-ask.sh — Send a notification and wait for user response
# Usage: bzap-ask.sh "Question?" [--actions "Approve,Reject"] [--text-input "Placeholder..."]
#
# Returns the response JSON to stdout. Exit code 0 if responded, 1 if expired.

SECRET="bps_usr_5133a3edaa97bc2e2c60ab80dc8ae4a5a65cfcf23678e4988288426f2ecca608"
BASE_URL="https://bzap-server.fly.dev/v1"
POLL_INTERVAL=3
MAX_WAIT=300  # 5 minutes

MESSAGE="$1"
shift

# Parse optional flags
ACTIONS='[{"id":"approve","label":"Approve","response_channel":true},{"id":"reject","label":"Reject","response_channel":true,"destructive":true}]'
while [[ $# -gt 0 ]]; do
  case "$1" in
    --actions)
      # Comma-separated labels: "Approve,Reject,Maybe"
      IFS=',' read -ra LABELS <<< "$2"
      ACTIONS="["
      for i in "${!LABELS[@]}"; do
        LABEL="${LABELS[$i]}"
        ID=$(echo "$LABEL" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
        [ $i -gt 0 ] && ACTIONS+=","
        ACTIONS+="{\"id\":\"$ID\",\"label\":\"$LABEL\",\"response_channel\":true}"
      done
      ACTIONS+="]"
      shift 2
      ;;
    --text-input)
      PLACEHOLDER="${2:-Type your response...}"
      ACTIONS='[{"id":"reply","label":"Reply","type":"text_input","text_input_placeholder":"'"$PLACEHOLDER"'","response_channel":true},{"id":"cancel","label":"Cancel","response_channel":true,"destructive":true}]'
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Send notification
RESPONSE=$(curl -s -X POST "$BASE_URL/$SECRET" \
  -H 'Content-Type: application/json' \
  -d "{
    \"title\": \"Claude Code\",
    \"message\": \"$MESSAGE\",
    \"actions\": $ACTIONS
  }")

RESPONSE_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response_id',''))" 2>/dev/null)

if [ -z "$RESPONSE_ID" ]; then
  echo "Failed to send notification: $RESPONSE" >&2
  exit 1
fi

# Poll for response
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  POLL=$(curl -s "$BASE_URL/responses/$RESPONSE_ID" \
    -H "Authorization: Bearer $SECRET")

  STATUS=$(echo "$POLL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

  if [ "$STATUS" = "responded" ]; then
    echo "$POLL"
    exit 0
  fi

  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo '{"status":"expired"}'
exit 1
