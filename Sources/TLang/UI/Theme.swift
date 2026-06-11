import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Adaptive color that resolves per-appearance (light/dark) at render time.
    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            let alpha = isDark ? darkAlpha : lightAlpha
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha
            )
        })
    }
}

/// "Lapis & Gold" — inspired by illuminated Arabic manuscripts.
/// English is lapis, Arabic is gold; translation is the gradient between.
/// Every color adapts to light (paper) and dark (night) appearances.
enum Theme {
    // MARK: Surfaces
    static let background = Color(light: 0xF4F5FA, dark: 0x161B2C)
    static let ink = Color(light: 0xFFFFFF, dark: 0x1D2440)

    static let card = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.75, darkAlpha: 0.07)
    static let cardHover = Color(light: 0x141A38, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.11)
    static let field = Color(light: 0x141A38, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.09)
    static let stroke = Color(light: 0x141A38, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.13)
    static let strokeStrong = Color(light: 0x141A38, dark: 0xFFFFFF, lightAlpha: 0.18, darkAlpha: 0.22)
    static let toggleOff = Color(light: 0x141A38, dark: 0xFFFFFF, lightAlpha: 0.15, darkAlpha: 0.17)
    static let shadow = Color(light: 0x141A38, dark: 0x000000, lightAlpha: 0.10, darkAlpha: 0.28)

    // MARK: Background glows
    static let glowLapis = Color(light: 0x3D55E8, dark: 0x4C63F0, lightAlpha: 0.08, darkAlpha: 0.22)
    static let glowGold = Color(light: 0xB98A1E, dark: 0xE9B949, lightAlpha: 0.06, darkAlpha: 0.10)

    // MARK: Brand
    static let lapis = Color(light: 0x3D55E8, dark: 0x86A0FF)
    static let lapisDeep = Color(light: 0x2F43C4, dark: 0x5570F2)
    static let teal = Color(light: 0x12939C, dark: 0x65D5DC)
    static let gold = Color(light: 0xA97E14, dark: 0xF0C45F)
    static let goldSoft = Color(light: 0xC99A2E, dark: 0xF6D98B)
    static let coral = Color(light: 0xD14B33, dark: 0xF58A73)
    static let green = Color(light: 0x238C4E, dark: 0x72D89D)

    // MARK: Text
    static let textPrimary = Color(light: 0x171A29, dark: 0xF1F2F8)
    static let textSecondary = textPrimary.opacity(0.62)
    static let textTertiary = textPrimary.opacity(0.4)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x171204)

    // MARK: Gradients
    static let accentGradient = LinearGradient(
        colors: [lapis, teal, gold],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let logoGradient = LinearGradient(
        colors: [Color(hex: 0x2F43C4), Color(hex: 0x5570F2), Color(hex: 0xD8A52E)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let borderGradient = LinearGradient(
        colors: [lapis.opacity(0.5), gold.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// English = lapis, Arabic = gold.
    static func languageColor(isArabic: Bool) -> Color {
        isArabic ? gold : lapis
    }
}

/// How the app resolves light vs dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Cycle order for the quick switch in the main window: Auto → Light → Dark.
    var next: AppearanceMode {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }

    @MainActor
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Layered background: paper with faint lapis/gold washes in light mode,
/// night ink with a lapis glow and gold dawn in dark mode.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.glowLapis, .clear],
                center: UnitPoint(x: 0.1, y: -0.15),
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [Theme.glowGold, .clear],
                center: UnitPoint(x: 0.98, y: 1.2),
                startRadius: 0,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

/// Brand mark: gradient rounded square with the Arabic letter ت.
struct LogoMark: View {
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Theme.logoGradient)
            .frame(width: size, height: size)
            .overlay(
                Text("ت")
                    .font(.system(size: size * 0.58, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -size * 0.05)
            )
            .shadow(color: Color(hex: 0x2F43C4, alpha: 0.4), radius: size * 0.25, y: 2)
    }
}

// MARK: - Modifiers

/// Card surface. On macOS 26+ this adopts the system Liquid Glass material;
/// earlier systems get the custom translucent card.
struct GlassCard: ViewModifier {
    var focus: Color?
    var radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(
                    shape.strokeBorder(focus.map { $0.opacity(0.5) } ?? .clear, lineWidth: 1)
                )
                .shadow(
                    color: focus.map { $0.opacity(0.18) } ?? .clear,
                    radius: 14,
                    y: 4
                )
                .animation(.easeOut(duration: 0.18), value: focus != nil)
        } else {
            content
                .background(shape.fill(Theme.card))
                .overlay(
                    shape.strokeBorder(focus.map { $0.opacity(0.5) } ?? Theme.stroke, lineWidth: 1)
                )
                .shadow(
                    color: focus.map { $0.opacity(0.16) } ?? Theme.shadow,
                    radius: focus == nil ? 10 : 16,
                    y: 4
                )
                .animation(.easeOut(duration: 0.18), value: focus != nil)
        }
    }
}

extension View {
    func glassCard(focus: Color? = nil, radius: CGFloat = 14) -> some View {
        modifier(GlassCard(focus: focus, radius: radius))
    }
}

struct UppercaseLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .kerning(1.4)
            .foregroundStyle(Theme.textTertiary)
    }
}

// MARK: - Control styles

struct PillToggleStyle: ToggleStyle {
    var tint: Color = Theme.lapis

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                Capsule()
                    .fill(configuration.isOn ? tint : Theme.toggleOff)
                    .frame(width: 27, height: 16)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .padding(2)
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
                configuration.label
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(configuration.isOn ? Theme.textPrimary : Theme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.accentGradient))
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: Theme.gold.opacity(isEnabled ? 0.3 : 0), radius: 9, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(configuration.isPressed ? Theme.cardHover : Theme.field))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.coral)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.coral.opacity(configuration.isPressed ? 0.28 : 0.16)))
            .overlay(Capsule().strokeBorder(Theme.coral.opacity(0.4), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Circular icon button used in headers and toolbars.
struct IconButton: View {
    let systemImage: String
    var active = false
    var help = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Theme.gold : (hovering ? Theme.textPrimary : Theme.textSecondary))
                .frame(width: 27, height: 27)
                .background(Circle().fill(active || hovering ? Theme.cardHover : Theme.field))
                .overlay(Circle().strokeBorder(active ? Theme.gold.opacity(0.35) : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
