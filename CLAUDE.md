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

| `actions` | array | Action buttons with response webhooks (max 4) |

**Action object:** `{"id": "deploy", "label": "Deploy to Prod", "webhook": "https://your-ci.com/deploy", "destructive": false}`

**Response:** `200 OK` with `{"message": "Notification sent"}` or appropriate error

### Two-Way Action Buttons

Notifications can include up to 4 action buttons. When tapped, each fires a webhook back. This requires:

1. **Server:** Set `mutable-content: 1` in APNs payload when `actions` are present (triggers Notification Service Extension)
2. **Server:** Set category to `BZAP_DYN_{hash}` where hash is deterministic from sorted action IDs
3. **iOS:** `BzapNotificationService` extension registers the dynamic category before the notification displays
4. **iOS:** `NotificationHandler` fires the action's webhook URL when the user taps a button

**Important:** Category prefixes must match between server and iOS app (`BZAP_DYN_`, `BZAP_GENERAL`, `BZAP_WITH_URL`). A mismatch causes buttons to not appear.

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

# Deploy server to Fly.io
cd server && flyctl deploy --remote-only

# iOS
cd ios && xcodegen generate
cd ios && xcodebuild -project Blip.xcodeproj -scheme Blip -sdk iphonesimulator -destination 'platform=iOS Simulator,id=40323EF0-7B4E-43FB-A939-15B4882384E8' build
cd ios && xcodebuild -project Blip.xcodeproj -scheme BlipTests -sdk iphonesimulator -destination 'platform=iOS Simulator,id=40323EF0-7B4E-43FB-A939-15B4882384E8' test

# Archive + upload to App Store
cd ios && xcodegen generate
xcodebuild -project Blip.xcodeproj -scheme Blip -sdk iphoneos -destination generic/platform=iOS -archivePath /tmp/Bzap.xcarchive archive
xcodebuild -exportArchive -archivePath /tmp/Bzap.xcarchive -exportOptionsPlist /tmp/ExportOptions.plist -exportPath /tmp/BzapExport
xcrun altool --upload-app -f /tmp/BzapExport/Bzap.ipa -t ios --apiKey 2WM4W2XZJ5 --apiIssuer 69a6de70-0922-47e3-e053-5b8c7c11a4d1

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

- English only for v1.0. Localization (en, ro, hu) deferred to post-launch.
- When adding localization later:
  - Hungarian uses family-name-first order — always use a `formatName()` helper
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
