import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class PushNotificationManager: NSObject {
    private(set) var deviceToken: String?
    private(set) var isRegistered = false
    private(set) var permissionGranted = false

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            self.permissionGranted = granted
            if granted {
                #if canImport(UIKit)
                UIApplication.shared.registerForRemoteNotifications()
                #else
                NSApplication.shared.registerForRemoteNotifications()
                #endif
            }
            return granted
        } catch {
            return false
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        self.isRegistered = true
    }

    func handleRegistrationError(_ error: Error) {
        self.isRegistered = false
    }

    nonisolated static func tokenToHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
