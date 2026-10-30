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

    var body: some View {
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
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(isEditable ? .primary : Color.accentColor)

            // 鼠标悬停时的微调浮层按钮（小巧精致）
            if isEditable && isHovered {
                VStack {
                    Button(action: onIncrement) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onDecrement) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
                .transition(.opacity)
            }
        }
        .frame(width: 54, height: 74)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if isEditable {
                onSelect()
            }
        }
    }
}
