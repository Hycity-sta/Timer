import Foundation
import Combine

/// 倒计时预设：名称 + 总时长（秒）
struct TimerPreset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var totalSeconds: Int

    /// 侧边栏展示用的时长文本，如 25:00 或 1:05:00
    var durationText: String {
        TimerPreset.durationText(for: totalSeconds)
    }

    static func durationText(for totalSeconds: Int) -> String {
        let total = max(0, totalSeconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }

    /// 根据时长自动生成的默认名称，如“25 分钟”“1 小时 5 分钟”“1 分钟 30 秒”
    static func autoName(for totalSeconds: Int) -> String {
        let total = max(0, totalSeconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60

        var parts: [String] = []
        if hrs > 0 { parts.append("\(hrs) 小时") }
        if mins > 0 { parts.append("\(mins) 分钟") }
        if secs > 0 { parts.append("\(secs) 秒") }
        return parts.isEmpty ? "0 秒" : parts.joined(separator: " ")
    }
}

/// 预设列表存储，以 JSON 形式持久化到 UserDefaults
@MainActor
final class PresetStore: ObservableObject {
    private static let storageKey = "TimerApp.presets"

    @Published private(set) var presets: [TimerPreset] {
        didSet { save() }
    }

    private var defaults: UserDefaults {
        UserDefaults.standard
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            self.presets = decoded
        } else {
            self.presets = []
        }
    }

    func preset(id: UUID?) -> TimerPreset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    /// 新建预设并追加到列表末尾
    @discardableResult
    func add(name: String, totalSeconds: Int) -> TimerPreset {
        let preset = TimerPreset(name: name, totalSeconds: totalSeconds)
        presets.append(preset)
        return preset
    }

    func rename(id: UUID, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].name = name
    }

    func updateDuration(id: UUID, totalSeconds: Int) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].totalSeconds = totalSeconds
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
