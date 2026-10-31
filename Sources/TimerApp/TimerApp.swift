import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationManager.shared.setup()
        setupAppIcon()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            WindowSizeManager.shared.saveSize(for: window)
        }
    }

    private func setupAppIcon() {
        // 1. 尝试从 SPM Bundle 资源读取计时器 AppIcon.icns
        if let iconUrl = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconUrl) {
            NSApp.applicationIconImage = icon
            return
        }

        // 2. 尝试从工程本地路径读取
        let localPaths = [
            "Sources/TimerApp/Resources/AppIcon.icns",
            Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        ]
        for path in localPaths {
            if let icon = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = icon
                return
            }
        }

        // 3. 兜底：使用系统 SF Symbol "timer"
        if let symbolImage = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer") {
            NSApp.applicationIconImage = symbolImage
        }
    }
}

@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 单窗口应用：使用 Window 而非 WindowGroup，禁止 ⌘N 多开
        Window("倒计时", id: "main") {
            ContentView()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                NewTimerCommand()
            }
            CommandGroup(replacing: .saveItem) {}
        }
    }
}

/// 「文件 > 新建倒计时」菜单项（⌘N）
private struct NewTimerCommand: View {
    @FocusedValue(\.newTimerAction) private var newTimerAction

    var body: some View {
        Button("新建倒计时") {
            newTimerAction?()
        }
        .keyboardShortcut("n", modifiers: .command)
        .disabled(newTimerAction == nil)
    }
}

/// 由 ContentView 提供的「新建倒计时」动作
struct NewTimerActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newTimerAction: (() -> Void)? {
        get { self[NewTimerActionKey.self] }
        set { self[NewTimerActionKey.self] = newValue }
    }
}
