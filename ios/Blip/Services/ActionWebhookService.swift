import Foundation

struct ActionWebhookService: Sendable {
    static func fire(url urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["status": "action_taken"])
        _ = try? await URLSession.shared.data(for: request)
    }
}
