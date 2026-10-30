import SwiftUI
import AppKit

enum TimerEditorMode: Identifiable {
    case create
    case edit(TimerPreset)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let preset):
            return "edit-\(preset.id.uuidString)"
        }
    }

    var sheetTitle: String {
        switch self {
        case .create:
            return "新建倒计时"
        case .edit:
            return "编辑倒计时"
        }
    }
}

struct TimerEditorSheet: View {
    let mode: TimerEditorMode
    let onConfirm: (String, Int) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var digits: [Int]
    @FocusState private var isNameFieldFocused: Bool

    // 当前聚焦的数字格索引（0~5）
    @State private var focusedDigitIndex: Int? = 0
    @State private var focusRequestToken: Int = 0

    init(
        mode: TimerEditorMode,
        onConfirm: @escaping (String, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _digits = State(initialValue: [0, 0, 0, 0, 0, 0])
        case .edit(let preset):
            let initialName = (preset.displayName == TimerPreset.untitledName) ? "" : preset.displayName
            _name = State(initialValue: initialName)
            _digits = State(initialValue: Self.digits(from: preset.totalSeconds))
        }
    }

    private static func digits(from totalSeconds: Int) -> [Int] {
        let clamped = max(0, min(TimerViewModel.maxTotalSeconds, totalSeconds))
        let hrs = clamped / 3600
        let mins = (clamped % 3600) / 60
        let secs = clamped % 60
        return [
            min(9, hrs / 10),
            min(9, hrs % 10),
            min(5, mins / 10),
            min(9, mins % 10),
            min(5, secs / 10),
            min(9, secs % 10)
        ]
    }

    private var calculatedSeconds: Int {
        let hours = digits[0] * 10 + digits[1]
        let minutes = digits[2] * 10 + digits[3]
        let seconds = digits[4] * 10 + digits[5]
        return hours * 3600 + minutes * 60 + seconds
    }

    private var canConfirm: Bool {
        calculatedSeconds > 0
    }

    private var isDigitFocusActive: Bool {
        focusedDigitIndex != nil && !isNameFieldFocused
    }

    var body: some View {
        VStack(spacing: 20) {
            // 顶部弹窗标题
            Text(mode.sheetTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // 名称输入框区域
            VStack(alignment: .leading, spacing: 6) {
                Text("名称")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    TextField(TimerPreset.untitledName, text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            if canConfirm {
                                commit()
                            } else {
                                selectDigit(0)
                            }
                        }

                    if !name.isEmpty {
                        Button(action: {
                            name = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("清空名称")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isNameFieldFocused ? Color.accentColor : Color.primary.opacity(0.15),
                            lineWidth: isNameFieldFocused ? 2 : 1
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedDigitIndex = nil
                    isNameFieldFocused = true
                }
            }
            .frame(width: 390)

            // 6 格数字设置区域
            VStack(spacing: 8) {
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
            .padding(.vertical, 4)
            .background(
                SheetDigitFocusResponderView(
                    isActive: isDigitFocusActive,
                    focusRequestToken: focusRequestToken,
                    onKeyDown: { event in
                        handleDigitKeyDown(event)
                    },
                    onTextFieldFocused: {
                        focusedDigitIndex = nil
                    },
                    onTabFromTextField: {
                        selectDigit(0)
                    },
                    onClickOutsideDigits: {
                        focusedDigitIndex = nil
                    }
                )
            )

            Divider()
                .frame(width: 390)

            // 底部操作按钮栏
            HStack(spacing: 10) {
                Button(action: clearDigits) {
                    Text("归零")
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 64, minHeight: 30)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(calculatedSeconds == 0)
                .opacity(calculatedSeconds == 0 ? 0.4 : 1.0)

                Spacer()

                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 68, minHeight: 30)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: commit) {
                    Text("确定")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 68, minHeight: 30)
                        .background(Color.accentColor)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
                .opacity(canConfirm ? 1.0 : 0.4)
            }
            .frame(width: 390)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .contentShape(Rectangle())
        .onTapGesture {
            isNameFieldFocused = false
            focusedDigitIndex = nil
        }
        .onChange(of: isNameFieldFocused) { _, focused in
            if focused {
                focusedDigitIndex = nil
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                selectDigit(0)
            }
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
            value: digits[index],
            isEditable: true,
            isInteractive: true,
            isFocused: focusedDigitIndex == index && !isNameFieldFocused,
            onSelect: {
                selectDigit(index)
            },
            onIncrement: {
                selectDigit(index)
                adjustDigit(at: index, delta: 1)
            },
            onDecrement: {
                selectDigit(index)
                adjustDigit(at: index, delta: -1)
            }
        )
    }

    private func selectDigit(_ index: Int) {
        isNameFieldFocused = false
        focusedDigitIndex = index
        focusRequestToken &+= 1
    }

    private func setDigit(at index: Int, value: Int) {
        guard index >= 0 && index < 6 else { return }
        var clamped = max(0, min(9, value))
        if (index == 2 || index == 4) && clamped > 5 {
            clamped = 5
        }
        digits[index] = clamped
    }

    private func adjustDigit(at index: Int, delta: Int) {
        guard index >= 0 && index < 6 else { return }
        let current = digits[index]
        let maxVal = (index == 2 || index == 4) ? 5 : 9
        let next = (current + delta + (maxVal + 1)) % (maxVal + 1)
        setDigit(at: index, value: next)
    }

    private func clearDigits() {
        digits = [0, 0, 0, 0, 0, 0]
        selectDigit(0)
    }

    private func commit() {
        let total = calculatedSeconds
        guard total > 0 else {
            NSSound.beep()
            return
        }
        onConfirm(name, total)
    }

    private func handleDigitKeyDown(_ event: NSEvent) -> Bool {
        guard isDigitFocusActive, let index = focusedDigitIndex else { return false }

        // 数字键输入 0-9（兼容主键盘与小键盘）
        if let chars = event.charactersIgnoringModifiers,
           chars.count == 1,
           let char = chars.first,
           let num = char.wholeNumberValue,
           (0...9).contains(num) {
            setDigit(at: index, value: num)
            if index < 5 {
                focusedDigitIndex = index + 1
                focusRequestToken &+= 1
            } else {
                focusedDigitIndex = nil
            }
            return true
        }

        switch event.keyCode {
        case 51, 117: // Delete (Backspace) / Forward Delete
            if digits[index] != 0 {
                setDigit(at: index, value: 0)
            } else if index > 0 {
                focusedDigitIndex = index - 1
                focusRequestToken &+= 1
                setDigit(at: index - 1, value: 0)
            }
            return true

        case 123: // Left Arrow
            if index > 0 {
                focusedDigitIndex = index - 1
                focusRequestToken &+= 1
            }
            return true

        case 124: // Right Arrow
            if index < 5 {
                focusedDigitIndex = index + 1
                focusRequestToken &+= 1
            }
            return true

        case 126: // Up Arrow
            adjustDigit(at: index, delta: 1)
            return true

        case 125: // Down Arrow
            adjustDigit(at: index, delta: -1)
            return true

        case 48: // Tab
            if event.modifierFlags.contains(.shift) {
                if index > 0 {
                    focusedDigitIndex = index - 1
                    focusRequestToken &+= 1
                } else {
                    focusedDigitIndex = nil
                    isNameFieldFocused = true
                }
            } else {
                if index < 5 {
                    focusedDigitIndex = index + 1
                    focusRequestToken &+= 1
                } else {
                    focusedDigitIndex = nil
                    isNameFieldFocused = true
                }
            }
            return true

        case 36, 76: // Return / Keypad Enter
            if canConfirm {
                commit()
            } else {
                NSSound.beep()
            }
            return true

        default:
            return false
        }
    }
}

/// 弹窗内专用的数字格焦点与键盘事件接管视图：
/// 当名称 TextField 聚焦时绝不拦截键盘事件；当数字格聚焦时使 TextField 释放焦点并响应数字与方向键。
private struct SheetDigitFocusResponderView: NSViewRepresentable {
    let isActive: Bool
    let focusRequestToken: Int
    let onKeyDown: (NSEvent) -> Bool
    let onTextFieldFocused: () -> Void
    let onTabFromTextField: () -> Void
    let onClickOutsideDigits: () -> Void

    func makeNSView(context: Context) -> SheetKeyResponderNSView {
        let view = SheetKeyResponderNSView()
        view.onKeyDown = onKeyDown
        view.onTextFieldFocused = onTextFieldFocused
        view.onTabFromTextField = onTabFromTextField
        view.onClickOutsideDigits = onClickOutsideDigits
        return view
    }

    func updateNSView(_ nsView: SheetKeyResponderNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onTextFieldFocused = onTextFieldFocused
        nsView.onTabFromTextField = onTabFromTextField
        nsView.onClickOutsideDigits = onClickOutsideDigits
        nsView.isActive = isActive

        if isActive {
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView = nsView,
                      nsView.isActive,
                      let window = nsView.window else { return }
                if window.firstResponder !== nsView {
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }
}

private final class SheetKeyResponderNSView: NSView {
    var isActive: Bool = false
    var onKeyDown: ((NSEvent) -> Bool)?
    var onTextFieldFocused: (() -> Void)?
    var onTabFromTextField: (() -> Void)?
    var onClickOutsideDigits: (() -> Void)?

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var lastHandledEventTimestamp: TimeInterval?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            if window.firstResponder is NSText {
                self.onTextFieldFocused?()
            }
        }
        return result
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitors()
        guard window != nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  window.isKeyWindow else {
                return event
            }

            // 如果当前焦点在名称输入框（NSText），绝不拦截其正常输入（仅支持无候选词时按 Tab 跳入第 1 个数字格）
            if let textView = window.firstResponder as? NSText {
                if event.keyCode == 48,
                   event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                   (textView as? NSTextView)?.hasMarkedText() != true {
                    DispatchQueue.main.async { [weak self] in
                        self?.onTabFromTextField?()
                    }
                    return nil
                }
                return event
            }

            guard self.isActive else {
                return event
            }

            // 不拦截带 Command / Control / Option 修饰键的快捷键
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                return event
            }

            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
            if self.onKeyDown?(event) == true {
                self.lastHandledEventTimestamp = event.timestamp
                return nil
            }
            return event
        }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  self.isActive,
                  let window = self.window,
                  event.window === window else {
                return event
            }
            let localPoint = self.convert(event.locationInWindow, from: nil)
            if !self.bounds.contains(localPoint) {
                DispatchQueue.main.async { [weak self] in
                    self?.onClickOutsideDigits?()
                }
            }
            return event
        }
    }

    override func keyDown(with event: NSEvent) {
        if lastHandledEventTimestamp == event.timestamp {
            return
        }
        if isActive,
           !(window?.firstResponder is NSText),
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           onKeyDown?(event) == true {
            lastHandledEventTimestamp = event.timestamp
            return
        }
        super.keyDown(with: event)
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    deinit {
        removeMonitors()
    }
}
