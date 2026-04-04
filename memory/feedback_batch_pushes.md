---
name: Batch git pushes to save build costs
description: Each git push may trigger CI/CD builds. Batch commits and push once per work session.
type: feedback
---

Each `git push` may trigger CI/CD builds or deploys that cost money.

**Why:** Build minutes add up fast with frequent pushes.

**How to apply:**
- Commit freely with `--no-verify` during active work
- Push once when a batch of changes is complete (not after every commit)
- Aim for 3-5 pushes per work session, not 30-60
- Run build + tests locally before the final push
- Always ask user before pushing
