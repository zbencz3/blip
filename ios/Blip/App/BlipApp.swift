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
    @State private var trialManager = TrialManager()
    @State private var showSplash = true

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
            ZStack {
                HomeView(viewModel: HomeViewModel(secretManager: secretManager), trialManager: trialManager)
                if showSplash {
                    SplashView(isActive: $showSplash)
                }
            }
                .preferredColorScheme(.dark)
                .task { @MainActor in
                    NotificationCategories.register()
                    _ = await pushManager.requestPermission()
                    appDelegate.pushManager = pushManager

                    notificationHandler.onNotificationReceived = { [sharedModelContainer] notification in
                        UserDefaults.standard.set(Date(), forKey: Constants.UserDefaultsKeys.lastPushReceived)
                        // Save to notification history
                        let content = notification.request.content
                        let context = ModelContext(sharedModelContainer)
                        let record = NotificationRecord(
                            title: content.title.isEmpty ? nil : content.title,
                            subtitle: content.subtitle.isEmpty ? nil : content.subtitle,
                            message: content.body.isEmpty ? nil : content.body,
                            threadId: content.threadIdentifier.isEmpty ? nil : content.threadIdentifier,
                            openURL: content.userInfo["open_url"] as? String
                        )
                        context.insert(record)
                        try? context.save()
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
