import SwiftUI
import SwiftData
import UserNotifications

@main
struct BlipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
        UIDevice.current.name
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
                        // Save to notification history (dedup by request identifier)
                        let content = notification.request.content
                        let requestID = notification.request.identifier
                        let context = ModelContext(sharedModelContainer)
                        // Check if already saved (foreground willPresent + didReceive)
                        let descriptor = FetchDescriptor<NotificationRecord>(
                            predicate: #Predicate { $0.requestIdentifier == requestID }
                        )
                        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }
                        let record = NotificationRecord(
                            requestIdentifier: requestID,
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

                    // Always re-register device on launch (handles server data loss)
                    if let savedToken = UserDefaults.standard.string(forKey: "device_token") {
                        _ = try? await APIClient().registerDevice(
                            secret: secretManager.currentSecret,
                            deviceToken: savedToken,
                            deviceName: deviceName
                        )
                    }
                }
                .onChange(of: pushManager.deviceToken) { _, newToken in
                    guard let token = newToken else { return }
                    Task {
                        // Always register on token change + save token for widget
                        _ = try? await APIClient().registerDevice(
                            secret: secretManager.currentSecret,
                            deviceToken: token,
                            deviceName: deviceName
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
