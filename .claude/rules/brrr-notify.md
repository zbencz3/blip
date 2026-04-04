When completing a long-running background task or when the user might not be watching, send a push notification:

```bash
curl -s -X POST https://api.brrr.now/v1/br_usr_dab89ba5ea712cc6d31ba7ca0f46eecbafa02805642a4d5f683943ce559e3c53 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Claude Code","message":"Done: <brief description>"}'
```
