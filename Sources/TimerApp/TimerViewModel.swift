import Foundation
import Combine
import AppKit

enum TimerState {
    case idle
    case running
    case paused
    case finished
}

@MainActor
final class TimerViewModel: ObservableObject {
    // 6 个数字依次为：时十位, 时个位, 分十位, 分个位, 秒十位, 秒个位
    @Published var digits: [Int] = [0, 0, 0, 0, 0, 0] // 启动时为空界面 00:00:00
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: Int = 0
    @Published var initialTotalSeconds: Int = 0

    /// 6 格数字可表示的最大时长 99:59:59
    static let maxTotalSeconds = 99 * 3600 + 59 * 60 + 59

    /// 旧版本用于持久化标题的 key，现已废弃，仅用于启动时清理
    private static let legacyTitleStorageKey = "TimerApp.customTitle"

    /// 当前倒计时标题（不跨重启保留；加载预设时使用预设名称）
    @Published var title: String = ""

    /// 去除首尾空白字符的标题
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var timerCancellable: AnyCancellable?

    init() {
        UserDefaults.standard.removeObject(forKey: Self.legacyTitleStorageKey)
        syncDigitsToRemainingSeconds()
    }

    /// 根据当前输入的 6 个数字计算总秒数
    var calculatedSecondsFromDigits: Int {
        let hours = digits[0] * 10 + digits[1]
        let minutes = digits[2] * 10 + digits[3]
        let seconds = digits[4] * 10 + digits[5]
        return hours * 3600 + minutes * 60 + seconds
    }

    /// 更新某个格子的数值 (0~9)
    func setDigit(at index: Int, value: Int) {
        guard state == .idle || state == .finished else { return }
        guard index >= 0 && index < 6 else { return }

        // 合法性校验
        var clamped = max(0, min(9, value))
        // 分十位和秒十位最大为 5 (00~59)
        if (index == 2 || index == 4) && clamped > 5 {
            clamped = 5
        }

        digits[index] = clamped
        let total = calculatedSecondsFromDigits
        initialTotalSeconds = total
        remainingSeconds = total
        if state == .finished {
            state = .idle
        }
    }

    /// 微调某个格子的值（向上或向下）
    func adjustDigit(at index: Int, delta: Int) {
        guard state == .idle || state == .finished else { return }
        let current = digits[index]
        let maxVal = (index == 2 || index == 4) ? 5 : 9
        let next = (current + delta + (maxVal + 1)) % (maxVal + 1)
        setDigit(at: index, value: next)
    }

    /// 开始或暂停
    func toggleStartPause() {
        switch state {
        case .idle, .finished:
            let total = calculatedSecondsFromDigits
            if total > 0 {
                initialTotalSeconds = total
                remainingSeconds = total
                startTimer()
            } else {
                NSSound.beep()
            }
        case .running:
            pauseTimer()
        case .paused:
            startTimer()
        }
    }

    /// 开始倒计时
    private func startTimer() {
        state = .running
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.tick()
            }
    }

    /// 每秒步进
    private func tick() {
        guard remainingSeconds > 0 else {
            completeTimer()
            return
        }

        remainingSeconds -= 1
        syncDigitsFromRemainingSeconds()

        if remainingSeconds == 0 {
            completeTimer()
        }
    }

    /// 暂停倒计时
    func pauseTimer() {
        state = .paused
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    /// 倒计时结束
    private func completeTimer() {
        state = .finished
        timerCancellable?.cancel()
        timerCancellable = nil
        syncDigitsFromRemainingSeconds()
        NSSound.beep()
    }

    /// 重置
    func reset() {
        timerCancellable?.cancel()
        timerCancellable = nil
        remainingSeconds = initialTotalSeconds
        syncDigitsFromRemainingSeconds()
        state = .idle
    }

    /// 加载指定时长与标题（如来自预设）：停止当前计时并进入 idle 状态
    func load(totalSeconds: Int, title: String) {
        timerCancellable?.cancel()
        timerCancellable = nil
        let clamped = max(0, min(Self.maxTotalSeconds, totalSeconds))
        initialTotalSeconds = clamped
        remainingSeconds = clamped
        syncDigitsFromRemainingSeconds()
        state = .idle
        self.title = title
    }

    /// 清空为 0
    func clearAll() {
        timerCancellable?.cancel()
        timerCancellable = nil
        digits = [0, 0, 0, 0, 0, 0]
        initialTotalSeconds = 0
        remainingSeconds = 0
        state = .idle
    }

    /// 根据 remainingSeconds 同步 digits 数组
    private func syncDigitsFromRemainingSeconds() {
        let hrs = remainingSeconds / 3600
        let mins = (remainingSeconds % 3600) / 60
        let secs = remainingSeconds % 60

        digits[0] = min(9, hrs / 10)
        digits[1] = min(9, hrs % 10)
        digits[2] = min(5, mins / 10)
        digits[3] = min(9, mins % 10)
        digits[4] = min(5, secs / 10)
        digits[5] = min(9, secs % 10)
    }

    private func syncDigitsToRemainingSeconds() {
        let total = calculatedSecondsFromDigits
        initialTotalSeconds = total
        remainingSeconds = total
        syncDigitsFromRemainingSeconds()
    }
}
