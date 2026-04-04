---
name: Bug fixes only — no feature work disguised as bugs
description: When working on user-reported issues, only fix actual bugs. Feature requests should be deferred.
type: feedback
---

When a user reports an issue, only fix it if it's an actual bug (something broken, crashes, returns wrong data, or doesn't work as designed).

Do NOT implement:
- Feature requests reported as "bugs"
- UX improvements
- New functionality

**Why:** Every feature addition adds maintenance burden, test surface, and potential for new bugs. Keep scope tight and only fix what's actually broken.

**How to apply:** When triaging issues, check if the issue describes broken behavior vs desired behavior. If it's a feature request, label it `enhancement` and don't implement it. Direct requests from the project owner can include features.
