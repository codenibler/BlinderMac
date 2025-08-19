import UserNotifications

enum Notifier {
    private static let queue = DispatchQueue(label: "focus.notifier.throttle")
    private static var lastFire: Date = .distantPast
    private static let minInterval: TimeInterval = 10

    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = Delegate.shared
    }

    static func remindFocusOn(modeName: String) {
        queue.async {
            let now = Date()
            guard now.timeIntervalSince(lastFire) >= minInterval else { return }
            lastFire = now

            let c = UNMutableNotificationContent()
            c.title = "Remember"
            c.body  = "\(modeName) is on!"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: trigger)
            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }
    }

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        static let shared = Delegate()
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .list, .sound]) // show while app is frontmost
        }
    }
}
