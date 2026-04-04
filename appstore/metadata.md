# Bzap — App Store Metadata

## App Name
Bzap

## Subtitle (30 chars max)
Push Notifications via Webhook

## Promotional Text (170 chars, can be updated without review)
Send push notifications to your devices with a simple HTTP request. Two-way action buttons, Siri Shortcuts, templates for GitHub, Docker, Home Assistant & more.

## Description (4000 chars max)
Bzap turns a simple webhook into a push notification on your iPhone, iPad, or Mac. No signup, no dashboard — just an HTTP POST.

SIMPLE BY DESIGN
Install Bzap, copy your webhook URL, and paste it into your script, CI pipeline, or home automation. That's it. Your first notification is one curl command away.

TWO-WAY ACTION BUTTONS
Unlike other push apps, Bzap notifications can include action buttons that fire webhooks back. Get a "Motion Detected" alert and tap "Turn On Lights" — Bzap sends the command to your Home Assistant without opening any app.

BUILT FOR DEVELOPERS
• 10+ ready-to-paste templates for GitHub Actions, Docker, Python, Node.js, cron jobs, Uptime Kuma, Home Assistant, and more
• Siri Shortcuts integration — "Hey Siri, send a Bzap"
• QR code sharing for webhook URLs
• Full-text search across notification history
• Export history as JSON or CSV
• Per-device webhooks to target specific devices

PRIVACY FIRST
Your notification content is never stored on our server. Messages pass through and are forwarded to Apple's push service immediately. On-device history stays on your device. You control how long it's kept.

WORKS EVERYWHERE
• iPhone, iPad, and Mac — native app, not a web wrapper
• Mac menu bar app for quick access
• Home screen Quick Actions
• Any language, any platform: if it can make an HTTP request, it can send you a Bzap

USE CASES
• CI/CD alerts: know when builds pass, deploys finish, or tests fail
• Server monitoring: uptime checks, error spikes, disk warnings
• Home automation: motion alerts, leak detection, temperature drops
• AI coding: get notified when Claude Code or Copilot finishes a task
• Cron jobs: long-running scripts, backups, data exports
• Anything with HTTP: Zapier, IFTTT, n8n, custom scripts

API
POST a JSON body to your webhook URL with title, message, sound, image, and optional action buttons. Full API docs at our website.

## Keywords (100 chars max, comma-separated)
webhook,push,notification,api,developer,devops,ci,home,automation,monitor,alert,curl,siri,shortcut

## Category
Primary: Developer Tools
Secondary: Utilities

## Age Rating
4+

## Price
Free

## In-App Purchases (stubbed — add later)
- Bzap Monthly: $0.99/month
- Bzap Yearly: $9.99/year

## URLs
- Support URL: https://zbencz3.github.io/bzap/
- Marketing URL: https://zbencz3.github.io/bzap/
- Privacy Policy URL: https://zbencz3.github.io/bzap/privacy.html

## Copyright
© 2026 iSylva

## Contact
support@isylva.com

## App Review Notes
This app requires a backend server to function. The server receives webhook HTTP requests and forwards them as Apple Push Notifications. No login or account creation is required — the app generates a unique webhook secret on first launch. For testing: the app can be tested by running the included Vapor server locally (see SETUP.md in the repository).
