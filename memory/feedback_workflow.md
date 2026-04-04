---
name: Workflow improvement patterns
description: Preferred Claude Code workflow — auto mode, plan mode for multi-file work, parallel agents, proactive compaction
type: feedback
---

## Active workflow preferences

### 1. Use auto mode instead of manual approvals
`--mode auto` or `/mode auto` for daily work. Safeguards still check each action but stops clicking approve on every file write.

### 2. Use plan mode for multi-file features
Start in plan mode -> lock the plan -> auto-accept edits -> done. Use for any feature with 5+ files to change.

### 3. Run parallel agents aggressively
Use 4-6 parallel agents for any task that can be decomposed: testing multiple routes, auditing multiple concerns, researching multiple topics. Subagents share the prompt cache so 5 agents ~ cost of 1.

### 4. Compact proactively at 60%
Don't wait for auto-compaction at 90%. Run `/compact` at 60% to preserve important context. Use `/clear` between unrelated tasks.

### 5. Record every mistake immediately
When Claude makes a mistake, add it as a feedback memory or CLAUDE.md rule right away. This compounds — fewer mistakes per session over time.

### 6. Send brrr push notifications when work completes
When running background agents or long tasks, send a push notification via brrr when done.
