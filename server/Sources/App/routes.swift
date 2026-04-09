import Vapor

// Shared rate-limit store — one instance per process, covers all notification endpoints.
let rateLimitStore = RateLimitStore()

func routes(_ app: Application) throws {
    app.get { req async in
        "Bzap API is running."
    }

    app.get("health") { req async in
        ["status": "ok"]
    }

    try app.register(collection: DeviceController())
    try app.register(collection: SecretController())

    // Response submit: not rate-limited (called once per notification tap)
    try app.register(collection: ResponseSubmitController())

    let rateLimited = app.grouped(RateLimitMiddleware(store: rateLimitStore))
    try rateLimited.register(collection: NotificationController(apnsService: app.apnsServiceCustom))
    // Response poll: rate-limited
    try rateLimited.register(collection: ResponsePollController())

    try rateLimited.register(collection: MonitorController())

    // Public heartbeat endpoint (no auth, no rate limit)
    try app.register(collection: HeartbeatController())

    // Public status page (no auth, no rate limit)
    try app.register(collection: StatusPageController())
}
