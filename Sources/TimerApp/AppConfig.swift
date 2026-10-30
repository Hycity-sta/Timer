import Foundation

/// 应用程序环境配置，用于物理隔离 Debug 与 Release 版本的数据与配置
public enum AppEnvironment {
    #if DEBUG
    public static let isDebug = true
    public static let environmentName = "Debug"
    public static let bundleIdentifier = "com.hycity.timer.debug"
    public static let appDisplayName = "倒计时 (Debug)"
    public static let windowAutosaveName = "TimerMainWindow.Debug"
    public static let userDefaultsSuiteName = "com.hycity.timer.debug"
    public static let dataKeyPrefix = "debug."
    public static let windowGroupId = "timer-main-window-debug"
    #else
    public static let isDebug = false
    public static let environmentName = "Release"
    public static let bundleIdentifier = "com.hycity.timer"
    public static let appDisplayName = "倒计时"
    public static let windowAutosaveName = "TimerMainWindow"
    public static let userDefaultsSuiteName = "com.hycity.timer"
    public static let dataKeyPrefix = ""
    public static let windowGroupId = "timer-main-window"
    #endif

    /// 获取当前环境专用的 UserDefaults 实例
    /// Debug 版本使用 "com.hycity.timer.debug"，Release 版本使用 "com.hycity.timer"
    /// 确保两者的配置、历史记录及窗口状态在系统偏好设置中完全隔离
    public static var userDefaults: UserDefaults {
        UserDefaults(suiteName: userDefaultsSuiteName) ?? .standard
    }
}
