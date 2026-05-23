import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home, profiles, hotkeys, appearance, general, permissions, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:        return "Home"
        case .profiles:    return "Profiles"
        case .hotkeys:     return "Hotkeys"
        case .appearance:  return "Appearance"
        case .general:     return "General"
        case .permissions: return "Permissions"
        case .about:       return "About"
        }
    }

    var symbol: String {
        switch self {
        case .home:        return "house"
        case .profiles:    return "person.crop.rectangle.stack"
        case .hotkeys:     return "command"
        case .appearance:  return "paintbrush"
        case .general:     return "gear"
        case .permissions: return "lock.shield"
        case .about:       return "info.circle"
        }
    }
}

struct MainWindowView: View {

    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .home

    var body: some View {
        let needsOnboarding = !appState.settingsStore.settings.hasCompletedOnboarding

        Group {
            if needsOnboarding {
                OnboardingView(onFinish: {
                    appState.settingsStore.settings.hasCompletedOnboarding = true
                })
            } else {
                NavigationSplitView {
                    List(Tab.allCases, selection: $selectedTab) { tab in
                        Label(tab.title, systemImage: tab.symbol)
                            .tag(tab)
                    }
                    .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
                } detail: {
                    content(for: selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                }
                .navigationTitle("CursorConfine")
            }
        }
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        switch tab {
        case .home:        HomeView()
        case .profiles:    ProfilesView()
        case .hotkeys:     HotkeysView()
        case .appearance:  AppearanceView()
        case .general:     GeneralView()
        case .permissions: PermissionsView()
        case .about:       AboutView()
        }
    }
}
