import SwiftUI

/// Shows a transient message banner at the top of the screen.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(spacing: 10) {
                        Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isError ? Theme.Colors.danger : Theme.Colors.success)
                        Text(message)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background {
                        NineSlice(piece: Chrome.toast, scale: 0.7)
                            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                    }
                    .padding(.bottom, 12)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("toast")
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.2))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.message = nil
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.2), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, isError: Bool = false) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}
