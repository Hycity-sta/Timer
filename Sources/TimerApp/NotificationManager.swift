import Foundation
import UserNotifications
import AppKit
import os.log

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let categoryIdentifier = "TIMER_FINISHED_CATEGORY"
    static let openActionIdentifier = "TIMER_OPEN_ACTION"

    private let logger = Logger(subsystem: "com.hycity.timer", category: "NotificationManager")

    private override init() {
        super.init()
    }

    /// 初始化通知中心与分类
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 注册交互动作（打开应用）与分类
        let openAction = UNNotificationAction(
            identifier: Self.openActionIdentifier,
            title: "打开应用",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])

        // 请求系统通知权限（请求 alert 和 sound 权限以便系统建立完整的通知项）
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("通知权限请求错误: \(error.localizedDescription, privacy: .public)")
            } else {
                self?.logger.info("通知权限状态: granted=\(granted, privacy: .public)")
            }
        }
    }

    /// 发送倒计时结束通知
    func sendTimerFinishedNotification(timerTitle: String) {
        let center = UNUserNotificationCenter.current()
        let cleanTitle = timerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleToDisplay = cleanTitle.isEmpty ? "倒计时" : cleanTitle

        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.postNotification(title: titleToDisplay)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        self.postNotification(title: titleToDisplay)
                    } else if let error = error {
                        self.logger.error("请求通知权限失败: \(error.localizedDescription, privacy: .public)")
                    }
                }
            case .denied:
                self.logger.warning("通知权限已被用户拒绝，请在「系统设置 > 通知」中为本应用开启通知")
            @unknown default:
                self.postNotification(title: titleToDisplay)
            }
        }
    }

    private func postNotification(title: String) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "时间到了！点击返回应用"
        content.categoryIdentifier = Self.categoryIdentifier
        // 使用 active 中断等级，保证本地编译免签名证书时亦可正常投递
        content.interruptionLevel = .active
        // 按用户要求：不附带声音提示
        content.sound = nil

        // trigger 为 nil 表示立即发送
        let request = UNNotificationRequest(
            identifier: "timer_finished_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("添加通知请求失败: \(error.localizedDescription, privacy: .public)")
            } else {
                self?.logger.info("成功添加倒计时结束通知")
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

    /// 用户手动点击通知或点击“打开应用”操作时，激活应用并前置窗口
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
