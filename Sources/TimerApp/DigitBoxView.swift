import SwiftUI

struct DigitBoxView: View {
    let index: Int
    @Binding var digit: Int
    let isEditable: Bool
    var isFocused: Bool
    var onSelect: () -> Void
    var onIncrement: () -> Void
    var onDecrement: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            if isEditable {
                Button(action: onIncrement) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isHovered ? .primary : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isFocused ? 1.0 : 0.0)
                .frame(height: 12)
            } else {
                Spacer().frame(height: 12)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isFocused ? Color.accentColor : Color.primary.opacity(0.12),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)

                Text("\(digit)")
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isEditable ? .primary : Color.accentColor)
            }
            .frame(width: 52, height: 68)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditable {
                    onSelect()
                }
            }

            if isEditable {
                Button(action: onDecrement) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isHovered ? .primary : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isFocused ? 1.0 : 0.0)
                .frame(height: 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
