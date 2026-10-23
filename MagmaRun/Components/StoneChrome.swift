import SwiftUI

/// A painted, 9-slice stretchable piece of the generated UI kit.
/// Corners and borders stay crisp; only the plain middle band stretches.
struct NineSlice: View {
    let piece: Chrome.Piece
    /// Draws the art smaller than authored so small controls keep proportional borders.
    var scale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Image(piece.name)
                .resizable(capInsets: piece.caps, resizingMode: .stretch)
                .frame(width: proxy.size.width / scale, height: proxy.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .accessibilityHidden(true)
    }
}

/// Catalogue of the stretchable UI kit painted by `Artwork/generate_assets.swift`.
enum Chrome {
    struct Piece: Equatable {
        let name: String
        let caps: EdgeInsets

        init(_ name: String, top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
            self.name = name
            caps = EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        }

        init(_ name: String, all: CGFloat) {
            self.init(name, top: all, leading: all, bottom: all, trailing: all)
        }
    }

    static let molten = Piece("btn_molten", all: 28)
    static let moltenPressed = Piece("btn_molten_pressed", all: 28)
    static let stone = Piece("btn_stone", all: 28)
    static let stonePressed = Piece("btn_stone_pressed", all: 28)
    static let disabled = Piece("btn_disabled", all: 28)
    static let panel = Piece("panel_stone", all: 40)
    static let panelLava = Piece("panel_lava", all: 40)
    static let plaque = Piece("panel_plaque", top: 30, leading: 60, bottom: 30, trailing: 60)
    static let toast = Piece("panel_toast", all: 30)
    static let chip = Piece("chip_stone", all: 20)
    static let barFrame = Piece("bar_frame", top: 12, leading: 16, bottom: 12, trailing: 16)
    static let barFill = Piece("bar_fill", top: 8, leading: 10, bottom: 8, trailing: 10)
    static let emberCounter = Piece("ember_counter", top: 20, leading: 50, bottom: 20, trailing: 24)
    static let stele = Piece("stele_result", top: 120, leading: 60, bottom: 80, trailing: 60)

    static let roundButton = "btn_round"
    static let roundButtonPressed = "btn_round_pressed"
    static let socketEmpty = "socket_empty"
    static let socketFull = "socket_full"
    static let divider = "divider_flame"
    static let pedestal = "pedestal"
    static let menuTablet = "menu_tablet"

    /// Dark text that reads on the molten button face.
    static let moltenInk = Color(red: 0.2, green: 0.06, blue: 0.03)
}

/// A carved obsidian nameplate with flame finials, used for titles.
struct StonePlaque<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 44)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(NineSlice(piece: Chrome.plaque, scale: 0.6))
    }
}

/// A molten progress bar set into a carved stone trough.
struct StoneBar: View {
    let progress: Double
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let inset = height * 0.2
            let fillWidth = (proxy.size.width - inset * 2) * clamped
            ZStack(alignment: .leading) {
                NineSlice(piece: Chrome.barFrame, scale: height / 28)
                if fillWidth > height * 0.5 {
                    NineSlice(piece: Chrome.barFill, scale: (height - inset * 2) / 20)
                        .frame(width: fillWidth, height: height - inset * 2)
                        .padding(.leading, inset)
                }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: progress)
        .accessibilityHidden(true)
    }
}

/// The ornamental flame divider between sections.
struct FlameDivider: View {
    var body: some View {
        Image(Chrome.divider)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)
            .frame(height: 20)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// Inline, gold navigation title with a carved stone back medallion instead of the system chevron.
struct StoneNavigation: ViewModifier {
    let title: String
    var showsBackButton = true
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        let styled = content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(showsBackButton)
            .toolbarBackground(Theme.Colors.background.opacity(0.92), for: .navigationBar)
        if !showsBackButton {
            styled
        } else if #available(iOS 26.0, *) {
            // Keep the system glass capsule from wrapping the painted medallion.
            styled.toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .principal) { titleView }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            styled.toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton }
                ToolbarItem(placement: .principal) { titleView }
            }
        }
    }

    private var titleView: some View {
        Text(title)
            .font(.display(24))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Theme.Colors.ember)
            .shadow(color: Theme.Colors.lava.opacity(0.5), radius: 6)
            .accessibilityAddTraits(.isHeader)
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
        }
        .buttonStyle(IconButtonStyle())
        .accessibilityLabel("Back")
    }
}

extension View {
    func stoneNavigation(_ title: String, showsBackButton: Bool = true) -> some View {
        modifier(StoneNavigation(title: title, showsBackButton: showsBackButton))
    }
}

/// A switch carved into stone: the knob is an empty socket when off and fills with lava when on.
struct StoneToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    NineSlice(piece: Chrome.barFrame, scale: 1)
                        .frame(width: 62, height: 30)
                        .overlay {
                            if configuration.isOn {
                                NineSlice(piece: Chrome.barFill, scale: 0.9)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 7)
                            }
                        }
                    Image(configuration.isOn ? Chrome.socketFull : Chrome.socketEmpty)
                        .resizable()
                        .frame(width: 34, height: 34)
                        .padding(.horizontal, -2)
                }
                .frame(width: 62, height: 34)
                .animation(.spring(duration: 0.25, bounce: 0.35), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
