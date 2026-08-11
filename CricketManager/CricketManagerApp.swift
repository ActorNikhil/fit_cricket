import SwiftUI
import SwiftData

@main
struct CricketManagerApp: App {
    @StateObject private var appVM = AppViewModel()
    @AppStorage(themeModeStorageKey) private var themeMode: ThemeMode = .dark
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .preferredColorScheme(themeMode.colorScheme)
                .buttonStyle(FeedbackButtonStyle())
        }
        .modelContainer(for: [SavedTeam.self, PlayerCareerStat.self, RegisteredPlayer.self, CompletedMatch.self])
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
                    case 3: MatchHistoryView()
                    case 4: PlayersView()
                    default: SettingsView()
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
                        Text("Third").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        Text("Umpire").font(.system(size: 26, weight: .bold)).foregroundColor(Theme.gold)
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
    let tabs: [(String, String, Int)] = [("person.2.fill","Teams",0),("sportscourt.fill","Match",1),("trophy.fill","Stats",2),("flag.checkered","History",3),("person.crop.circle.fill","Players",4),("gearshape.fill","Settings",5)]
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
