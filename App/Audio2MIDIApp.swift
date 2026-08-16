import Audio2MIDICore
import SwiftUI
import UserNotifications

@main
struct Audio2MIDIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.make()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(StudioColor.blue)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(
            name: .didRegisterForPush,
            object: deviceToken.map { String(format: "%02x", $0) }.joined()
        )
    }
}

extension Notification.Name {
    static let didRegisterForPush = Notification.Name("didRegisterForPush")
}

