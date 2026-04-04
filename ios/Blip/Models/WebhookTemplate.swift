import SwiftUI

struct WebhookTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String  // SF Symbol name
    let iconColor: Color
    let description: String
    let curlTemplate: String  // uses {{WEBHOOK_URL}} placeholder
    let category: TemplateCategory
}

enum TemplateCategory: String, CaseIterable, Identifiable {
    case cicd = "CI/CD"
    case monitoring = "Monitoring"
    case homeAutomation = "Home"
    case scripting = "Scripts"
    case other = "Other"

    var id: String { rawValue }
}
