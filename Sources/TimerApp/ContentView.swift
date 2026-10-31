import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var presetStore = PresetStore()

    // 侧边栏选中项
    @State private var selectedPresetID: UUID?

    // 新建 / 编辑倒计时弹窗状态
    @State private var activeEditorMode: TimerEditorMode?

    // 运行中切换倒计时确认弹窗
    @State private var pendingSwitchPreset: TimerPreset?
    @State private var isSwitchConfirmPresented = false

    // 删除倒计时确认弹窗
    @State private var pendingDeletePreset: TimerPreset?
    @State private var isDeleteConfirmPresented = false

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
    }

    /// 当前倒计时是否已开始（运行中或已暂停）
    private var isCountdownActive: Bool {
        viewModel.state == .running || viewModel.state == .paused
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
        guard let selectedPreset = selectedPreset else {
            return defaultAppName
        }
        let title = viewModel.trimmedTitle
        return title.isEmpty ? selectedPreset.displayName : title
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
        .sheet(item: $activeEditorMode) { mode in
            TimerEditorSheet(
                mode: mode,
                onConfirm: { name, totalSeconds in
                    commitEditor(mode: mode, name: name, totalSeconds: totalSeconds)
                },
                onCancel: {
                    activeEditorMode = nil
                }
            )
        }
        .alert(switchConfirmTitle, isPresented: $isSwitchConfirmPresented) {
            Button("停止并切换") {
                confirmPendingSwitch()
            }
            Button("取消", role: .cancel) {
                cancelPendingSwitch()
            }
        }
        .alert(deleteConfirmTitle, isPresented: $isDeleteConfirmPresented) {
            Button("删除", role: .destructive) {
                confirmPendingDelete()
            }
            Button("取消", role: .cancel) {
                cancelPendingDelete()
            }
        } message: {
            if let pending = pendingDeletePreset,
               pending.id == selectedPresetID && isCountdownActive {
                Text("当前倒计时正在进行中，删除后将停止计时且无法恢复。")
            } else {
                Text("删除后将无法恢复。")
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
                        Button("编辑") {
                            beginEdit(presetID: preset.id)
                        }
                        .disabled(preset.id == selectedPresetID && isCountdownActive)
                        Divider()
                        Button("删除", role: .destructive) {
                            requestDeletePreset(preset)
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
            guard activeEditorMode == nil else { return }
            if let id = selectedPresetID, let preset = presetStore.preset(id: id) {
                requestDeletePreset(preset)
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

        if viewModel.state == .running || viewModel.state == .paused {
            pendingSwitchPreset = preset
            isSwitchConfirmPresented = true
        } else {
            loadPreset(preset)
        }
    }

    // MARK: - 倒计时项管理（新建 / 编辑 / 加载 / 删除）

    private func requestCreateCountdown() {
        activeEditorMode = .create
    }

    private func beginEdit(presetID: UUID?) {
        guard let preset = presetStore.preset(id: presetID) else { return }
        // 倒计时已开始（运行中或已暂停）时不允许编辑当前倒计时
        if preset.id == selectedPresetID && isCountdownActive {
            return
        }
        activeEditorMode = .edit(preset)
    }

    private func commitEditor(mode: TimerEditorMode, name: String, totalSeconds: Int) {
        let normalizedName = TimerPreset.normalizedName(name)
        switch mode {
        case .create:
            let preset = presetStore.add(name: normalizedName, totalSeconds: totalSeconds)
            loadPreset(preset)
        case .edit(let preset):
            presetStore.update(id: preset.id, name: normalizedName, totalSeconds: totalSeconds)
            if selectedPresetID == preset.id {
                viewModel.load(totalSeconds: totalSeconds, title: normalizedName)
            }
        }
        activeEditorMode = nil
    }

    private func loadPreset(_ preset: TimerPreset) {
        selectedPresetID = preset.id
        viewModel.load(totalSeconds: preset.totalSeconds, title: preset.displayName)
    }

    private var switchConfirmTitle: String {
        "是否停止当前倒计时并切换到「\(pendingSwitchPreset?.displayName ?? "")」？"
    }

    private func confirmPendingSwitch() {
        if let pending = pendingSwitchPreset,
           let latest = presetStore.preset(id: pending.id) {
            loadPreset(latest)
        }
        pendingSwitchPreset = nil
    }

    private func cancelPendingSwitch() {
        pendingSwitchPreset = nil
    }

    private var deleteConfirmTitle: String {
        "确定要删除倒计时「\(pendingDeletePreset?.displayName ?? "")」吗？"
    }

    private func requestDeletePreset(_ preset: TimerPreset) {
        pendingDeletePreset = preset
        isDeleteConfirmPresented = true
    }

    private func confirmPendingDelete() {
        if let preset = pendingDeletePreset {
            deletePreset(id: preset.id)
        }
        pendingDeletePreset = nil
    }

    private func cancelPendingDelete() {
        pendingDeletePreset = nil
    }

    /// 删除倒计时项；若删除的是当前选中项，则先停止计时并清空选中回到空界面
    private func deletePreset(id: UUID) {
        if selectedPresetID == id {
            selectedPresetID = nil
            viewModel.load(totalSeconds: 0, title: "")
        }
        if pendingSwitchPreset?.id == id {
            pendingSwitchPreset = nil
            isSwitchConfirmPresented = false
        }
        presetStore.delete(id: id)
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

    // MARK: - 计时器主界面（纯只读展示 + 运行控制）

    private var timerDetail: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            // 6 个纯净只读数字显示与冒号
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    // 时 (2位)
                    HStack(spacing: 6) {
                        makeReadOnlyDigitView(index: 0)
                        makeReadOnlyDigitView(index: 1)
                    }

                    colonView

                    // 分 (2位)
                    HStack(spacing: 6) {
                        makeReadOnlyDigitView(index: 2)
                        makeReadOnlyDigitView(index: 3)
                    }

                    colonView

                    // 秒 (2位)
                    HStack(spacing: 6) {
                        makeReadOnlyDigitView(index: 4)
                        makeReadOnlyDigitView(index: 5)
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

            // 控制按钮区域（开始/暂停/继续、重置、编辑）
            HStack(spacing: 12) {
                // 开始 / 暂停 / 继续 / 重新开始
                Button(action: {
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
                .disabled(viewModel.initialTotalSeconds == 0)
                .opacity(viewModel.initialTotalSeconds == 0 ? 0.4 : 1.0)

                // 重置
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("重置")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 76, minHeight: 34)
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

                // 编辑当前选中的倒计时
                Button(action: {
                    beginEdit(presetID: selectedPresetID)
                }) {
                    Text("编辑")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 76, minHeight: 34)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(isCountdownActive ? 0.06 : 0.12), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isCountdownActive)
                .opacity(isCountdownActive ? 0.4 : 1.0)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    private func makeReadOnlyDigitView(index: Int) -> some View {
        DigitBoxView(
            index: index,
            value: viewModel.digits[index],
            isEditable: isEditable,
            isInteractive: false,
            showsBackground: false,
            isFocused: false
        )
    }

    private var startPauseTitle: String {
        switch viewModel.state {
        case .running:
            return "暂停"
        case .paused:
            return "继续"
        case .finished:
            return "重新开始"
        case .idle:
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
