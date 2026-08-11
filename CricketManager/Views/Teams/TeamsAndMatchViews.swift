import SwiftUI

// MARK: - Teams View
struct TeamsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var vm = TeamsViewModel()
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    PageHeader(title: "Team Manager", subtitle: "Build your squads").padding(.top, 8)
                    TeamPanel(side: .a, vm: vm)
                    TeamPanel(side: .b, vm: vm)
                    GreenButton("Set Up Match →") { withAnimation { appVM.selectedTab = 1 } }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }.navigationViewStyle(.stack)
    }
}

struct PageHeader: View {
    let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text("🏏").font(.system(size: 22)); Text("Cricket").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text); Text(".").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.gold); Text("Manager").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text) }
            Text(subtitle).font(.system(size: 13)).foregroundColor(Theme.text2)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TeamPanel: View {
    let side: TeamSide; @ObservedObject var vm: TeamsViewModel
    @EnvironmentObject var appVM: AppViewModel
    var team: CricketTeam { appVM.team(for: side) }
    var accent: Color { side == .a ? Theme.green : Theme.cyan }
    var isAdding: Bool { side == .a ? vm.isAddingPlayerA : vm.isAddingPlayerB }
    var body: some View {
        CricketCard {
            HStack {
                if side == .a {
                    TextField("Team name", text: $appVM.teamA.name)
                        .font(.system(size: 20, weight: .bold)).foregroundColor(accent)
                } else {
                    TextField("Team name", text: $appVM.teamB.name)
                        .font(.system(size: 20, weight: .bold)).foregroundColor(accent)
                }
                Spacer()
                BadgeView(text: side == .a ? "TEAM A" : "TEAM B", color: accent)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .overlay(Divider().background(Theme.border), alignment: .bottom)

            HStack {
                Text("\(team.players.count) player\(team.players.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundColor(Theme.text3)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if side == .a { vm.isAddingPlayerA.toggle() } else { vm.isAddingPlayerB.toggle() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAdding ? "xmark" : "plus").font(.system(size: 11, weight: .bold))
                        Text(isAdding ? "Cancel" : "Add Player").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(isAdding ? Theme.text3 : accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accent.opacity(isAdding ? 0.05 : 0.1)).cornerRadius(8)
                }
            }
            .padding(.horizontal, 18).padding(.top, 14)

            if isAdding {
                AddPlayerForm(side: side, accent: accent, vm: vm)
                    .padding(.horizontal, 18).padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if team.players.isEmpty {
                Text("No players yet. Tap + Add Player above.")
                    .font(.system(size: 13)).foregroundColor(Theme.text3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24).padding(.horizontal, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(team.players) { p in
                        PlayerRow(player: p) { appVM.removePlayer(from: side, id: p.id) }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
        }
    }
}

struct AddPlayerForm: View {
    let side: TeamSide; let accent: Color; @ObservedObject var vm: TeamsViewModel
    @EnvironmentObject var appVM: AppViewModel
    @FocusState private var focused: Bool
    var name: Binding<String> { side == .a ? $vm.newNameA : $vm.newNameB }
    var role: Binding<PlayerRole> { side == .a ? $vm.newRoleA : $vm.newRoleB }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(PlayerRole.allCases) { r in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { role.wrappedValue = r } } label: {
                        VStack(spacing: 3) {
                            Text(r.icon).font(.system(size: 16))
                            Text(r.short).font(.system(size: 9, weight: .bold)).tracking(1)
                        }
                        .foregroundColor(role.wrappedValue == r ? r.color : Theme.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(role.wrappedValue == r ? r.color.opacity(0.15) : Theme.surface3)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(role.wrappedValue == r ? r.color : Color.clear, lineWidth: 1.5))
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Player name…", text: name)
                    .font(.system(size: 14)).foregroundColor(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface3).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border2, lineWidth: 1))
                    .focused($focused).submitLabel(.done)
                    .onSubmit { vm.addPlayer(to: side, appVM: appVM) }
                Button { vm.addPlayer(to: side, appVM: appVM) } label: {
                    Text("+ Add").font(.system(size: 13, weight: .bold)).tracking(1)
                        .foregroundColor(Color(hex: "#0a0e1a"))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.goldGrad).cornerRadius(10)
                }
            }
        }
        .padding(14).background(Theme.surface2).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .onAppear { focused = true }
    }
}

struct PlayerRow: View {
    let player: Player; let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            PlayerAvatar(name: player.name, role: player.role)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                Text(player.role.label).font(.system(size: 11)).foregroundColor(Theme.text3)
            }
            Spacer()
            RolePill(role: player.role)
            Button(action: onDelete) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.text3).frame(width: 22, height: 22)
                    .background(Theme.surface3).cornerRadius(6)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Theme.surface2).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .padding(.vertical, 2)
    }
}

// MARK: - Match Setup View
struct MatchSetupView: View {
    @EnvironmentObject var appVM: AppViewModel
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    PageHeader(title: "Match Setup", subtitle: "Configure your match").padding(.top, 8)
                    MatchTeamsSection()
                    OversSection()
                    MatchSummarySection()
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }.navigationViewStyle(.stack)
    }
}

struct MatchTeamsSection: View {
    @EnvironmentObject var appVM: AppViewModel
    var body: some View {
        CricketCard {
            CardHeader(title: "① Playing Teams")
            HStack(spacing: 12) {
                TeamSummaryCard(team: appVM.teamA, gradient: Theme.teamAGrad)
                Text("VS").font(.system(size: 16, weight: .black)).foregroundColor(Theme.gold)
                TeamSummaryCard(team: appVM.teamB, gradient: Theme.teamBGrad)
            }.padding(16)
            Text("Rename teams on the Teams tab").font(.system(size: 11)).foregroundColor(Theme.text3)
                .frame(maxWidth: .infinity).padding(.bottom, 14)
        }
    }
}

struct TeamSummaryCard: View {
    let team: CricketTeam; let gradient: LinearGradient
    var body: some View {
        VStack(spacing: 6) {
            Text(team.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(team.players.count) players").font(.system(size: 11)).foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(gradient).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct OversSection: View {
    @EnvironmentObject var appVM: AppViewModel
    let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    var body: some View {
        CricketCard {
            CardHeader(title: "② Select Overs")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(appVM.availableOvers, id: \.self) { o in
                    OverButton(overs: o, isSelected: appVM.selectedOvers == o) {
                        withAnimation(.easeInOut(duration: 0.15)) { appVM.selectedOvers = o }
                    }
                }
            }.padding(16)
        }
    }
}

struct OverButton: View {
    let overs: Int; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(overs)").font(.system(size: 22, weight: .bold)).foregroundColor(isSelected ? Theme.gold : Theme.text2)
                Text("Overs").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundColor(isSelected ? Theme.gold.opacity(0.7) : Theme.text3)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(isSelected ? Theme.gold.opacity(0.1) : Theme.surface2).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.gold : Theme.border, lineWidth: isSelected ? 1.5 : 1))
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
    }
}

struct MatchSummarySection: View {
    @EnvironmentObject var appVM: AppViewModel
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                SummaryChip(label: "Team A", value: appVM.teamA.name)
                Rectangle().fill(Theme.border).frame(width: 1, height: 36)
                SummaryChip(label: "Team B", value: appVM.teamB.name)
                Rectangle().fill(Theme.border).frame(width: 1, height: 36)
                SummaryChip(label: "Overs", value: appVM.selectedOvers.map { "\($0)" } ?? "—")
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.surface2).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border2, lineWidth: 1))

            if !appVM.isMatchReady {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill").foregroundColor(Theme.amber).font(.system(size: 13))
                    Text(appVM.teamA.players.isEmpty || appVM.teamB.players.isEmpty ? "Add players to both teams to continue" : "Select number of overs above")
                        .font(.system(size: 13)).foregroundColor(Theme.amber)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.amber.opacity(0.08)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.amber.opacity(0.2), lineWidth: 1))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { appVM.showTossSheet = true } label: {
                HStack(spacing: 10) {
                    Text("🏏")
                    Text("START SCORING").font(.system(size: 16, weight: .bold)).tracking(3)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(appVM.isMatchReady ? AnyView(Theme.greenGrad) : AnyView(Theme.surface3))
                .cornerRadius(16)
                .shadow(color: appVM.isMatchReady ? Theme.green.opacity(0.35) : .clear, radius: 14, y: 7)
            }
            .disabled(!appVM.isMatchReady)
        }
    }
}

struct SummaryChip: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundColor(Theme.text3).textCase(.uppercase)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Toss Sheet
struct TossSheet: View {
    @EnvironmentObject var appVM: AppViewModel
    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("🪙").font(.system(size: 44))
                    Text("TOSS TIME").font(.system(size: 24, weight: .black)).tracking(4).foregroundColor(Theme.text)
                    Text("Who won the toss and bats first?").font(.system(size: 14)).foregroundColor(Theme.text2)
                }.padding(.top, 8)
                HStack(spacing: 14) { TossTeamButton(side: .a); TossTeamButton(side: .b) }.padding(.horizontal, 20)
                Button { appVM.confirmToss() } label: {
                    HStack(spacing: 8) { Text("⚡"); Text("CONFIRM & START MATCH").font(.system(size: 15, weight: .bold)).tracking(2) }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(appVM.tossWinner != nil ? AnyView(Theme.greenGrad) : AnyView(Color(Theme.surface3)))
                        .cornerRadius(14)
                }
                .disabled(appVM.tossWinner == nil).padding(.horizontal, 20)
                Spacer()
            }
        }
    }
}

struct TossTeamButton: View {
    let side: TeamSide; @EnvironmentObject var appVM: AppViewModel
    var team: CricketTeam { appVM.team(for: side) }
    var other: TeamSide { side == .a ? .b : .a }
    var isBatting: Bool { appVM.tossWinner == side }
    var isFielding: Bool { appVM.tossWinner == other }
    var body: some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { appVM.tossWinner = side } } label: {
            VStack(spacing: 8) {
                Text(team.name).font(.system(size: 16, weight: .bold)).foregroundColor(isBatting ? .white : Theme.text).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                if isBatting { HStack(spacing: 4) { Text("🏏"); Text("BATTING FIRST").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(Theme.bat) } }
                else if isFielding { HStack(spacing: 4) { Text("🎯"); Text("BOWLING FIRST").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(Theme.bowl) } }
                else { Text("Tap to select").font(.system(size: 11)).foregroundColor(Theme.text3) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(isBatting ? AnyView(LinearGradient(colors: [Theme.bat.opacity(0.25), Theme.bat.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)) : isFielding ? AnyView(LinearGradient(colors: [Theme.bowl.opacity(0.15), Theme.bowl.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(Color(Theme.surface2)))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isBatting ? Theme.bat : isFielding ? Theme.bowl : Theme.border2, lineWidth: isBatting ? 2 : 1))
            .scaleEffect(isBatting ? 1.03 : 1.0)
        }
    }
}
