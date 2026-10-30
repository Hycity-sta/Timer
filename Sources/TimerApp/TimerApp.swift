import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.processName = AppEnvironment.appDisplayName
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.processName = AppEnvironment.appDisplayName
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
        WindowGroup(AppEnvironment.appDisplayName, id: AppEnvironment.windowGroupId) {
            ContentView()
        }
        .windowToolbarStyle(.unified)
    }
}
