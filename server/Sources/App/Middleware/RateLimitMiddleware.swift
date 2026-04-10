import Vapor
import Foundation

/// In-memory rate limiter: 60 requests per minute per secret.
/// Thread-safe via an actor. Periodically evicts stale buckets.
actor RateLimitStore {
    private var buckets: [String: [TimeInterval]] = [:]
    private let limit: Int
    private let window: TimeInterval
    private var lastCleanup: TimeInterval = 0

    init(limit: Int = 60, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
        self.lastCleanup = Date().timeIntervalSince1970
    }

    /// Returns true if the request is allowed, false if rate limit exceeded.
    func allow(key: String) -> Bool {
        let now = Date().timeIntervalSince1970
        let cutoff = now - window

        var timestamps = buckets[key, default: []].filter { $0 > cutoff }
        guard timestamps.count < limit else {
            buckets[key] = timestamps
            return false
        }
        timestamps.append(now)
        buckets[key] = timestamps

        // Periodic cleanup: evict empty/stale buckets every 5 minutes
        if now - lastCleanup > 300 {
            lastCleanup = now
            buckets = buckets.filter { !$0.value.isEmpty && $0.value.contains(where: { $0 > cutoff }) }
        }

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
