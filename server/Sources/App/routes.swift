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

    let rateLimited = app.grouped(RateLimitMiddleware(store: rateLimitStore))
    try rateLimited.register(collection: NotificationController(apnsService: app.apnsServiceCustom))
}
