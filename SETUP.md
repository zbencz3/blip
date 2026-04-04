# Bzap — Setup Guide

Bzap is a push-notification relay service: the iOS app registers devices and generates webhook URLs; anyone who POSTs to those URLs gets a push notification on your device. No accounts, no servers to babysit (beyond one tiny Fly.io machine).

---

## 1. Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 16+ | App Store |
| Swift | 6.0+ | Bundled with Xcode |
| xcodegen | any | `brew install xcodegen` |
| flyctl | any | `brew install flyctl` |
| Docker | any | [docker.com](https://docker.com) (only for local container testing) |

Check you have everything:

```bash
swift --version       # should print Swift 6.x
xcodegen --version
flyctl version
```

---

## 2. Quick Start

### Server (< 2 minutes)

```bash
cd /path/to/brr/server

# Copy and fill in env vars (APNs not required locally — mock is used automatically)
cp .env.example .env

# Build and run
swift run App serve --env development --hostname 0.0.0.0 --port 8080
```

The server starts on `http://localhost:8080`. Without APNs credentials it uses a mock that logs sends to the console — useful for UI work.

Verify it's up:

```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

### iOS (< 3 minutes)

```bash
cd /path/to/brr/ios

# Generate the Xcode project from project.yml
xcodegen generate

# Open in Xcode
open Blip.xcodeproj
```

In Xcode: select the **Blip** scheme, choose an iPhone 16 simulator, hit Run. The app launches pointing at `http://localhost:8080` by default.

> **Note:** Push notifications do not work in the simulator. Use a physical device for end-to-end testing (see section 5).

---

## 3. Apple Developer Setup

You need an active Apple Developer account ($99/year).

### 3a. Create an App ID with Push Notifications

1. Log in to [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles → Identifiers.
2. Click **+** → App IDs → App.
3. Set the Bundle ID to `com.isylva.bzap` (or your own — keep it consistent with `project.yml`).
4. Under Capabilities, tick **Push Notifications**.
5. Save.

### 3b. Create an APNs Auth Key (.p8)

This is a single key that works for all your apps — you only need one.

1. Certificates, IDs & Profiles → **Keys** → **+**.
2. Name it (e.g. "Bzap APNs Key"), tick **Apple Push Notifications service (APNs)**.
3. Register → Download the `.p8` file. **Store it safely — Apple will not let you download it again.**
4. Note the **Key ID** (10 characters) shown on the key detail page.
5. Note your **Team ID** from the top-right of the developer portal (also 10 characters).

### 3c. Create a Provisioning Profile

1. Profiles → **+** → iOS App Development.
2. Select your App ID (`com.isylva.bzap`).
3. Select your certificate and test devices.
4. Download and double-click to install.

---

## 4. Server Configuration

### Environment Variables

Copy `.env.example` to `.env` in the `server/` directory and fill in:

| Variable | Required | Description |
|----------|----------|-------------|
| `APNS_KEY_PATH` | Yes (prod) | Absolute path to your `.p8` file, e.g. `/secrets/AuthKey_XXXXXXXXXX.p8` |
| `APNS_KEY_ID` | Yes (prod) | 10-char Key ID from Apple Developer portal |
| `APNS_TEAM_ID` | Yes (prod) | 10-char Team ID from Apple Developer portal |
| `APNS_TOPIC` | Yes (prod) | Bundle ID of the iOS app: `com.isylva.bzap` |
| `LOG_LEVEL` | No | `debug` locally, `info` in production |
| `APP_ENV` | No | `development` locally, `production` on Fly.io |
| `BASE_URL` | No | Public base URL used in webhook responses, e.g. `https://api.yourdomain.com` |

> `APNS_PRIVATE_KEY` (the raw PEM string) in `.env.example` is an alternative to `APNS_KEY_PATH`. `configure.swift` currently reads `APNS_KEY_PATH` from disk — use that locally and set it as a Fly.io secret pointing to the mounted file path.

### Database

SQLite is used by default — no setup needed. A `db.sqlite` file is created automatically in the working directory on first run. The schema is migrated automatically at startup via `autoMigrate()`.

For production on Fly.io the SQLite file lives on a persistent volume (see section 6).

---

## 5. iOS Configuration

### Bundle ID

The bundle ID is set in `ios/project.yml`:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.isylva.bzap
```

Change this to match your App ID if you used a different one.

After changing `project.yml`, regenerate the project:

```bash
cd ios && xcodegen generate
```

### Signing

1. Open `Blip.xcodeproj` in Xcode.
2. Select the **Blip** target → Signing & Capabilities.
3. Tick **Automatically manage signing**, select your team.
4. Xcode will fetch the provisioning profile automatically.

### Push Notification Capability

`project.yml` already configures the entitlement:

```yaml
entitlements:
  path: Blip/Blip.entitlements
  properties:
    aps-environment: development
```

Change `development` to `production` before submitting to the App Store or using a production APNs environment.

### Point the App at Your Server

Edit `ios/Blip/Utilities/Constants.swift`:

```swift
static let baseURL = "https://api.yourdomain.com"   // change this
```

Rebuild and run on device.

---

## 6. Deployment (Fly.io)

### One-time Setup

```bash
# Install flyctl and log in
brew install flyctl
fly auth login

# Launch the app (from the server/ directory)
cd server
fly launch --name bzap-server --region iad --no-deploy

# Create a persistent volume for the SQLite database
fly volumes create bzap_data --size 1 --region iad

# Mount it — add this to fly.toml under [mounts]:
```

Add to `server/fly.toml`:

```toml
[[mounts]]
  source      = "bzap_data"
  destination = "/data"
```

Update `configure.swift` to store the DB on the volume:

```swift
app.databases.use(.sqlite(.file("/data/db.sqlite")), as: .sqlite)
```

### Set Secrets

```bash
# Upload your .p8 file as a Fly.io secret (read it inline)
fly secrets set APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXXXXXXX.p8)"
fly secrets set APNS_KEY_ID=XXXXXXXXXX
fly secrets set APNS_TEAM_ID=XXXXXXXXXX
fly secrets set APNS_TOPIC=com.isylva.bzap
fly secrets set BASE_URL=https://api.yourdomain.com
fly secrets set LOG_LEVEL=info
```

> Alternatively, mount the `.p8` file as a Fly.io secret file and set `APNS_KEY_PATH` to its path — that avoids embedding the key in an env var.

### Deploy

```bash
cd server
fly deploy
```

Watch logs:

```bash
fly logs
```

### Custom Domain (optional)

```bash
fly certs add api.yourdomain.com
```

Then point a DNS CNAME at the printed Fly.io hostname. HTTPS is enforced automatically (`force_https = true` in `fly.toml`).

---

## 7. Going Live Checklist

Before shipping to TestFlight / the App Store:

- [ ] `Constants.baseURL` points to your production server (not `localhost`)
- [ ] `aps-environment` in `project.yml` is set to `production`
- [ ] All Fly.io secrets are set (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, `BASE_URL`, key material)
- [ ] SQLite volume is mounted and `configure.swift` uses `/data/db.sqlite`
- [ ] `fly.toml` has `force_https = true` (already the default)
- [ ] APNs production environment is used — Vapor sets this automatically when `app.environment == .production`
- [ ] Bundle ID and provisioning profile match between `project.yml` and the Apple Developer portal
- [ ] `APP_ENV=production` is set on Fly.io (or pass `--env production` in the Dockerfile entrypoint — already done)
- [ ] `LOG_LEVEL=info` or `warning` in production (not `debug`)
- [ ] Run the full test suite and fix any failures before submitting

---

## 8. Project Structure

```
brr/
├── Makefile                  # Top-level convenience targets (build, test, deploy)
├── CLAUDE.md                 # AI assistant instructions and project spec
├── server/                   # Vapor (Swift) backend
│   ├── Package.swift         # Dependencies: Vapor, Fluent, SQLite, VaporAPNS
│   ├── fly.toml              # Fly.io config (region, machine size, HTTPS)
│   ├── Dockerfile            # Two-stage build: swift:6.0 → ubuntu:22.04
│   ├── .env.example          # Template for local env vars
│   └── Sources/App/
│       ├── entrypoint.swift  # Swift entry point
│       ├── configure.swift   # DB, APNs, and route setup
│       ├── routes.swift      # Route registration
│       ├── Controllers/      # HTTP handlers (Device, Notification, Secret)
│       ├── Models/           # Fluent ORM models (User, DeviceRegistration)
│       ├── Migrations/       # DB schema migrations
│       ├── DTOs/             # Codable request/response structs
│       ├── Services/         # APNs abstraction (Live + Mock)
│       └── Utilities/        # SecretGenerator
└── ios/                      # SwiftUI iOS/macOS app
    ├── project.yml           # XcodeGen spec (targets, bundle ID, entitlements)
    └── Blip/
        ├── App/              # Entry point, AppDelegate (push token handling)
        ├── Views/            # SwiftUI screens
        ├── ViewModels/       # Observable state for each screen
        ├── Services/         # APIClient, PushNotificationManager, SecretManager
        ├── Models/           # NotificationRecord, Device, WebhookTemplate
        ├── Storage/          # NotificationStore (on-device history)
        ├── Utilities/        # Constants (baseURL, keychain keys)
        └── Theme/            # BlipColors, BlipFonts
```

---

## 9. Testing

### Server

```bash
cd server
swift test
```

Or via Make:

```bash
make test-server
```

Tests live in `server/Tests/AppTests/`. They use `XCTVapor` with the mock APNs service, so no Apple credentials are needed.

### iOS

```bash
make test-ios
# Equivalent to:
cd ios && xcodebuild -project Blip.xcodeproj -scheme Blip \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Tests live in `ios/BlipTests/`.

### Both

```bash
make all        # build only
make test-server && make test-ios
```

---

## 10. API Reference

**Base URL:** `http://localhost:8080` (dev) / `https://api.yourdomain.com` (prod)

### Health Check

```bash
curl https://api.yourdomain.com/health
# {"status":"ok"}
```

### Register a Device

Called automatically by the iOS app on launch.

```bash
curl -X POST https://api.yourdomain.com/v1/devices/register \
  -H 'Content-Type: application/json' \
  -d '{
    "secret": "bps_usr_<your-secret>",
    "device_token": "<APNs-device-token>",
    "device_name": "My iPhone"
  }'
```

Response:

```json
{
  "id": "uuid",
  "device_name": "My iPhone",
  "device_secret": "bps_usr_<device-specific-secret>",
  "created_at": "2026-04-04T12:00:00Z"
}
```

### List Devices

```bash
curl https://api.yourdomain.com/v1/devices \
  -H 'Authorization: Bearer bps_usr_<your-secret>'
```

### Delete a Device

```bash
curl -X DELETE https://api.yourdomain.com/v1/devices/<device-uuid> \
  -H 'Authorization: Bearer bps_usr_<your-secret>'
```

### Send a Notification — Secret in URL

```bash
curl -X POST https://api.yourdomain.com/v1/bps_usr_<your-secret> \
  -H 'Content-Type: application/json' \
  -d '{"title": "Hello", "message": "World"}'
```

### Send a Notification — Bearer Token

```bash
curl -X POST https://api.yourdomain.com/v1/send \
  -H 'Authorization: Bearer bps_usr_<your-secret>' \
  -H 'Content-Type: application/json' \
  -d '{"title": "Hello", "message": "World"}'
```

### Send a Plain-Text Notification

```bash
curl -X POST https://api.yourdomain.com/v1/bps_usr_<your-secret> \
  -H 'Content-Type: text/plain' \
  -d 'Hello from curl'
```

### Full Payload Example

```bash
curl -X POST https://api.yourdomain.com/v1/bps_usr_<your-secret> \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Build failed",
    "subtitle": "main branch",
    "message": "3 tests failed",
    "thread_id": "ci",
    "sound": "warm_soft_error",
    "open_url": "https://github.com/you/repo/actions",
    "interruption_level": "time-sensitive"
  }'
```

**All payload fields:**

| Field | Type | Notes |
|-------|------|-------|
| `title` | string | Notification title |
| `subtitle` | string | Second line |
| `message` | string | Body text |
| `thread_id` | string | Groups notifications together |
| `sound` | string | See sounds list below |
| `open_url` | string | URL opened on tap |
| `image_url` | string | Attachment image |
| `expiration_date` | string | ISO 8601; drop if expired |
| `filter_criteria` | string | Custom automation tag |
| `interruption_level` | string | `passive`, `active` (default), `time-sensitive` |

**Sounds:** `default`, `system`, `brrr`, `bell_ringing`, `bubble_ding`, `bubbly_success_ding`, `cat_meow`, `calm1`, `calm2`, `cha_ching`, `dog_barking`, `door_bell`, `duck_quack`, `short_triple_blink`, `upbeat_bells`, `warm_soft_error`

### Rotate Webhook Secret

Invalidates the old secret and returns a new one with a fresh webhook URL.

```bash
curl -X POST https://api.yourdomain.com/v1/secret/rotate \
  -H 'Authorization: Bearer bps_usr_<current-secret>'
```

Response:

```json
{
  "secret": "bps_usr_<new-secret>",
  "webhook_url": "https://api.yourdomain.com/v1/bps_usr_<new-secret>"
}
```

**All responses use HTTP 200 on success** with `{"message": "Notification sent"}`, or a JSON error body with the appropriate HTTP status code on failure.
