import SwiftUI
import SwiftData

@main
struct CricketManagerApp: App {
    @StateObject private var appVM = AppViewModel()
    @AppStorage(themeModeStorageKey) private var themeMode: ThemeMode = .dark
    var body: some Scene {
        WindowGroup {
            RootAuthGate()
                .environmentObject(appVM)
                .preferredColorScheme(themeMode.colorScheme)
                .buttonStyle(FeedbackButtonStyle())
        }
        .modelContainer(for: [SavedTeam.self, PlayerCareerStat.self, RegisteredPlayer.self, CompletedMatch.self, UserProfile.self])
    }
}

struct RootView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var showSplash = true
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Theme.bgGrad.ignoresSafeArea().opacity(0.6)
            GridTexture().ignoresSafeArea().opacity(0.4)
            VStack(spacing: 0) {
                Group {
                    switch appVM.selectedTab {
                    case 0: TeamsView()
                    case 1: MatchSetupView()
                    case 2: LeaderboardView()
                    case 3: CaloriesView()
                    default: MoreView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                CustomTabBar()
            }
        }
        .sheet(isPresented: $appVM.showTossSheet) {
            TossSheet().presentationDetents([.fraction(0.55)]).presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $appVM.showMatchStarted) {
            if let match = appVM.activeMatch {
                ScoringRootView(match: match)
            }
        }
        .overlay {
            if showSplash {
                SplashView().transition(.opacity).zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
        }
    }
}

// MARK: - Splash Screen
// An in-app splash shown briefly on launch, matching the app icon's artwork
// (the system launch screen only flashes for a moment and can't be prolonged).
struct SplashView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#125036"), Color(hex: "#0c3122"), Color(hex: "#06120d")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            RadialGradient(
                colors: [Theme.gold.opacity(0.16), .clear],
                center: .center, startRadius: 0, endRadius: 320
            ).ignoresSafeArea()

            VStack(spacing: 22) {
                Image("LaunchLogo")
                    .resizable().scaledToFit()
                    .frame(width: 190, height: 190)
                    .scaleEffect(animate ? 1.0 : 0.78)
                    .opacity(animate ? 1 : 0)
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Fit").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        Text("Cricket").font(.system(size: 26, weight: .bold)).foregroundColor(Theme.gold)
                    }
                    Text("MATCH • SCORE • WIN")
                        .font(.system(size: 11, weight: .semibold)).tracking(4)
                        .foregroundColor(.white.opacity(0.55))
                }
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) { animate = true }
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var appVM: AppViewModel
    let tabs: [(String, String, Int)] = [("person.2.fill","Teams",0),("sportscourt.fill","Match",1),("trophy.fill","Stats",2),("flame.fill","Calories",3),("ellipsis.circle.fill","More",4)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.2) { icon, label, idx in
                Button { withAnimation(.easeInOut(duration: 0.2)) { appVM.selectedTab = idx } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                        Text(label).font(.system(size: 10, weight: .semibold)).tracking(1).textCase(.uppercase)
                    }
                    .foregroundColor(appVM.selectedTab == idx ? Theme.gold : Theme.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
            }
        }
        .padding(.bottom, 4)
        .background(Theme.surface1.overlay(Divider().background(Theme.border), alignment: .top))
        .overlay(
            GeometryReader { geo in
                let w = geo.size.width / CGFloat(tabs.count)
                RoundedRectangle(cornerRadius: 2).fill(Theme.goldGrad)
                    .frame(width: w * 0.4, height: 2)
                    .offset(x: w * CGFloat(appVM.selectedTab) + w * 0.3, y: 0)
                    .animation(.spring(response: 0.3), value: appVM.selectedTab)
            }, alignment: .top
        )
    }
}

// MARK: - More Tab
// Groups the secondary screens (History, Players, Settings) under a single tab
// to keep the main tab bar simple. Shows a menu of destinations and slides the
// selected screen in with a Back control.
struct MoreView: View {
    @State private var selection: MoreDestination? = nil

    var body: some View {
        Group {
            if let selection {
                VStack(spacing: 0) {
                    // Back bar returning to the menu.
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { self.selection = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                                Text("More").font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(Theme.gold)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 2)

                    destinationView(for: selection)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                menu
            }
        }
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                PageHeader(title: "More", subtitle: "History, players & settings").padding(.top, 8)

                CricketCard {
                    CardHeader(title: "More")
                    ForEach(Array(MoreDestination.allCases.enumerated()), id: \.element) { index, item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selection = item }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.gold)
                                    .frame(width: 24)
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.text3)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(FeedbackButtonStyle())
                        if index < MoreDestination.allCases.count - 1 {
                            Divider().background(Theme.border).padding(.leading, 18)
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func destinationView(for item: MoreDestination) -> some View {
        switch item {
        case .profile:  ProfileView()
        case .history:  MatchHistoryView()
        case .players:  PlayersView()
        case .settings: SettingsView()
        }
    }
}

enum MoreDestination: CaseIterable, Hashable {
    case profile, history, players, settings

    var title: String {
        switch self {
        case .profile:  return "Profile"
        case .history:  return "History"
        case .players:  return "Players"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .profile:  return "person.crop.circle.fill"
        case .history:  return "flag.checkered"
        case .players:  return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
