import SwiftUI
import AppKit

// MARK: - Fluent UI Helpers

/// A SwiftUI wrapper around NSVisualEffectView that mimics Windows 10 Acrylic material.
/// Acrylic recipe: background blur, exclusion/contrast layer, color tint, and subtle noise.
struct AcrylicBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var cornerRadius: CGFloat = 0
    var tintColor: NSColor? = nil
    var drawNoise: Bool = true
    var drawBorder: Bool = true

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
    /// Applies a Windows 10-style acrylic background with square corners.
    func fluentAcrylicBackground(
        material: NSVisualEffectView.Material = .popover,
        cornerRadius: CGFloat = 0,
        drawNoise: Bool = true
    ) -> some View {
        self.background(
            AcrylicBackgroundView(
                material: material,
                blendingMode: .behindWindow,
                cornerRadius: cornerRadius,
                drawNoise: drawNoise
            )
        )
    }

    /// Removes default list row insets and rounded corners for a dense Windows 10 sidebar feel.
    func fluentSidebarRow() -> some View {
        self.listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
        case .installed: "square.grid.2x2"
        case .formulae: "terminal"
        case .casks: "macwindow"
        case .masApps: "bag"
        case .outdated: "arrow.triangle.2.circlepath"
        case .pinned: "pin"
        case .leaves: "leaf"
        case .taps: "square.and.arrow.down"
        case .services: "gearshape.2"
        case .groups: "folder"
        case .history: "clock.arrow.circlepath"
        case .discover: "magnifyingglass"
        case .maintenance: "wrench.and.screwdriver"
        }
    }
}

// MARK: - Accent Color

extension Color {
    /// Classic Windows 10 accent blue.
    static var fluentAccent: Color { Color(red: 0.0, green: 0.471, blue: 0.843) } // #0078D7
}
