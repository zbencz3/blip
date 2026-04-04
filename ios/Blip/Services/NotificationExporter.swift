import Foundation

enum ExportFormat {
    case json, csv
}

struct NotificationExporter {
    static func export(_ records: [NotificationRecord], format: ExportFormat) -> String {
        switch format {
        case .json: return exportJSON(records)
        case .csv: return exportCSV(records)
        }
    }

    // MARK: - JSON

    private static func exportJSON(_ records: [NotificationRecord]) -> String {
        let dicts: [[String: String]] = records.map { record in
            var dict: [String: String] = [
                "id": record.id.uuidString,
                "receivedAt": ISO8601DateFormatter().string(from: record.receivedAt)
            ]
            if let title = record.title { dict["title"] = title }
            if let subtitle = record.subtitle { dict["subtitle"] = subtitle }
            if let message = record.message { dict["message"] = message }
            if let threadId = record.threadId { dict["threadId"] = threadId }
            if let openURL = record.openURL { dict["openURL"] = openURL }
            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    // MARK: - CSV

    private static func exportCSV(_ records: [NotificationRecord]) -> String {
        let header = "id,receivedAt,title,subtitle,message,threadId,openURL"
        let formatter = ISO8601DateFormatter()
        let rows = records.map { record in
            [
                record.id.uuidString,
                formatter.string(from: record.receivedAt),
                csvEscape(record.title),
                csvEscape(record.subtitle),
                csvEscape(record.message),
                csvEscape(record.threadId),
                csvEscape(record.openURL)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func csvEscape(_ value: String?) -> String {
        guard let value else { return "" }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
