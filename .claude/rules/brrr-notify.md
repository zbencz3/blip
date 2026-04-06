When completing a long-running background task or when the user might not be watching, send a push notification:

```bash
curl -s -X POST https://bzap-server.fly.dev/v1/bps_usr_5133a3edaa97bc2e2c60ab80dc8ae4a5a65cfcf23678e4988288426f2ecca608 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Claude Code","message":"Done: <brief description>"}'
```
