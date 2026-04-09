import Foundation

@MainActor
@Observable
final class TrialManager {
    private(set) var firstLaunchDate: Date
    private(set) var trialEndDate: Date

    private static let keychainKey = "trial_start_date"
    private let keychain = KeychainService()

    var isTrialActive: Bool {
        Date() < trialEndDate
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate).day ?? 0)
    }

    var trialEndDateFormatted: String {
        trialEndDate.formatted(.dateTime.month(.wide).day().year())
    }

    init() {
        let launch: Date

        // Try Keychain first (survives reinstalls)
        if let saved = keychain.load(key: Self.keychainKey),
           let timestamp = Double(saved) {
            launch = Date(timeIntervalSince1970: timestamp)
        }
        // Migrate from UserDefaults if exists
        else if let saved = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.firstLaunchDate) as? Date {
            launch = saved
            try? keychain.save(String(launch.timeIntervalSince1970), for: Self.keychainKey)
        }
        // First ever launch
        else {
            launch = Date()
            try? keychain.save(String(launch.timeIntervalSince1970), for: Self.keychainKey)
            UserDefaults.standard.set(launch, forKey: Constants.UserDefaultsKeys.firstLaunchDate)
        }

        self.firstLaunchDate = launch
        self.trialEndDate = Calendar.current.date(
            byAdding: .day,
            value: Constants.trialDurationDays,
            to: launch
        ) ?? launch
    }
}
