import SwiftUI

/// The primary call to action: a molten slab set in basalt that sinks when pressed.
struct LavaButtonStyle: ButtonStyle {
    var isProminent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(19))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(isEnabled ? Chrome.moltenInk : Theme.Colors.textSecondary)
            .shadow(color: .white.opacity(isEnabled ? 0.35 : 0), radius: 0, y: 1)
            .padding(.vertical, 18)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, minHeight: 60)
            // The pressed art sits ~4 pt lower, so the label follows it down.
            .offset(y: configuration.isPressed ? 2 : -1)
            .background {
                NineSlice(piece: !isEnabled ? Chrome.disabled : (configuration.isPressed ? Chrome.moltenPressed : Chrome.molten), scale: 0.9)
                    .shadow(color: Theme.Colors.lava.opacity(isProminent && isEnabled ? 0.45 : 0), radius: configuration.isPressed ? 6 : 16, y: 4)
            }
            .animation(.spring(duration: 0.18, bounce: 0.3), value: configuration.isPressed)
    }
}

/// The secondary action: a chiselled basalt slab with light text.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 52)
            .offset(y: configuration.isPressed ? 2 : -1)
            .background {
                NineSlice(piece: configuration.isPressed ? Chrome.stonePressed : Chrome.stone, scale: 0.8)
            }
            .animation(.spring(duration: 0.18, bounce: 0.3), value: configuration.isPressed)
    }
}

/// Compact molten slab for inline actions such as forging or unlocking.
struct CompactLavaButtonStyle: ButtonStyle {
    var isEnabledLook = true

    func makeBody(configuration: Configuration) -> some View {
        let piece = !isEnabledLook ? Chrome.disabled : (configuration.isPressed ? Chrome.moltenPressed : Chrome.molten)
        return configuration.label
            .font(.display(15))
            .textCase(.uppercase)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(isEnabledLook ? Chrome.moltenInk : Theme.Colors.background)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .frame(minWidth: 88, minHeight: 44)
            .offset(y: configuration.isPressed ? 1.5 : -0.5)
            .background { NineSlice(piece: piece, scale: 0.68) }
            .animation(.spring(duration: 0.18, bounce: 0.3), value: configuration.isPressed)
    }
}

/// A round carved stone medallion for icon buttons (pause, settings).
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(Theme.Colors.ember)
            .shadow(color: Theme.Colors.lava.opacity(0.6), radius: 4)
            .offset(y: configuration.isPressed ? 1 : 0)
            .frame(width: 48, height: 48)
            .background {
                Image(configuration.isPressed ? Chrome.roundButtonPressed : Chrome.roundButton)
                    .resizable()
                    .scaledToFit()
            }
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}
