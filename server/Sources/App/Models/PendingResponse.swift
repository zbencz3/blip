import Fluent
import Vapor

final class PendingResponse: Model, Content, @unchecked Sendable {
    static let schema = "pending_responses"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "status") var status: String
    @OptionalField(key: "action_id") var actionID: String?
    @OptionalField(key: "text") var text: String?
    @OptionalField(key: "device_name") var deviceName: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @OptionalField(key: "responded_at") var respondedAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, status: String = "pending") {
        self.id = id
        self.$user.id = userID
        self.status = status
    }
}
