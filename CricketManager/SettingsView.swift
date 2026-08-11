import SwiftUI

// MARK: - Theme Mode

/// User-selectable appearance. Persisted via @AppStorage and applied at the app
/// root through `.preferredColorScheme`. Theme's structural colors adapt to the
/// resolved color scheme automatically.
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// nil lets the system decide; otherwise force the chosen scheme.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Shared key so the App entry point and Settings screen read the same value.
let themeModeStorageKey = "appThemeMode"

/// "1.0 (1)" style version string sourced from the bundle Info.plist.
var appVersionString: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    return "\(version) (\(build))"
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage(themeModeStorageKey) private var themeMode: ThemeMode = .dark

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    PageHeader(title: "Settings", subtitle: "Personalise your app").padding(.top, 8)

                    // Appearance
                    CricketCard {
                        CardHeader(title: "Appearance")
                        ForEach(Array(ThemeMode.allCases.enumerated()), id: \.element.id) { index, mode in
                            ThemeModeRow(mode: mode, isSelected: themeMode == mode) {
                                withAnimation(.easeInOut(duration: 0.2)) { themeMode = mode }
                            }
                            if index < ThemeMode.allCases.count - 1 {
                                Divider().background(Theme.border).padding(.leading, 18)
                            }
                        }
                    }

                    // About
                    CricketCard {
                        CardHeader(title: "About")
                        HStack {
                            Text("Version").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                            Spacer()
                            Text(appVersionString).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text2)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 16)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }.navigationViewStyle(.stack)
    }
}

private struct ThemeModeRow: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.gold : Theme.text2)
                    .frame(width: 24)
                Text(mode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.gold)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(FeedbackButtonStyle())
    }
}
