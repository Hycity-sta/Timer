import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @FocusState private var focusedIndex: Int?

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
    }

    var body: some View {
        VStack(spacing: 24) {
            // 顶部栏
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("倒计时")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

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
                Text("⏰ 时间到！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .transition(.opacity)
            }

            // 控制按钮区域
            HStack(spacing: 12) {
                // 开始 / 暂停 / 继续
                Button(action: {
                    focusedIndex = nil
                    viewModel.toggleStartPause()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: startPauseIconName)
                        Text(startPauseTitle)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 100, minHeight: 36)
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
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(minWidth: 80, minHeight: 36)
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

                // 清空（放置在重置右侧，带背景和边框）
                Button(action: {
                    focusedIndex = nil
                    viewModel.clearAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清空")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(minWidth: 80, minHeight: 36)
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
        }
        .padding(28)
        .frame(width: 440, height: 250)
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var startPauseIconName: String {
        switch viewModel.state {
        case .running:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .idle, .finished:
            return "play.fill"
        }
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
