import Combine
import Sparkle
import SwiftUI

@main
struct BrewyApp: App {
    @State private var brewService = BrewService()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    @AppStorage("appTheme")
    private var appTheme = AppTheme.system.rawValue
    @AppStorage("appLanguage")
    private var appLanguage = AppLanguage.system.rawValue

    // HACK: there is a known color scheme bug in SwiftUI where passing `nil` to `.preferredColorScheme`
    // doesn't change the color of some elements:
    // https://stackoverflow.com/questions/76123702/preferredcolorschemenil-visual-bug-when-switching-to-system-light-dark-more
    private var systemColorScheme: ColorScheme? {
        switch NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
        case .aqua: .light
        case .darkAqua: .dark
        default: nil
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme(rawValue: appTheme)?.colorScheme
    }

    private var preferredLocale: Locale {
        AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(brewService)
                .environment(\.locale, preferredLocale)
                .preferredColorScheme(preferredColorScheme ?? systemColorScheme)
                .background(WindowTransparencySetup())
        }
        .windowStyle(.automatic)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(after: .newItem) {
                Button("Refresh Packages") {
                    Task { await brewService.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Upgrade All") {
                    Task { await brewService.upgradeAll() }
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Cleanup...") {
                    Task { await brewService.cleanup() }
                }
            }
            CommandGroup(replacing: .help) {
                Button("What's New") {
                    NotificationCenter.default.post(name: .showWhatsNew, object: nil)
                }
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
                .environment(brewService)
        } label: {
            let count = brewService.outdatedPackages.count
            Label(
                count > 0 ? "\(count)" : "Brewy",
                systemImage: count > 0 ? "mug.fill" : "mug"
            )
        }
        .environment(\.locale, preferredLocale)
    }
}

// MARK: - Sparkle Updates

@MainActor
@Observable
private final class CheckForUpdatesViewModel {
    var canCheckForUpdates = false
    @ObservationIgnored private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }
}

private struct CheckForUpdatesView: View {
    @State private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        _viewModel = State(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

// MARK: - Window Transparency Setup

/// Makes the main window transparent so that the sidebar can show a true
/// Windows 10-style .behindWindow acrylic blur of the desktop behind the app.
private struct WindowTransparencySetup: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    private func configureWindow() {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // Keep the system title bar available; only the content area is clear
        // so the sidebar's .behindWindow material can sample the desktop.
        window.titlebarAppearsTransparent = false
    }
}

// MARK: - Menu Bar View

private struct MenuBarView: View {
    @Environment(BrewService.self)
    private var brewService
    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        let outdatedCount = brewService.outdatedPackages.count

        if outdatedCount > 0 {
            Text(String(format: String(localized: "%d package(s) outdated"), outdatedCount))
            Divider()
            Button("Upgrade All") {
                Task { await brewService.upgradeAll() }
            }
        } else {
            Text("All packages up to date")
        }

        Divider()

        Button("Refresh") {
            Task { await brewService.refresh() }
        }
        .keyboardShortcut("r")

        Divider()

        Button("Open Brewy") {
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Button("Quit Brewy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
