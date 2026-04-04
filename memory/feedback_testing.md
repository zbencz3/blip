---
name: Testing preferences
description: User preferences for testing approach — test with feature, run locally, CI may be disabled
type: feedback
---

- Write or update tests in the same commit as the feature
- Always build + run tests before committing
- Never use `--no-verify` for final commits
- GitHub Actions CI may be disabled to save billing — run all tests locally instead
- This is mandatory — do not skip local test runs after significant work
- Use parallel agents for running tests while working on features
