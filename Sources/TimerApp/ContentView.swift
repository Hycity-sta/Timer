import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var presetStore = PresetStore()
    @FocusState private var focusedIndex: Int?

    // 重命名弹窗：renameTargetID 为 nil 时仅修改当前临时标题，否则重命名对应预设
    @State private var isRenamePresented = false
    @State private var renameTargetID: UUID?
    @State private var tempTitle = ""

    // 侧边栏选中项及「运行中加载预设」确认弹窗
    @State private var selectedPresetID: UUID?
    @State private var pendingPreset: TimerPreset?
    @State private var selectionBeforePending: UUID?
    @State private var isLoadConfirmPresented = false

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
    }

    /// 当前设定的倒计时时长（运行中、暂停、结束时均为本次设定的总时长）
    private var currentDurationSeconds: Int {
        viewModel.initialTotalSeconds
    }

    private var canSavePreset: Bool {
        currentDurationSeconds > 0
    }

    private var selectedPreset: TimerPreset? {
        presetStore.preset(id: selectedPresetID)
    }

    private var defaultAppName: String {
        (Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? "倒计时"
    }

    private var windowTitle: String {
        let title = viewModel.trimmedTitle
        if title.isEmpty {
            return defaultAppName
        } else {
            return "\(title) - \(defaultAppName)"
        }
    }

    private var finishedMessage: String {
        let title = viewModel.trimmedTitle
        if title.isEmpty {
            return "⏰ 时间到！"
        } else {
            return "⏰ [\(title)] 时间到！"
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 300)
        } detail: {
            timerDetail
        }
        .frame(minWidth: 600, minHeight: 250)
        .navigationTitle(windowTitle)
        .background(WindowSizeTracker())
        .focusedSceneValue(\.savePresetAction, canSavePreset ? { saveCurrentAsPreset() } : nil)
        .alert(renameAlertTitle, isPresented: $isRenamePresented) {
            TextField(renameTargetID == nil ? "输入倒计时标题" : "输入预设名称", text: $tempTitle)
            Button("确定") {
                commitRename()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(renameTargetID == nil
                 ? "设置倒计时标题，留空则不显示标题。"
                 : "设置预设名称，留空则按时长自动命名。")
        }
        .alert(loadConfirmTitle, isPresented: $isLoadConfirmPresented) {
            Button("停止并加载") {
                confirmPendingLoad()
            }
            Button("取消", role: .cancel) {
                cancelPendingLoad()
            }
        }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            ForEach(presetStore.presets) { preset in
                presetRow(preset)
                    .tag(preset.id)
                    .contextMenu {
                        Button("重命名") {
                            beginRename(presetID: preset.id)
                        }
                        Button("用当前时长覆盖") {
                            presetStore.updateDuration(id: preset.id, totalSeconds: currentDurationSeconds)
                        }
                        .disabled(!canSavePreset)
                        Divider()
                        Button("删除", role: .destructive) {
                            deletePreset(id: preset.id)
                        }
                    }
            }
            .onMove { source, destination in
                presetStore.move(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let id = selectedPresetID {
                deletePreset(id: id)
            }
        }
        .overlay {
            if presetStore.presets.isEmpty {
                VStack(spacing: 6) {
                    Text("暂无预设")
                        .font(.system(size: 13, weight: .medium))
                    Text("点击 ＋ 保存当前倒计时")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                Button(action: saveCurrentAsPreset) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .help("将当前倒计时保存为预设 (⌘S)")
                .disabled(!canSavePreset)

                Button(action: {
                    if let id = selectedPresetID {
                        deletePreset(id: id)
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .help("删除选中的预设")
                .disabled(selectedPresetID == nil)

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private func presetRow(_ preset: TimerPreset) -> some View {
        HStack(spacing: 8) {
            Text(preset.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Text(preset.durationText)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    /// 侧边栏选中绑定：仅在用户点击时触发加载逻辑，代码内部直接修改 selectedPresetID 不会触发
    private var sidebarSelection: Binding<UUID?> {
        Binding(
            get: { selectedPresetID },
            set: { newID in handleUserSelection(newID) }
        )
    }

    private func handleUserSelection(_ newID: UUID?) {
        guard newID != selectedPresetID else { return }
        let previousID = selectedPresetID
        selectedPresetID = newID

        guard let preset = presetStore.preset(id: newID) else { return }
        focusedIndex = nil

        if viewModel.state == .running || viewModel.state == .paused {
            pendingPreset = preset
            selectionBeforePending = previousID
            isLoadConfirmPresented = true
        } else {
            viewModel.load(totalSeconds: preset.totalSeconds, title: preset.name)
        }
    }

    private var loadConfirmTitle: String {
        "是否停止当前倒计时并加载「\(pendingPreset?.name ?? "")」？"
    }

    private func confirmPendingLoad() {
        if let preset = pendingPreset {
            viewModel.load(totalSeconds: preset.totalSeconds, title: preset.name)
            selectedPresetID = preset.id
        }
        pendingPreset = nil
        selectionBeforePending = nil
    }

    private func cancelPendingLoad() {
        selectedPresetID = selectionBeforePending
        pendingPreset = nil
        selectionBeforePending = nil
    }

    // MARK: - 预设操作

    /// 用当前时长新建预设：名称取当前标题，标题为空时按时长自动命名，新建后自动选中
    private func saveCurrentAsPreset() {
        let seconds = currentDurationSeconds
        guard seconds > 0 else {
            NSSound.beep()
            return
        }
        let title = viewModel.trimmedTitle
        let name = title.isEmpty ? TimerPreset.autoName(for: seconds) : title
        let preset = presetStore.add(name: name, totalSeconds: seconds)
        selectedPresetID = preset.id
        viewModel.title = name
    }

    /// 删除预设；若删除的是当前选中项，则保持当前时长并取消选中
    private func deletePreset(id: UUID) {
        if selectedPresetID == id {
            selectedPresetID = nil
        }
        presetStore.delete(id: id)
    }

    private func beginRename(presetID: UUID?) {
        focusedIndex = nil
        if let preset = presetStore.preset(id: presetID) {
            renameTargetID = preset.id
            tempTitle = preset.name
        } else {
            renameTargetID = nil
            tempTitle = viewModel.title
        }
        isRenamePresented = true
    }

    private var renameAlertTitle: String {
        renameTargetID == nil ? "重命名倒计时" : "重命名预设"
    }

    private func commitRename() {
        if let id = renameTargetID, let preset = presetStore.preset(id: id) {
            let trimmed = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = trimmed.isEmpty ? TimerPreset.autoName(for: preset.totalSeconds) : trimmed
            presetStore.rename(id: id, to: name)
            if id == selectedPresetID {
                viewModel.title = name
            }
        } else {
            viewModel.title = tempTitle
        }
    }

    // MARK: - 计时器主界面

    private var timerDetail: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            // 倒计时标题（有标题时居中展示）
            if !viewModel.trimmedTitle.isEmpty {
                Text(viewModel.trimmedTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // 6 个格子与冒号
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    // 时 (2位)
                    HStack(spacing: 6) {
                        makeDigitView(index: 0)
                        makeDigitView(index: 1)
                    }

                    colonView

                    // 分 (2位)
                    HStack(spacing: 6) {
                        makeDigitView(index: 2)
                        makeDigitView(index: 3)
                    }

                    colonView

                    // 秒 (2位)
                    HStack(spacing: 6) {
                        makeDigitView(index: 4)
                        makeDigitView(index: 5)
                    }
                }

                // 底部单位标签
                HStack(spacing: 0) {
                    Text("时")
                        .frame(width: 114)
                    Spacer().frame(width: 24)
                    Text("分")
                        .frame(width: 114)
                    Spacer().frame(width: 24)
                    Text("秒")
                        .frame(width: 114)
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            }

            // 倒计时完成提示
            if viewModel.state == .finished {
                Text(finishedMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // 控制按钮区域
            HStack(spacing: 12) {
                // 开始 / 暂停 / 继续
                Button(action: {
                    focusedIndex = nil
                    viewModel.toggleStartPause()
                }) {
                    Text(startPauseTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 92, minHeight: 34)
                        .background(startPauseButtonColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)

                // 重置
                Button(action: {
                    focusedIndex = nil
                    viewModel.reset()
                }) {
                    Text("重置")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 72, minHeight: 34)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state == .idle && viewModel.remainingSeconds == viewModel.initialTotalSeconds)
                .opacity((viewModel.state == .idle && viewModel.remainingSeconds == viewModel.initialTotalSeconds) ? 0.4 : 1.0)

                // 重命名（选中预设时重命名该预设，否则仅修改当前临时标题）
                Button(action: {
                    beginRename(presetID: selectedPresetID)
                }) {
                    Text("重命名")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 72, minHeight: 34)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 归零（将所有数字重置为 00:00:00）
                Button(action: {
                    focusedIndex = nil
                    viewModel.clearAll()
                }) {
                    Text("归零")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 72, minHeight: 34)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable || viewModel.calculatedSecondsFromDigits == 0)
                .opacity((!isEditable || viewModel.calculatedSecondsFromDigits == 0) ? 0.4 : 1.0)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 点击空白处取消格子焦点
        .contentShape(Rectangle())
        .onTapGesture {
            focusedIndex = nil
        }
    }

    private var colonView: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
        }
        .frame(width: 14)
    }

    @ViewBuilder
    private func makeDigitView(index: Int) -> some View {
        DigitBoxView(
            index: index,
            value: viewModel.digits[index],
            isEditable: isEditable,
            isFocused: focusedIndex == index,
            onSelect: {
                focusedIndex = index
            },
            onIncrement: {
                viewModel.adjustDigit(at: index, delta: 1)
            },
            onDecrement: {
                viewModel.adjustDigit(at: index, delta: -1)
            }
        )
        .focusable(isEditable)
        .focusEffectDisabled()
        .focused($focusedIndex, equals: index)
        .onKeyPress { press in
            guard isEditable else { return .ignored }
            return handleKeyPress(press, at: index)
        }
    }

    private func handleKeyPress(_ press: KeyPress, at index: Int) -> KeyPress.Result {
        // 数字键输入 0-9
        if let char = press.characters.first, let num = Int(String(char)) {
            viewModel.setDigit(at: index, value: num)
            if index < 5 {
                focusedIndex = index + 1
            } else {
                focusedIndex = nil
            }
            return .handled
        }

        // 删除键 Backspace / Delete
        if press.key == .delete {
            if viewModel.digits[index] != 0 {
                viewModel.setDigit(at: index, value: 0)
            } else if index > 0 {
                focusedIndex = index - 1
                viewModel.setDigit(at: index - 1, value: 0)
            }
            return .handled
        }

        // 左右箭头切换焦点
        if press.key == .leftArrow {
            if index > 0 {
                focusedIndex = index - 1
                return .handled
            }
        } else if press.key == .rightArrow {
            if index < 5 {
                focusedIndex = index + 1
                return .handled
            }
        }

        // 上下箭头增减数值
        if press.key == .upArrow {
            viewModel.adjustDigit(at: index, delta: 1)
            return .handled
        } else if press.key == .downArrow {
            viewModel.adjustDigit(at: index, delta: -1)
            return .handled
        }

        return .ignored
    }

    private var startPauseTitle: String {
        switch viewModel.state {
        case .running:
            return "暂停"
        case .paused:
            return "继续"
        case .idle, .finished:
            return "开始"
        }
    }

    private var startPauseButtonColor: Color {
        switch viewModel.state {
        case .running:
            return Color.orange
        case .paused:
            return Color.blue
        case .idle, .finished:
            return Color.accentColor
        }
    }
}
