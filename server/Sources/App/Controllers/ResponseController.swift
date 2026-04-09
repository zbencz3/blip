import Fluent
import Vapor

struct ResponseSubmitController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let responses = routes.grouped("v1", "responses")
        responses.post(":responseID", use: submit)
    }

    @Sendable
    func submit(req: Request) async throws -> Response {
        guard let responseIDString = req.parameters.get("responseID"),
              let responseID = UUID(uuidString: responseIDString) else {
            throw Abort(.badRequest, reason: "Invalid response ID.")
        }

        let submission = try req.content.decode(ResponseSubmission.self)

        guard let pending = try await PendingResponse.find(responseID, on: req.db) else {
            throw Abort(.notFound, reason: "Response not found.")
        }

        guard pending.status == "pending" else {
            throw Abort(.conflict, reason: "Response already submitted.")
        }

        pending.actionID = submission.actionID
        pending.text = submission.text
        pending.deviceName = submission.deviceName
        pending.status = "responded"
        pending.respondedAt = Date()
        try await pending.save(on: req.db)

        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(string: #"{"status":"ok"}"#)
        )
    }
}

struct ResponsePollController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let responses = routes.grouped("v1", "responses")
        responses.get(":responseID", use: poll)
    }

    @Sendable
    func poll(req: Request) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header.")
        }

        guard let user = try await User.query(on: req.db)
            .filter(\.$secret == bearer.token)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid secret.")
        }

        guard let responseIDString = req.parameters.get("responseID"),
              let responseID = UUID(uuidString: responseIDString) else {
            throw Abort(.badRequest, reason: "Invalid response ID.")
        }

        guard let pending = try await PendingResponse.find(responseID, on: req.db) else {
            throw Abort(.notFound, reason: "Response not found.")
        }

        guard pending.$user.id == user.id else {
            throw Abort(.notFound, reason: "Response not found.")
        }

        if pending.status == "pending" {
            let pollResponse = PollResponse(
                status: "pending",
                actionID: nil,
                text: nil,
                deviceName: nil,
                respondedAt: nil
            )
            let response = Response(status: .accepted)
            try response.content.encode(pollResponse)
            return response
        }

        let pollResponse = PollResponse(
            status: pending.status,
            actionID: pending.actionID,
            text: pending.text,
            deviceName: pending.deviceName,
            respondedAt: pending.respondedAt
        )

        // Delete the row after reading
        try await pending.delete(on: req.db)

        let response = Response(status: .ok)
        try response.content.encode(pollResponse)
        return response
    }
}
