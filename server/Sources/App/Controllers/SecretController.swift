import Fluent
import Vapor

struct SecretController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let secret = routes.grouped("v1", "secret")
        secret.post("rotate", use: rotate)
    }

    @Sendable
    func rotate(req: Request) async throws -> RotateSecretResponse {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header.")
        }
        guard let user = try await User.query(on: req.db)
            .filter(\.$secret == bearer.token)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid secret.")
        }

        let newSecret = SecretGenerator.generate()
        user.secret = newSecret
        try await user.save(on: req.db)

        let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
        return RotateSecretResponse(
            secret: newSecret,
            webhookUrl: "\(baseURL)/v1/\(newSecret)"
        )
    }
}
