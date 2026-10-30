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
    @Published var digits: [Int] = [0, 0, 0, 5, 0, 0] // 默认 00:05:00
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: Int = 300
    @Published var initialTotalSeconds: Int = 300

    private static let titleStorageKey = "TimerApp." + AppEnvironment.dataKeyPrefix + "customTitle"

    /// 用户自定义倒计时标题，支持通过 UserDefaults 在应用重启后保留
    @Published var title: String {
        didSet {
            AppEnvironment.userDefaults.set(title, forKey: Self.titleStorageKey)
        }
    }

    /// 去除首尾空白字符的标题
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var timerCancellable: AnyCancellable?

    init() {
        self.title = AppEnvironment.userDefaults.string(forKey: Self.titleStorageKey) ?? ""
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
