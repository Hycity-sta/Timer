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

    var body: some View {
        VStack(spacing: 4) {
            // 上方微调按钮（卡片外部）
            Button(action: onIncrement) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isHighlighted ? .accentColor : .secondary.opacity(0.4))
                    .frame(width: 50, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .opacity(isEditable ? (isHighlighted ? 1.0 : 0.25) : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isHighlighted)

            // 中间纯净数字卡片
            ZStack {
                // 背景卡片
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(isFocused ? 0.08 : 0.04), radius: isFocused ? 6 : 2, x: 0, y: 1)

                // 边框高亮
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isFocused ? 2.5 : 1
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
                    .foregroundColor(isHighlighted ? .accentColor : .secondary.opacity(0.4))
                    .frame(width: 50, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .opacity(isEditable ? (isHighlighted ? 1.0 : 0.25) : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
