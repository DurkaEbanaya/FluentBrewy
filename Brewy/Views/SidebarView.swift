import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(\.interfaceScale)
    private var interfaceScale
    @Binding var selectedCategory: SidebarCategory?
    @Binding var uiScale: Double
    let commitUIScalePreview: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Packages")
                ForEach(SidebarCategory.packageCategories) { category in
                    SidebarButton(
                        category: category,
                        selectedCategory: $selectedCategory
                    )
                }

                sectionHeader("Management")
                ForEach(SidebarCategory.managementCategories) { category in
                    SidebarButton(
                        category: category,
                        selectedCategory: $selectedCategory
                    )
                }

                sectionHeader("Tools")
                ForEach(SidebarCategory.toolCategories) { category in
                    SidebarButton(
                        category: category,
                        selectedCategory: $selectedCategory
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .fluentAcrylicBackground(cornerRadius: 0)
        .fluentAcrylicTint(.fluentAccent, opacity: 0.06)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter(
                uiScale: $uiScale,
                commitUIScalePreview: commitUIScalePreview
            )
                .fluentAcrylicBackground(cornerRadius: 0)
                .fluentAcrylicTint(.fluentAccent, opacity: 0.06)
        }
        .navigationTitle("Brewy")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.fluent(size: 11 * interfaceScale))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12 * interfaceScale)
            .padding(.top, 12 * interfaceScale)
            .padding(.bottom, 4 * interfaceScale)
    }
}

// MARK: - Sidebar Button

private struct SidebarButton: View {
    @Environment(BrewService.self)
    private var brewService
    @Environment(\.interfaceScale)
    private var interfaceScale
    let category: SidebarCategory
    @Binding var selectedCategory: SidebarCategory?

    private var isSelected: Bool {
        selectedCategory == category
    }

    var body: some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 0) {
                Image(systemName: category.fluentSystemImage)
                    .font(.system(size: 16 * interfaceScale, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 24 * interfaceScale, alignment: .center)

                Text(category.localizedName)
                    .font(.fluent(size: 13 * interfaceScale))
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.fluent(size: 11 * interfaceScale))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 6 * interfaceScale)
            .padding(.horizontal, 12 * interfaceScale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(category.rawValue)
        .background(
            isSelected ? Color.fluentAccent : Color.clear,
            in: .rect(cornerRadius: 0)
        )
    }

    private var count: Int? {
        switch category {
        case .masApps: brewService.isMasAvailable ? brewService.packages(for: category).count : nil
        case .taps: brewService.installedTaps.count
        case .services: nil
        case .groups: brewService.packageGroups.isEmpty ? nil : brewService.packageGroups.count
        case .history: brewService.actionHistory.isEmpty ? nil : brewService.actionHistory.count
        case .discover: nil
        case .maintenance: nil
        default: brewService.packages(for: category).count
        }
    }
}

// MARK: - Sidebar Footer

private struct SidebarFooter: View {
    @Environment(BrewService.self)
    private var brewService
    @Environment(\.interfaceScale)
    private var interfaceScale
    @Binding var uiScale: Double
    let commitUIScalePreview: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scale")
                        .font(.fluent(size: 11 * interfaceScale))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((uiScale * 100).rounded()))%")
                        .font(.fluent(size: 11 * interfaceScale))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Slider(value: $uiScale, in: 0.8...1.3, step: 0.01) { editing in
                    if !editing {
                        commitUIScalePreview()
                    }
                }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12 * interfaceScale)
            .padding(.vertical, 8 * interfaceScale)

            Divider()
            HStack(spacing: 8) {
                Button {
                    Task { await brewService.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.fluent(size: 11 * interfaceScale))
                }
                .buttonStyle(.borderless)
                .disabled(brewService.isLoading)

                Spacer()

                if brewService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let lastUpdated = brewService.lastUpdated {
                    Text(Self.relativeTime(since: lastUpdated))
                        .font(.fluent(size: 11 * interfaceScale))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12 * interfaceScale)
            .padding(.vertical, 8 * interfaceScale)
        }
    }

    private static func relativeTime(since date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return String(localized: "Just now") }
        if minutes == 1 { return String(localized: "1 min ago") }
        if minutes < 60 { return String(format: String(localized: "%d min ago"), minutes) }
        let hours = minutes / 60
        if hours == 1 { return String(localized: "1 hour ago") }
        return String(format: String(localized: "%d hours ago"), hours)
    }
}
