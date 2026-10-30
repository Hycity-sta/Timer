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

    private func setupAppIcon() {
        // 1. 尝试从应用 Bundle 资源读取复制的系统时钟/计时器图标
        if let iconUrl = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconUrl) {
            NSApp.applicationIconImage = icon
            return
        }

        // 2. 尝试从 macOS 系统的 Clock.app 读取官方图标
        let systemClockAppIcon = "/System/Applications/Clock.app/Contents/Resources/AppIcon.icns"
        if let icon = NSImage(contentsOfFile: systemClockAppIcon) {
            NSApp.applicationIconImage = icon
            return
        }

        // 3. 兜底方案：使用系统 SF Symbol "timer" 矢量图标
        if let symbolImage = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer") {
            NSApp.applicationIconImage = symbolImage
        }
    }
}

@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
