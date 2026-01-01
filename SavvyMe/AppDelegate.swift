import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Route notifications to our custom delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        return true
    }
}
