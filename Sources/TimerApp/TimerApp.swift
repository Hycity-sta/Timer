import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {
                SavePresetCommand()
            }
        }
    }
}

/// 「文件 > 保存为预设」菜单项（⌘S）
private struct SavePresetCommand: View {
    @FocusedValue(\.savePresetAction) private var savePresetAction

    var body: some View {
        Button("保存为预设") {
            savePresetAction?()
        }
        .keyboardShortcut("s", modifiers: .command)
        .disabled(savePresetAction == nil)
    }
}

/// 由 ContentView 提供的「保存当前倒计时为预设」动作
struct SavePresetActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var savePresetAction: (() -> Void)? {
        get { self[SavePresetActionKey.self] }
        set { self[SavePresetActionKey.self] = newValue }
    }
}
