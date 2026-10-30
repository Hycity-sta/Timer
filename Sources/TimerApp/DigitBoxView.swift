import SwiftUI

struct DigitBoxView: View {
    let index: Int
    let value: Int
    let isEditable: Bool
    let isFocused: Bool

    var onSelect: () -> Void
    var onIncrement: () -> Void
    var onDecrement: () -> Void

    @State private var isHovered = false

    private var isHighlighted: Bool {
        isHovered || isFocused
    }

    private var chevronColor: Color {
        if isFocused {
            return .accentColor
        } else if isHovered {
            return .primary.opacity(0.65)
        } else {
            return .secondary.opacity(0.4)
        }
    }

    private var borderColor: Color {
        if isFocused {
            return .accentColor
        } else if isHovered && isEditable {
            return .primary.opacity(0.22)
        } else {
            return .primary.opacity(0.1)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // 上方微调按钮（卡片外部）
            Button(action: onIncrement) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(chevronColor)
                    .frame(width: 50, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .opacity(isEditable ? (isHighlighted ? 1.0 : 0.25) : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isHighlighted)
            .animation(.easeInOut(duration: 0.15), value: isFocused)

            // 中间纯净数字卡片
            ZStack {
                // 背景卡片
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(isFocused ? 0.08 : 0.04), radius: isFocused ? 6 : 2, x: 0, y: 1)

                // 边框高亮
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        borderColor,
                        lineWidth: isFocused ? 2.5 : (isHovered && isEditable ? 1.5 : 1)
                    )

                // 数字显示
                Text("\(value)")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isEditable ? .primary : Color.accentColor)
            }
            .frame(width: 54, height: 68)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditable {
                    onSelect()
                }
            }

            // 下方微调按钮（卡片外部）
            Button(action: onDecrement) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(chevronColor)
                    .frame(width: 50, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .opacity(isEditable ? (isHighlighted ? 1.0 : 0.25) : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isHighlighted)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable {
                onSelect()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
