import SwiftUI

struct ContentView: View {
    private enum PendingInterruptAction {
        case select(TimerPreset)
        case createNew
    }

    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var presetStore = PresetStore()
    @FocusState private var focusedIndex: Int?

    // 重命名弹窗
    @State private var isRenamePresented = false
    @State private var renameTargetID: UUID?
    @State private var tempTitle = ""

    // 侧边栏选中项及「运行中切换/新建倒计时」确认弹窗
    @State private var selectedPresetID: UUID?
    @State private var pendingInterruptAction: PendingInterruptAction?
    @State private var isInterruptConfirmPresented = false

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
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
        guard selectedPreset != nil else {
            return defaultAppName
        }
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
            if selectedPreset != nil {
                timerDetail
            } else {
                emptyDetailView
            }
        }
        .frame(minWidth: 600, minHeight: 250)
        .navigationTitle(windowTitle)
        .background(WindowSizeTracker())
        .focusedSceneValue(\.newTimerAction, { requestCreateCountdown() })
        .onChange(of: viewModel.initialTotalSeconds) { _, newSeconds in
            if let id = selectedPresetID {
                presetStore.updateDuration(id: id, totalSeconds: newSeconds)
            }
        }
        .alert("重命名倒计时", isPresented: $isRenamePresented) {
            TextField("输入倒计时名称", text: $tempTitle)
            Button("确定") {
                commitRename()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("设置倒计时名称，留空则显示为「未命名倒计时」。")
        }
        .alert(interruptConfirmTitle, isPresented: $isInterruptConfirmPresented) {
            Button(interruptConfirmButtonTitle) {
                confirmPendingInterrupt()
            }
            Button("取消", role: .cancel) {
                cancelPendingInterrupt()
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
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarHeader
        }
        .onDeleteCommand {
            if let id = selectedPresetID {
                deletePreset(id: id)
            }
        }
        .overlay {
            if presetStore.presets.isEmpty {
                VStack(spacing: 6) {
                    Text("暂无倒计时")
                        .font(.system(size: 13, weight: .medium))
                    Text("点击上方「新建倒计时」创建")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 0) {
            Button(action: requestCreateCountdown) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("新建倒计时")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("新建倒计时 (⌘N)")
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()
                .opacity(0.6)
        }
    }

    private func presetRow(_ preset: TimerPreset) -> some View {
        HStack(spacing: 8) {
            Text(preset.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Text(preset.durationText)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    /// 侧边栏选中绑定：仅在用户点击具体项时触发切换逻辑
    private var sidebarSelection: Binding<UUID?> {
        Binding(
            get: { selectedPresetID },
            set: { newID in handleUserSelection(newID) }
        )
    }

    private func handleUserSelection(_ newID: UUID?) {
        guard let newID, newID != selectedPresetID,
              let preset = presetStore.preset(id: newID) else { return }
        focusedIndex = nil

        if viewModel.state == .running || viewModel.state == .paused {
            pendingInterruptAction = .select(preset)
            isInterruptConfirmPresented = true
        } else {
            loadPreset(preset)
        }
    }

    // MARK: - 倒计时项管理（新建 / 加载 / 删除 / 重命名）

    private func requestCreateCountdown() {
        focusedIndex = nil
        if viewModel.state == .running || viewModel.state == .paused {
            pendingInterruptAction = .createNew
            isInterruptConfirmPresented = true
        } else {
            performCreateCountdown()
        }
    }

    private func performCreateCountdown() {
        let preset = presetStore.add(name: TimerPreset.untitledName, totalSeconds: 0)
        loadPreset(preset)
    }

    private func loadPreset(_ preset: TimerPreset) {
        focusedIndex = nil
        selectedPresetID = preset.id
        viewModel.load(totalSeconds: preset.totalSeconds, title: preset.displayName)
    }

    private var interruptConfirmTitle: String {
        switch pendingInterruptAction {
        case .select(let preset):
            return "是否停止当前倒计时并切换到「\(preset.displayName)」？"
        case .createNew, .none:
            return "是否停止当前倒计时并新建？"
        }
    }

    private var interruptConfirmButtonTitle: String {
        switch pendingInterruptAction {
        case .select:
            return "停止并切换"
        case .createNew, .none:
            return "停止并新建"
        }
    }

    private func confirmPendingInterrupt() {
        guard let action = pendingInterruptAction else { return }
        pendingInterruptAction = nil
        switch action {
        case .select(let preset):
            if let latest = presetStore.preset(id: preset.id) {
                loadPreset(latest)
            }
        case .createNew:
            performCreateCountdown()
        }
    }

    private func cancelPendingInterrupt() {
        pendingInterruptAction = nil
    }

    /// 删除倒计时项；若删除的是当前选中项，则先停止计时并清空选中回到空界面
    private func deletePreset(id: UUID) {
        if selectedPresetID == id {
            selectedPresetID = nil
            focusedIndex = nil
            viewModel.load(totalSeconds: 0, title: "")
        }
        if case .select(let pending) = pendingInterruptAction, pending.id == id {
            pendingInterruptAction = nil
            isInterruptConfirmPresented = false
        }
        presetStore.delete(id: id)
    }

    private func beginRename(presetID: UUID?) {
        focusedIndex = nil
        guard let preset = presetStore.preset(id: presetID) else { return }
        renameTargetID = preset.id
        tempTitle = preset.displayName
        isRenamePresented = true
    }

    private func commitRename() {
        guard let id = renameTargetID, presetStore.preset(id: id) != nil else { return }
        let name = TimerPreset.normalizedName(tempTitle)
        presetStore.rename(id: id, to: name)
        if id == selectedPresetID {
            viewModel.title = name
        }
    }

    // MARK: - 未选中空界面

    private var emptyDetailView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Image(systemName: "timer")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.65))

            Text("请在左侧选择或新建一个倒计时")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Button(action: requestCreateCountdown) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("新建倒计时")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                // 重命名当前选中的倒计时
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
