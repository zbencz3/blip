---
name: Claude Code autonomy levels
description: Six levels of running Claude Code autonomously — from permission skipping to 24/7 VPS loops
type: reference
---

## Level 0.5: Auto mode (recommended)
`--mode auto` or `/mode auto` — Claude makes permission decisions with safeguards.

## Level 1: Skip permission prompts
`claude --dangerously-skip-permissions` — no safeguards.

## Level 2: Context window management
- Use `/clear` between tasks
- Run `/compact` at 60% usage instead of waiting for auto-compaction at 90%

## Level 3: Subagents
- Subagents run in separate context windows
- Build a looping todo command, each task in its own window
- 2+ hours autonomous with zero intervention

## Level 4: Ralph Wiggum loop
- Claude works, tries to exit, a Stop hook blocks exit, re-feeds the same prompt
- Each iteration sees modified files and git history from previous runs
- Use case: batch tasks overnight

## Level 5: Karpathy's AutoResearch
- Define a metric, run, measure, analyze failures, improve, repeat
- Automated experiments

## Level 6: VPS + OpenClaw for 24/7
- Run Claude Code on a VPS inside tmux
- Detach, close laptop, come back tomorrow

## Boris Cherny's Setup (Claude Code creator)
1. **Use the smartest model** — counterintuitively cheaper. Fewer tokens = lower cost.
2. **Invest in CLAUDE.md** — whole team contributes. Every mistake gets added so it never happens again.
3. **Let Claude verify its own output** — let it run code, see results.

Workflow: Start in plan mode -> lock the plan -> auto-accept edits -> done.

## brrr — Push notifications
- Simple POST request sends push notification to all devices — no account needed.
- Zsolt's webhook: `https://api.brrr.now/v1/br_usr_dab89ba5ea712cc6d31ba7ca0f46eecbafa02805642a4d5f683943ce559e3c53`

## Key principles
- **Self-verification:** Give Claude a way to verify its own work (build, tests, lint).
- **Mistake recording:** Every mistake should be recorded so it never happens again.
- **Supply chain security:** Pin dependency versions, use lockfiles, review transitive deps.
