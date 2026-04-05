import Foundation

@MainActor
@Observable
final class TrialManager {
    private(set) var firstLaunchDate: Date
    private(set) var trialEndDate: Date

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
        let defaults = UserDefaults.standard
        let launch: Date
        if let saved = defaults.object(forKey: Constants.UserDefaultsKeys.firstLaunchDate) as? Date {
            launch = saved
        } else {
            launch = Date()
            defaults.set(launch, forKey: Constants.UserDefaultsKeys.firstLaunchDate)
        }
        self.firstLaunchDate = launch
        self.trialEndDate = Calendar.current.date(
            byAdding: .day,
            value: Constants.trialDurationDays,
            to: launch
        ) ?? launch
    }
}
