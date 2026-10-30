import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @FocusState private var focusedIndex: Int?
    @State private var isRenamePresented = false
    @State private var tempTitle = ""

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
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

                // 重命名
                Button(action: {
                    focusedIndex = nil
                    tempTitle = viewModel.title
                    isRenamePresented = true
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
        .navigationTitle(windowTitle)
        // 点击空白处取消格子焦点
        .contentShape(Rectangle())
        .onTapGesture {
            focusedIndex = nil
        }
        .background(WindowSizeTracker())
        .alert("重命名倒计时", isPresented: $isRenamePresented) {
            TextField("输入倒计时标题", text: $tempTitle)
            Button("确定") {
                viewModel.title = tempTitle
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("设置倒计时标题，留空则不显示标题。")
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
