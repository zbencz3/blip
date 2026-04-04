import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "Blip API is running."
    }

    app.get("health") { req async in
        ["status": "ok"]
    }

    try app.register(collection: DeviceController())
    try app.register(collection: SecretController())
    try app.register(collection: NotificationController(apnsService: app.apnsServiceCustom))
}
