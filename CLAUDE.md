# CLAUDE.md — brr (brrr clone)

## Project Goal

Build a clone of **brrr** (https://brrr.now by Simon Støvring) — a simple push notification relay service. The project has two components:

1. **Backend API** — receives webhook POST requests and forwards them as APNs push notifications
2. **iOS app** — registers for push notifications, generates webhook URLs, displays notification history

### How it works
- No signup/login required. The app generates a webhook URL with an embedded secret
- Anyone with the webhook URL can POST to it to send a push notification to the user's devices
- Messages are NOT stored on the backend — notification history is on-device only
- Supports shared webhooks (all devices) and device-specific webhooks
- Secret can be rotated (generates new webhook URL)

### API Specification

**Base URL:** `https://api.<domain>/v1/`

**Two ways to authenticate:**

1. Secret in URL: `POST /v1/{secret}` with JSON body
2. Bearer token: `POST /v1/send` with `Authorization: Bearer {secret}` header

**JSON payload fields:**

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Notification title |
| `subtitle` | string | Subtitle line |
| `message` | string | Body text (also accepted as plain text body) |
| `thread_id` | string | Group notifications by thread |
| `sound` | string | Notification sound (see list below) |
| `open_url` | string | URL to open when notification is tapped |
| `image_url` | string | Image to show in notification |
| `expiration_date` | string | ISO 8601 date after which notification won't be delivered |
| `filter_criteria` | string | Custom filter for automation |
| `interruption_level` | string | `passive`, `active` (default), `time-sensitive` |

**Sounds:** `default`, `system`, `brrr`, `bell_ringing`, `bubble_ding`, `bubbly_success_ding`, `cat_meow`, `calm1`, `calm2`, `cha_ching`, `dog_barking`, `door_bell`, `duck_quack`, `short_triple_blink`, `upbeat_bells`, `warm_soft_error`

**Response:** `200 OK` with `{"message": "Notification sent"}` or appropriate error

### iOS App Screens (from screenshots)

1. **Home** — "Welcome to brr" hero, curl command snippet with Copy/Share buttons, "Read docs" link, free trial banner
2. **Settings** — Subscription, Webhooks, Documentation, Guides, Send Test, Notification Settings (opens system settings), About
3. **Subscription** — Monthly/Yearly plans via StoreKit, Manage/Redeem Code menu
4. **Webhooks** — "Send to All Devices" webhook with curl snippet, Copy/Share/menu, last-used timestamp. "Send to a Single Device" section listing registered devices with per-device webhooks
5. **Device webhook popup** — shows device-specific webhook URL and curl command
6. **Recent Notifications** — on-device history grouped by date, retention setting (Keep for 1 month), trash button to clear all
7. **About** — version number, app icon, credits

### Design Language
- Dark theme (primary), dark gray cards on black background
- Accent colors: purple (brand/headings), green/lime (primary buttons like Copy), white (secondary buttons like Share)
- SF Symbols for icons
- Rounded card UI with subtle borders
- Code snippets in monospace on dark cards

## Key Commands

```bash
# Server (Swift/Vapor)
cd server && swift build
cd server && swift test

# iOS
cd ios && xcodegen generate
cd ios && xcodebuild -project Blip.xcodeproj -scheme Blip -sdk iphonesimulator -destination 'platform=iOS Simulator,id=40323EF0-7B4E-43FB-A939-15B4882384E8' build
cd ios && xcodebuild -project Blip.xcodeproj -scheme BlipTests -sdk iphonesimulator -destination 'platform=iOS Simulator,id=40323EF0-7B4E-43FB-A939-15B4882384E8' test

# Run server locally
cd server && swift run
```

## Pre-Commit Gate

**Always** build + run tests before committing. Never skip this, never use `--no-verify`. If either fails, fix the issue before committing.

## Commit Convention

Use conventional commits: `feat|fix|refactor|chore|docs|test: short description`

Keep commits small and focused — one concern per commit.

## Push Policy

**Batch pushes** — commit freely with `--no-verify` during work sessions, then push once when a batch is ready. Ask user before pushing.

## File Size Limit

Target ~500 lines per file. When touching a file over 500 LOC, split out the section being modified.

## Testing Discipline

Write or update tests in the same commit as the feature, especially for:
- API endpoints (request/response, validation)
- Business logic (webhook routing, secret generation, APNs payload building)
- SwiftUI view models

## Blast Radius

- Prefer small, focused changes over large multi-file rewrites
- Don't refactor surrounding code when fixing a bug
- Don't add features beyond what was requested
- No over-engineering: three similar lines > premature abstraction

## i18n & Localization

- Three locales: en, ro, hu
- Hungarian uses family-name-first order — always use a `formatName()` helper
- Never hardcode English strings in UI — use localization system
- Romanian: formal/polite form (dvs.), not informal (tu)

## Verification Before Commit

Before committing, always verify:
1. Build succeeds (both iOS and server)
2. Tests pass
3. New UI changes checked on simulator if available
4. Localization keys added to ALL 3 locale files (en/ro/hu)

Use `--no-verify` only during rapid iteration. Run full verification before the final batch commit.

## When Things Go Wrong

If a bug is found:
1. Fix the bug
2. Add a test that would have caught it
3. If it reveals a pattern, check everywhere for the same issue
4. Add a rule to CLAUDE.md if it's a recurring pattern

## Session Learnings

Before a session ends, context compresses, or the user says goodbye:
1. Save any new learnings, decisions, or patterns to the memory directory
2. Update MEMORY.md index if new files were created
3. Update CLAUDE.md if new development rules were discovered
4. Commit any uncommitted work (with `--no-verify`)
5. Remind the user about unpushed commits

## Parallel Agents

Use subagents for independent work — they share the prompt cache so 5 agents ~ cost of 1.

**Model selection per agent:**
- `model: "haiku"` — simple file searches, grep-like lookups
- `model: "sonnet"` — code exploration, summarizing modules
- Default (Opus, inherited) — complex analysis, planning, code review

## Context Management

- Use `/compact` proactively before context gets too large
- Prefer `--continue` to resume sessions
- Interrupt (Escape) freely if a response is going wrong
