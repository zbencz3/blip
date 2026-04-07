When completing a long-running background task or when the user might not be watching, send a push notification:

```bash
curl -s -X POST https://bzap-server.fly.dev/v1/bps_usr_5133a3edaa97bc2e2c60ab80dc8ae4a5a65cfcf23678e4988288426f2ecca608 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Claude Code","message":"Done: <brief description>"}'
```

When you need the user's input and they might not be watching the terminal, use the response channel. This sends a push notification and waits for their answer (up to 5 minutes):

```bash
# Yes/No question (default: Approve/Reject buttons)
RESPONSE=$(.claude/scripts/bzap-ask.sh "Deploy to production?")
ACTION=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('action_id',''))")

# Custom buttons
RESPONSE=$(.claude/scripts/bzap-ask.sh "Which environment?" --actions "Staging,Production,Cancel")
ACTION=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('action_id',''))")

# Free-text input
RESPONSE=$(.claude/scripts/bzap-ask.sh "What branch should I deploy?" --text-input "Branch name...")
TEXT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('text',''))")
```

Use the response channel when:
- You need approval before a destructive action (deploy, delete, push)
- You need the user to choose between options
- You need a free-text answer (branch name, commit message, API key name)

Do NOT use it for trivial confirmations — only when you'd otherwise be blocked waiting.
