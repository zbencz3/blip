import Vapor
import Foundation

/// In-memory rate limiter: 60 requests per minute per secret.
/// Thread-safe via an actor.
actor RateLimitStore {
    private var buckets: [String: [Date]] = [:]
    private let limit: Int
    private let window: TimeInterval

    init(limit: Int = 60, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    /// Returns true if the request is allowed, false if rate limit exceeded.
    func allow(key: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        var timestamps = buckets[key, default: []].filter { $0 > cutoff }
        guard timestamps.count < limit else {
            buckets[key] = timestamps
            return false
        }
        timestamps.append(now)
        buckets[key] = timestamps
        return true
    }
}

struct RateLimitMiddleware: AsyncMiddleware {
    let store: RateLimitStore

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let key: String

        // Extract the secret from the URL path or the Bearer token header.
        if let secret = request.parameters.get("secret"), secret.hasPrefix("bps_") {
            key = secret
        } else if let bearer = request.headers.bearerAuthorization {
            key = bearer.token
        } else {
            // No identifiable key — let the request through (auth will fail it later)
            return try await next.respond(to: request)
        }

        let allowed = await store.allow(key: key)
        guard allowed else {
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Maximum 60 requests per minute per secret.")
        }

        return try await next.respond(to: request)
    }
}
