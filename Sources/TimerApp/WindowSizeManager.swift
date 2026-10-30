import SwiftUI
import AppKit

final class WindowSizeManager {
    static let shared = WindowSizeManager()

    private let widthKey = "TimerApp." + AppEnvironment.dataKeyPrefix + "lastWindowWidth"
    private let heightKey = "TimerApp." + AppEnvironment.dataKeyPrefix + "lastWindowHeight"

    private let minWidth: CGFloat = 420
    private let minHeight: CGFloat = 220

    private var isRestoring = false

    private var defaults: UserDefaults {
        AppEnvironment.userDefaults
    }

    private init() {}

    /// 保存当前窗口大小到 UserDefaults
    func saveSize(for window: NSWindow) {
        // 如果正在恢复尺寸，或者窗口处于全屏、最小化状态，不进行保存
        guard !isRestoring else { return }
        guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else { return }

        let size = window.frame.size
        guard size.width >= minWidth, size.height >= minHeight else { return }

        defaults.set(Double(size.width), forKey: widthKey)
        defaults.set(Double(size.height), forKey: heightKey)
    }

    /// 恢复上一次保存的窗口大小
    func restoreSize(for window: NSWindow) {
        let savedW = CGFloat(defaults.double(forKey: widthKey))
        let savedH = CGFloat(defaults.double(forKey: heightKey))

        // 若没有保存过有效尺寸，则保持系统默认尺寸
        guard savedW >= minWidth, savedH >= minHeight else { return }

        isRestoring = true
        defer { isRestoring = false }

        var frame = window.frame
        let targetWidth = max(minWidth, savedW)
        let targetHeight = max(minHeight, savedH)

        // 保持窗口顶部位置不变，向下扩展或收缩
        let newY = frame.maxY - targetHeight
        frame.origin.y = newY
        frame.size = CGSize(width: targetWidth, height: targetHeight)

        // 确保窗口在屏幕安全可视区域内（避免超出菜单栏或 Dock）
        let activeScreen = window.screen ?? NSScreen.main
        if let screen = activeScreen {
            let visible = screen.visibleFrame

            if frame.height > visible.height {
                frame.size.height = visible.height
            }
            if frame.width > visible.width {
                frame.size.width = visible.width
            }
            if frame.minY < visible.minY {
                frame.origin.y = visible.minY
            }
            if frame.maxY > visible.maxY {
                frame.origin.y = visible.maxY - frame.height
            }
            if frame.minX < visible.minX {
                frame.origin.x = visible.minX
            }
            if frame.maxX > visible.maxX {
                frame.origin.x = visible.maxX - frame.width
            }
        }

        window.setFrame(frame, display: true, animate: false)
    }
}

/// 窗口尺寸跟踪与恢复的 ViewRepresentable
struct WindowSizeTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowTrackingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowTrackingView: NSView {
    private var observers: [NSObjectProtocol] = []
    private var hasRestored = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // 清理旧监听
        clearObservers()

        guard let window = self.window else { return }

        // 设置系统 Frame Autosave Name 作为辅助支持
        _ = window.setFrameAutosaveName(AppEnvironment.windowAutosaveName)

        // 异步确保在 SwiftUI 首轮布局后应用保存的窗口尺寸
        if !hasRestored {
            hasRestored = true
            DispatchQueue.main.async { [weak window] in
                guard let window = window else { return }
                WindowSizeManager.shared.restoreSize(for: window)
            }
        }

        // 监听窗口尺寸调整通知
        let resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let window = window else { return }
            WindowSizeManager.shared.saveSize(for: window)
        }

        // 监听拖拽调整完成通知
        let endLiveResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let window = window else { return }
            WindowSizeManager.shared.saveSize(for: window)
        }

        // 监听窗口关闭通知
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let window = window else { return }
            WindowSizeManager.shared.saveSize(for: window)
        }

        observers.append(contentsOf: [resizeObserver, endLiveResizeObserver, closeObserver])
    }

    private func clearObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    deinit {
        clearObservers()
    }
}
