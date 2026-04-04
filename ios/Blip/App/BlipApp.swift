import SwiftUI
import SwiftData
import UserNotifications

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@main
struct BlipApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var secretManager = SecretManager()
    @State private var pushManager = PushNotificationManager()
    @State private var notificationHandler = NotificationHandler()

    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: NotificationRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    private var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(secretManager: secretManager))
                .preferredColorScheme(.dark)
                .task { @MainActor in
                    NotificationCategories.register()
                    _ = await pushManager.requestPermission()
                    appDelegate.pushManager = pushManager

                    notificationHandler.onNotificationReceived = { _ in
                        UserDefaults.standard.set(Date(), forKey: Constants.UserDefaultsKeys.lastPushReceived)
                    }
                    UNUserNotificationCenter.current().delegate = notificationHandler
                    appDelegate.notificationHandler = notificationHandler

                    #if canImport(UIKit)
                    QuickActions.registerShortcuts()
                    #endif
                }
                .onChange(of: pushManager.deviceToken) { _, newToken in
                    guard let token = newToken else { return }
                    Task {
                        _ = try? await APIClient().registerDevice(
                            secret: secretManager.currentSecret,
                            deviceToken: token,
                            deviceName: deviceName
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        MenuBarExtra("Blip", systemImage: "bell.badge.fill") {
            MenuBarView(secretManager: secretManager)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
        #endif
    }
}
