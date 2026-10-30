import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @FocusState private var focusedIndex: Int?

    var isEditable: Bool {
        viewModel.state == .idle || viewModel.state == .finished
    }

    var body: some View {
        VStack(spacing: 24) {
            // 顶部标题
            HStack {
                Text("倒计时")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if isEditable && viewModel.calculatedSecondsFromDigits > 0 {
                    Button("清空") {
                        viewModel.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            // 6 个格子与冒号
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
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

                // 底部标签
                HStack(spacing: 0) {
                    Text("时")
                        .frame(width: 110)
                    Spacer().frame(width: 20)
                    Text("分")
                        .frame(width: 110)
                    Spacer().frame(width: 20)
                    Text("秒")
                        .frame(width: 110)
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
            }

            // 状态提示
            if viewModel.state == .finished {
                Text("⏰ 时间到！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .transition(.opacity)
            }

            // 控制按钮区域
            HStack(spacing: 16) {
                // 开始 / 暂停 / 继续按钮
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

                // 重置按钮
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
            }
        }
        .padding(28)
        .frame(width: 440, height: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var colonView: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 4, height: 4)
        }
        .frame(width: 14)
    }

    @ViewBuilder
    private func makeDigitView(index: Int) -> some View {
        ZStack {
            DigitBoxView(
                index: index,
                digit: $viewModel.digits[index],
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

            // 隐藏的 TextField，用于捕获键盘数字输入与焦点跳转
            if isEditable {
                TextField("", text: Binding(
                    get: { "" },
                    set: { val in
                        handleKeyInput(for: index, value: val)
                    }
                ))
                .focused($focusedIndex, equals: index)
                .opacity(0.001)
                .frame(width: 52, height: 68)
            }
        }
    }

    private func handleKeyInput(for index: Int, value: String) {
        guard let lastChar = value.last, let num = Int(String(lastChar)) else {
            return
        }
        viewModel.setDigit(at: index, value: num)
        // 自动跳转到下一个输入格
        if index < 5 {
            focusedIndex = index + 1
        } else {
            focusedIndex = nil
        }
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
