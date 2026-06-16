import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System"
    case english = "English"
    case russian = "Русский"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system: return Locale.current
        case .english: return Locale(identifier: "en")
        case .russian: return Locale(identifier: "ru")
        }
    }

    var displayName: String { rawValue }
}

struct SettingsView: View {
    @AppStorage("brewPath")
    private var brewPath = "/opt/homebrew/bin/brew"
    @AppStorage("autoRefreshInterval")
    private var autoRefreshInterval = 0
    @AppStorage("showCasksByDefault")
    private var showCasksByDefault = false
    @AppStorage("appTheme")
    private var appTheme = AppTheme.system.rawValue
    @AppStorage("appLanguage")
    private var appLanguage = AppLanguage.system.rawValue

    private var isBrewPathValid: Bool {
        FileManager.default.isExecutableFile(atPath: brewPath)
    }

    var body: some View {
        Form {
            TextField("Homebrew Path:", text: $brewPath)
                .help("Path to the brew executable")
            if !brewPath.isEmpty, !isBrewPathValid {
                Text("No executable found at this path.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Picker("Auto-refresh:", selection: $autoRefreshInterval) {
                Text("Off").tag(0)
                Text("Every 5 minutes").tag(300)
                Text("Every 15 minutes").tag(900)
                Text("Every hour").tag(3_600)
            }

            Picker("Appearance:", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme.rawValue)
                }
            }

            Picker("Language:", selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }

            Toggle("Show Casks by default", isOn: $showCasksByDefault)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 450, height: 260)
    }
}
