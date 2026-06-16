import SwiftUI
import AppKit

// MARK: - Acrylic Background View

/// A SwiftUI wrapper around NSVisualEffectView that mimics Windows 10 Acrylic material.
/// Uses the native sidebar blur with within-window blending so it stays visible in all states.
struct AcrylicBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies a stable, Windows 10-style acrylic background with square corners.
    func fluentAcrylicBackground(
        material: NSVisualEffectView.Material = .popover,
        cornerRadius: CGFloat = 0
    ) -> some View {
        self.background(
            AcrylicBackgroundView(
                material: material,
                cornerRadius: cornerRadius
            )
        )
    }

    /// Applies a subtle color tint on top of an acrylic background.
    func fluentAcrylicTint(_ color: Color = .fluentAccent, opacity: Double = 0.06) -> some View {
        self.overlay(color.opacity(opacity).allowsHitTesting(false))
    }
}

// MARK: - Fluent Icons

/// Windows 10 MDL2-style glyph icons. Outlined, sharp, and square.
enum FluentIcon: String, CaseIterable {
    case installed = "square.grid.2x2"
    case formulae = "terminal"
    case casks = "macwindow"
    case masApps = "bag"
    case outdated = "arrow.triangle.2.circlepath"
    case pinned = "pin"
    case leaves = "leaf"
    case taps = "square.and.arrow.down"
    case services = "gearshape.2"
    case groups = "folder"
    case history = "clock.arrow.circlepath"
    case discover = "magnifyingglass"
    case maintenance = "wrench.and.screwdriver"

    var systemName: String { rawValue }
}

// MARK: - Sidebar Category Icon Mapping

extension SidebarCategory {
    /// Fluent / Windows 10 style outline icon for this category.
    var fluentSystemImage: String {
        switch self {
        case .installed: FluentIcon.installed.systemName
        case .formulae: FluentIcon.formulae.systemName
        case .casks: FluentIcon.casks.systemName
        case .masApps: FluentIcon.masApps.systemName
        case .outdated: FluentIcon.outdated.systemName
        case .pinned: FluentIcon.pinned.systemName
        case .leaves: FluentIcon.leaves.systemName
        case .taps: FluentIcon.taps.systemName
        case .services: FluentIcon.services.systemName
        case .groups: FluentIcon.groups.systemName
        case .history: FluentIcon.history.systemName
        case .discover: FluentIcon.discover.systemName
        case .maintenance: FluentIcon.maintenance.systemName
        }
    }
}

// MARK: - Accent Color

extension Color {
    /// Classic Windows 10 accent blue.
    static var fluentAccent: Color { Color(red: 0.0, green: 0.471, blue: 0.843) } // #0078D7
}

// MARK: - Fluent Fonts (Windows 10 / Segoe UI)

extension Font {
    /// Returns Segoe UI if installed, otherwise Selawik, otherwise the system font.
    static func fluent(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base = NSFont(name: "Segoe UI", size: size)
            ?? NSFont(name: "Selawik", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: weight.nsFontWeight)

        let nsFont: NSFont
        if base.fontName == "SegoeUI" || base.fontName == "SegoeUI-Regular" ||
            base.fontName == "Selawik" || base.fontName == "Selawik-Regular" {
            // Apply bold/unbold traits for custom fonts via NSFontManager.
            let traits: NSFontTraitMask = weight.isBold ? .boldFontMask : .unboldFontMask
            nsFont = NSFontManager.shared.convert(base, toHaveTrait: traits)
        } else {
            nsFont = base
        }

        return Font(nsFont as CTFont)
    }

    static var fluentBody: Font { fluent(size: 13) }
    static var fluentCaption: Font { fluent(size: 11) }
    static var fluentHeadline: Font { fluent(size: 14, weight: .semibold) }
    static var fluentTitle: Font { fluent(size: 18, weight: .semibold) }
}

extension Font.Weight {
    var nsFontWeight: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    var isBold: Bool {
        switch self {
        case .medium, .semibold, .bold, .heavy, .black: return true
        default: return false
        }
    }
}
