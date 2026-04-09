import Foundation

struct ResponseSubmitter: Sendable {
    static func submit(url urlString: String, actionID: String, text: String?, deviceName: String) async {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "action_id": actionID,
            "device_name": deviceName
        ]
        if let text {
            body["text"] = text
        }
        request.httpBody = try? JSONEncoder().encode(body)
        _ = try? await URLSession.shared.data(for: request)
    }
}
