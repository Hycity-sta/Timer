import Foundation
import UserNotifications
import AppKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let categoryIdentifier = "TIMER_FINISHED_CATEGORY"
    static let openActionIdentifier = "TIMER_OPEN_ACTION"

    private override init() {
        super.init()
    }

    /// 初始化并请求系统通知权限
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 注册交互动作（打开应用）与分类
        let openAction = UNNotificationAction(
            identifier: Self.openActionIdentifier,
            title: "打开",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])

        // 请求系统横幅通知权限（无需提示音权限）
        center.requestAuthorization(options: [.alert, .badge]) { granted, error in
            if let error = error {
                NSLog("通知权限申请失败: %@", error.localizedDescription)
            }
        }
    }

    /// 发送倒计时结束长通知（需用户手动操作/点击）
    func sendTimerFinishedNotification(timerTitle: String) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        let cleanTitle = timerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            content.title = "倒计时"
            content.body = "时间到了！点击返回应用"
        } else {
            content.title = cleanTitle
            content.body = "时间到了！点击返回应用"
        }

        content.categoryIdentifier = Self.categoryIdentifier
        // 设为时间敏感通知，提高系统展示优先级并常驻提醒
        content.interruptionLevel = .timeSensitive
        // 按用户要求：不附带声音提示
        content.sound = nil

        // 立即触发通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "timer_finished_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                NSLog("发送通知失败: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 即使应用处于前台，也以横幅形式展示并保留在通知列表
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    /// 用户手动点击通知或点击“打开”操作时，激活应用并前置窗口
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        completionHandler()
    }
}
