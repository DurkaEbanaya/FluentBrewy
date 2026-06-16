import SwiftUI
import AppKit

extension Notification.Name {
    static let showWhatsNew = Notification.Name("showWhatsNew")
}

// MARK: - Package Navigation Environment

extension EnvironmentValues {
    @Entry var selectPackage: @MainActor @Sendable (String) -> Void = { _ in }
}

struct ContentView: View {
    @Environment(BrewService.self)
    private var brewService
    @AppStorage("autoRefreshInterval")
    private var autoRefreshInterval = 0
    @AppStorage("showCasksByDefault")
    private var showCasksByDefault = false
    @AppStorage("lastSeenVersion")
    private var lastSeenVersion = ""
    @AppStorage("uiScale")
    private var savedUIScale = 1.0
    @AppStorage("sidebarWidth")
    private var savedSidebarWidth = 240.0
    @AppStorage("contentColumnWidth")
    private var savedContentColumnWidth = 350.0
    @State private var selectedCategory: SidebarCategory? = .installed
    @State private var selectedPackage: BrewPackage?
    @State private var selectedTap: BrewTap?
    @State private var selectedServiceItem: BrewServiceItem?
    @State private var selectedGroupItem: PackageGroup?
    @State private var selectedHistoryEntry: ActionHistoryEntry?
    @State private var servicesRefreshTrigger = 0
    // periphery:ignore - Mutated through PackageListView's searchable binding.
    @State private var searchText = ""
    @State private var showWhatsNew = false
    @State private var uiScale = 1.0
    @State private var pendingUIScale = 1.0
    @State private var sidebarWidth = 240.0
    @State private var contentColumnWidth = 350.0
    @State private var sidebarDragStartWidth: Double?
    @State private var contentDragStartWidth: Double?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selectedCategory: $selectedCategory,
                uiScale: Binding(
                    get: { pendingUIScale },
                    set: { pendingUIScale = $0 }
                ),
                commitUIScalePreview: {
                    uiScale = pendingUIScale
                    savedUIScale = pendingUIScale
                }
            )
                .frame(width: sidebarWidth)
                .clipShape(Rectangle())

            ResizableColumnDivider { translation in
                let startWidth = sidebarDragStartWidth ?? sidebarWidth
                sidebarDragStartWidth = startWidth
                sidebarWidth = min(max(startWidth + translation, 200), 360)
            } onEnded: {
                sidebarDragStartWidth = nil
                savedSidebarWidth = sidebarWidth
            }

            NavigationStack {
                contentView
                    .contentBackground()
            }
            .frame(width: shouldShowDetailColumn ? contentColumnWidth : nil)
            .frame(maxWidth: shouldShowDetailColumn ? contentColumnWidth : .infinity, maxHeight: .infinity)

            if shouldShowDetailColumn {
                ResizableColumnDivider { translation in
                    let startWidth = contentDragStartWidth ?? contentColumnWidth
                    contentDragStartWidth = startWidth
                    contentColumnWidth = min(max(startWidth + translation, 280), 620)
                } onEnded: {
                    contentDragStartWidth = nil
                    savedContentColumnWidth = contentColumnWidth
                }

                NavigationStack {
                    detailView
                        .contentBackground()
                }
                .frame(minWidth: 450, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .dynamicTypeSize(dynamicTypeSize(for: uiScale))
        .controlSize(controlSize(for: uiScale))
        .environment(\.interfaceScale, uiScale)
        .background(Color.clear)
        .environment(\.selectPackage) { name in navigateToPackage(name) }
        .onAppear {
            uiScale = savedUIScale
            pendingUIScale = savedUIScale
            sidebarWidth = savedSidebarWidth
            contentColumnWidth = savedContentColumnWidth
        }
        .task {
            if showCasksByDefault {
                selectedCategory = .casks
            }
            brewService.loadFromCache()
            brewService.loadTapHealthCache()
            brewService.loadGroups()
            brewService.loadHistory()
            brewService.loadLastUpdateResult()
            // Skip non-deterministic startup work under tests: real `brew` subprocesses
            // hang the runner, and the WhatsNew sheet's modal AX hierarchy hides the sidebar.
            // XCTestBundlePath is set by unit-test hosts; BREWY_UI_TESTING is set by UI-test setUp.
            let env = ProcessInfo.processInfo.environment
            guard env["XCTestBundlePath"] == nil, env["BREWY_UI_TESTING"] != "1" else { return }
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            if !currentVersion.isEmpty, currentVersion != lastSeenVersion {
                lastSeenVersion = currentVersion
                showWhatsNew = true
            }
            await brewService.refresh()
        }
        .task(id: autoRefreshInterval) {
            guard autoRefreshInterval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoRefreshInterval))
                guard !Task.isCancelled else { break }
                await brewService.refresh()
            }
        }
        .onChange(of: selectedCategory) {
            // Cleared here (not in PackageListView, which is torn down when switching to a
            // non-package category like Discover and would leave a stale detail showing).
            selectedPackage = nil
            selectedTap = nil
            selectedServiceItem = nil
            selectedGroupItem = nil
            selectedHistoryEntry = nil
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { brewService.lastError != nil },
                set: { if !$0 { brewService.lastError = nil } }
            ),
            presenting: brewService.lastError
        ) { _ in
            Button("OK") { brewService.lastError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showWhatsNew)) { _ in
            showWhatsNew = true
        }
    }

    @ViewBuilder private var contentView: some View {
        if selectedCategory == .masApps, !brewService.isMasAvailable {
            MasSetupView()
        } else if selectedCategory == .taps {
            TapListView(selectedTap: $selectedTap)
        } else if selectedCategory == .services {
            ServicesView(selectedService: $selectedServiceItem, refreshTrigger: servicesRefreshTrigger)
        } else if selectedCategory == .groups {
            GroupsView(selectedGroup: $selectedGroupItem)
        } else if selectedCategory == .history {
            HistoryView(selectedEntry: $selectedHistoryEntry)
        } else if selectedCategory == .discover {
            DiscoverView(selectedPackage: $selectedPackage)
        } else if selectedCategory == .maintenance {
            MaintenanceView()
        } else {
            PackageListView(
                selectedCategory: selectedCategory,
                selectedPackage: $selectedPackage,
                searchText: $searchText
            )
        }
    }

    private var shouldShowDetailColumn: Bool {
        selectedCategory != .maintenance && !(selectedCategory == .masApps && !brewService.isMasAvailable)
    }

    private func dynamicTypeSize(for scale: Double) -> DynamicTypeSize {
        switch scale {
        case ..<0.9: .xSmall
        case ..<1.0: .small
        case ..<1.1: .medium
        case ..<1.2: .large
        default: .xLarge
        }
    }

    private func controlSize(for scale: Double) -> ControlSize {
        switch scale {
        case ..<0.95: .small
        case ..<1.15: .regular
        default: .large
        }
    }

    @ViewBuilder private var detailView: some View {
        if selectedCategory == .maintenance || (selectedCategory == .masApps && !brewService.isMasAvailable) {
            Color.clear
        } else if selectedCategory == .services, let service = selectedServiceItem {
            ServiceDetailView(service: service) {
                servicesRefreshTrigger &+= 1
            }
            .id(service.id)
        } else if selectedCategory == .services {
            EmptyStateView(
                icon: "gearshape.2",
                title: "Select a Service",
                subtitle: "Choose a service from the list to view its details and controls."
            )
        } else if selectedCategory == .groups, let group = selectedGroupItem,
                  let currentGroup = brewService.packageGroups.first(where: { $0.id == group.id }) {
            GroupDetailView(group: currentGroup)
                .id(group.id)
        } else if selectedCategory == .groups {
            EmptyStateView(
                icon: "folder",
                title: "Select a Group",
                subtitle: "Choose a group from the list to view its packages."
            )
        } else if selectedCategory == .history, let entry = selectedHistoryEntry {
            HistoryDetailView(entry: entry)
                .id(entry.id)
        } else if selectedCategory == .history {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "Select an Action",
                subtitle: "Choose an action from the history to view its details."
            )
        } else if selectedCategory == .taps, let tap = selectedTap {
            TapDetailView(tap: tap)
        } else if selectedCategory == .taps {
            EmptyStateView(
                icon: "spigot",
                title: "Select a Tap",
                subtitle: "Choose a tap from the list to view its details."
            )
        } else if let selectedPackage {
            let package = brewService.allInstalled.first(where: { $0.id == selectedPackage.id }) ?? selectedPackage
            PackageDetailView(package: package)
                .id(package.id)
        } else {
            EmptyStateView(lastUpdated: brewService.lastUpdated)
        }
    }

    private func navigateToPackage(_ name: String) {
        if let match = brewService.allInstalled.first(where: { $0.name == name }) {
            switch match.source {
            case .formula: selectedCategory = .formulae
            case .cask: selectedCategory = .casks
            case .mas: selectedCategory = .masApps
            }
            selectedPackage = match
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var icon: String = "shippingbox"
    var title: String = "Select a Package"
    var subtitle: String = "Choose a package from the list to view its details."
    var lastUpdated: Date?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
            if icon == "shippingbox" {
                Text("\u{2318}R to refresh  \u{00B7}  \u{2318}U to upgrade all")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .padding(.top, 4)
            }
            if let lastUpdated {
                Text("Last refreshed \(Self.relativeTime(since: lastUpdated))")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func relativeTime(since date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return String(localized: "just now") }
        if minutes == 1 { return String(localized: "1 min ago") }
        if minutes < 60 { return String(format: String(localized: "%d min ago"), minutes) }
        let hours = minutes / 60
        if hours == 1 { return String(localized: "1 hour ago") }
        return String(format: String(localized: "%d hours ago"), hours)
    }
}

// MARK: - Content Background

private extension View {
    /// Opaque background for content/detail columns so that the transparent window
    /// only reveals the desktop behind the sidebar acrylic.
    func contentBackground() -> some View {
        self.background(Color(nsColor: .windowBackgroundColor))
    }

}

private struct InterfaceScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var interfaceScale: Double {
        get { self[InterfaceScaleKey.self] }
        set { self[InterfaceScaleKey.self] = newValue }
    }
}

private struct ResizableColumnDivider: View {
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color(nsColor: .separatorColor)
                .frame(width: 1)
        }
        .frame(width: 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onChanged(value.translation.width)
                }
                .onEnded { _ in
                    onEnded()
                }
        )
        .horizontalResizeCursor()
        .ignoresSafeArea(edges: .vertical)
    }
}

private extension View {
    func horizontalResizeCursor() -> some View {
        modifier(HorizontalResizeCursorModifier())
    }
}

private struct HorizontalResizeCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering, !isHovering {
                NSCursor.resizeLeftRight.push()
                isHovering = true
            } else if !hovering, isHovering {
                NSCursor.pop()
                isHovering = false
            }
        }
    }
}
