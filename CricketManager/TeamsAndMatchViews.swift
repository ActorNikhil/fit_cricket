import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import Charts

// MARK: - Teams View (Library)
struct TeamsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedTeam.createdAt, order: .reverse) private var teams: [SavedTeam]
    @State private var editingTeam: SavedTeam?
    @State private var editingTeamIsNew = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PageHeader(title: "Team Manager", subtitle: "Your saved squads").padding(.top, 8)

                    GoldButton(title: "New Team", icon: "➕") {
                        let team = SavedTeam(name: "")
                        context.insert(team)
                        // Persist immediately so the model has its permanent
                        // persistentModelID before it becomes the sheet's item.
                        // Otherwise the temporary→permanent ID switch changes the
                        // item identity and tears down TeamEditorView mid-typing,
                        // resetting @State/@FocusState (the "one letter" bug).
                        // The team is only kept if the user taps Done in the editor;
                        // dismissing without confirming deletes it (see TeamEditorView).
                        try? context.save()
                        editingTeamIsNew = true
                        editingTeam = team
                    }

                    if teams.isEmpty {
                        VStack(spacing: 8) {
                            Text("🏟️").font(.system(size: 40))
                            Text("No teams yet")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                            Text("Tap “New Team” to build your first squad. Saved teams stay here for every future match.")
                                .font(.system(size: 13)).foregroundColor(Theme.text3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 20)
                    } else {
                        ForEach(teams) { team in
                            SavedTeamCard(team: team) { editingTeamIsNew = false; editingTeam = team }
                                onDelete: { context.delete(team) }
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $editingTeam) { team in
            TeamEditorView(team: team, isNewTeam: editingTeamIsNew)
        }
    }
}

// MARK: - Saved team card (library row)
struct SavedTeamCard: View {
    @Bindable var team: SavedTeam
    let onEdit: () -> Void
    let onDelete: () -> Void
    var body: some View {
        CricketCard {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name.isEmpty ? "Untitled Team" : team.name)
                            .font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
                            .lineLimit(1)
                        Text("\(team.players.count) player\(team.players.count == 1 ? "" : "s")")
                            .font(.system(size: 12)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text3)
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
            }
            if !team.orderedPlayers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(team.orderedPlayers.prefix(6)) { p in
                        PlayerAvatar(name: p.name, role: p.role, size: 28)
                    }
                    if team.players.count > 6 {
                        Text("+\(team.players.count - 6)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.red).frame(width: 28, height: 28)
                            .background(Theme.red.opacity(0.12)).cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            } else {
                HStack {
                    Text("No players yet").font(.system(size: 12)).foregroundColor(Theme.text3)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.red).frame(width: 28, height: 28)
                            .background(Theme.red.opacity(0.12)).cornerRadius(8)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 12)
            }
        }
    }
}

struct PageHeader: View {
    let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) { Text("🏏").font(.system(size: 22)); Text("Fit").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text); Text("Cricket").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.gold) }
            Text(subtitle).font(.system(size: 13)).foregroundColor(Theme.text2)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Team Editor (create / edit a saved team)
struct TeamEditorView: View {
    @Bindable var team: SavedTeam
    // When true, the team was just created by "New Team" and is only kept if the
    // user taps Done. Dismissing any other way deletes the unsaved team.
    var isNewTeam: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var newRole: PlayerRole = .bat
    @State private var didConfirm = false
    @FocusState private var focusedField: Field?
    @Query private var allTeams: [SavedTeam]

    // Directory search (Supabase profiles of everyone who created an account).
    @State private var searchText = ""
    @State private var searchResults: [DirectoryPlayer] = []
    @State private var isSearching = false
    @State private var searchError: String?

    private enum Field: Hashable { case teamName, search }

    // Search hits, minus anyone already on a team (matched by display name).
    private var filteredResults: [DirectoryPlayer] {
        let assigned = Set(allTeams.flatMap { $0.players.map(\.name) })
        return searchResults.filter { !$0.displayName.isEmpty && !assigned.contains($0.displayName) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CricketCard {
                        HStack {
                            TextField("Team name", text: $team.name)
                                .autocorrectionDisabled()
                                .font(.system(size: 20, weight: .bold)).foregroundColor(Theme.green)
                                .focused($focusedField, equals: .teamName)
                            Spacer()
                            Text("🏏").font(.system(size: 20))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(focusedField == .teamName ? Theme.green : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: focusedField == .teamName ? Theme.green.opacity(0.3) : .clear, radius: 8)
                        .animation(.easeInOut(duration: 0.15), value: focusedField)
                    }

                    CricketCard {
                        CardHeader(title: "Add Player")
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                ForEach(PlayerRole.allCases) { r in
                                    Button { withAnimation(.easeInOut(duration: 0.15)) { newRole = r } } label: {
                                        VStack(spacing: 3) {
                                            Text(r.icon).font(.system(size: 16))
                                            Text(r.short).font(.system(size: 9, weight: .bold)).tracking(1)
                                        }
                                        .foregroundColor(newRole == r ? r.color : Theme.text3)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(newRole == r ? r.color.opacity(0.15) : Theme.surface3)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(newRole == r ? r.color : Color.clear, lineWidth: 1.5))
                                    }
                                }
                            }
                            // Search the player directory by name or phone number.
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14)).foregroundColor(Theme.text3)
                                TextField("Search players by name or phone", text: $searchText)
                                    .font(.system(size: 14)).foregroundColor(Theme.text)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedField, equals: .search)
                                if isSearching {
                                    ProgressView().scaleEffect(0.7)
                                } else if !searchText.isEmpty {
                                    Button { searchText = ""; searchResults = [] } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14)).foregroundColor(Theme.text3)
                                    }
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Theme.surface2).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .search ? Theme.green : Theme.border,
                                        lineWidth: focusedField == .search ? 2 : 1))

                            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text("Search the player directory to add members to your team.")
                                    .font(.system(size: 12)).foregroundColor(Theme.text3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 2)
                            } else if filteredResults.isEmpty && !isSearching {
                                Text(searchError.map { "Search failed: \($0)" } ?? "No players found for “\(searchText)”.")
                                    .font(.system(size: 12)).foregroundColor(searchError == nil ? Theme.text3 : Theme.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 2)
                            } else {
                                Text("Tap a player to add as \(newRole.label)")
                                    .font(.system(size: 11)).foregroundColor(Theme.text3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(spacing: 6) {
                                    ForEach(filteredResults) { dp in
                                        Button { addPlayer(named: dp.displayName) } label: {
                                            HStack(spacing: 10) {
                                                PlayerAvatar(name: dp.displayName, role: newRole)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(dp.displayName)
                                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                                                    if !dp.phone.isEmpty {
                                                        Text(dp.phone)
                                                            .font(.system(size: 11)).foregroundColor(Theme.text3)
                                                    }
                                                }
                                                Spacer()
                                                Text("+ Add").font(.system(size: 12, weight: .bold)).tracking(1)
                                                    .foregroundColor(Color(hex: "#0a0e1a"))
                                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                                    .background(Theme.goldGrad).cornerRadius(8)
                                            }
                                            .padding(.horizontal, 8).padding(.vertical, 6)
                                            .background(Theme.surface2).cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }

                    if team.orderedPlayers.isEmpty {
                        Text("No players yet. Add players above.")
                            .font(.system(size: 13)).foregroundColor(Theme.text3)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(team.orderedPlayers) { p in
                                PlayerRow(player: Player(name: p.name, role: p.role)) {
                                    context.delete(p)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(isNewTeam ? "New Team" : "Edit Team")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: searchText) { await runSearch() }
            .task {
                // For a brand-new team, focus the name field on appear so the
                // keyboard is up and the user can type the name right away.
                guard isNewTeam else { return }
                try? await Task.sleep(for: .milliseconds(350))
                focusedField = .teamName
            }
            .toolbar {
                if isNewTeam {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        didConfirm = true
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            // A new team is only persisted when the user confirms with Done.
            // Any other dismissal (Cancel or swipe-down) discards it. Cascade
            // delete removes any players that were added while editing.
            if isNewTeam && !didConfirm {
                context.delete(team)
                try? context.save()
            }
        }
    }

    private func addPlayer(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let player = SavedPlayer(name: trimmed, role: newRole, order: team.players.count)
        player.team = team
        context.insert(player)
        searchText = ""
        searchResults = []
    }

    // Debounced directory search (runs whenever searchText changes).
    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchError = nil
        try? await Task.sleep(for: .milliseconds(300))   // debounce
        if Task.isCancelled { return }
        do {
            let results = try await searchDirectory(query)
            if Task.isCancelled { return }
            searchResults = results
        } catch {
            if Task.isCancelled { return }
            searchResults = []
            searchError = error.localizedDescription
            #if DEBUG
            print("[Directory] search error: \(error)")
            #endif
        }
        isSearching = false
    }

    // Looks players up in the Supabase `profiles` directory by name, phone or email.
    private func searchDirectory(_ query: String) async throws -> [DirectoryPlayer] {
        let pattern = "%\(query)%"
        return try await SupabaseManager.shared.client
            .from("profiles")
            .select("id,first_name,last_name,phone,email")
            .or("first_name.ilike.\(pattern),last_name.ilike.\(pattern),phone.ilike.\(pattern),email.ilike.\(pattern)")
            .limit(25)
            .execute()
            .value
    }
}

// A player found in the Supabase directory (the profiles of registered accounts).
struct DirectoryPlayer: Identifiable, Codable, Sendable {
    let id: String
    let first_name: String
    let last_name: String
    let phone: String
    let email: String

    var fullName: String {
        "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
    }

    // The name to show/add. Falls back to the email's local part for accounts
    // that registered but haven't set a name in their profile yet.
    var displayName: String {
        let name = fullName
        if !name.isEmpty { return name }
        return email.split(separator: "@").first.map(String.init) ?? email
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
    @State private var picking: TeamSide?
    var body: some View {
        CricketCard {
            CardHeader(title: "① Playing Teams")
            HStack(spacing: 12) {
                TeamSummaryCard(team: appVM.teamA, gradient: Theme.teamAGrad) { picking = .a }
                Text("VS").font(.system(size: 16, weight: .black)).foregroundColor(Theme.gold)
                TeamSummaryCard(team: appVM.teamB, gradient: Theme.teamBGrad) { picking = .b }
            }.padding(16)
            Text("Tap a team to pick from your library").font(.system(size: 11)).foregroundColor(Theme.text3)
                .frame(maxWidth: .infinity).padding(.bottom, 14)
        }
        .sheet(item: $picking) { side in
            TeamPickerSheet(side: side)
        }
    }
}

struct TeamSummaryCard: View {
    let team: CricketTeam; let gradient: LinearGradient
    let action: () -> Void
    var isSelected: Bool { !team.players.isEmpty }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(team.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(isSelected ? "\(team.players.count) players" : "Tap to choose")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(gradient).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(isSelected ? 0.1 : 0.35), lineWidth: 1))
        }
    }
}

// MARK: - Team picker (load a saved team into a match slot)
struct TeamPickerSheet: View {
    let side: TeamSide
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedTeam.createdAt, order: .reverse) private var teams: [SavedTeam]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if teams.isEmpty {
                        VStack(spacing: 8) {
                            Text("📋").font(.system(size: 36))
                            Text("No saved teams").font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                            Text("Create teams on the Teams tab first.")
                                .font(.system(size: 13)).foregroundColor(Theme.text3).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        let otherID = appVM.selectedTeamID(for: side == .a ? .b : .a)
                        ForEach(teams) { team in
                            let usedByOther = team.persistentModelID == otherID
                            let tooFew = team.players.count < 2
                            let disabled = usedByOther || tooFew
                            Button {
                                appVM.load(team, into: side)
                                dismiss()
                            } label: {
                                CricketCard {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(team.name.isEmpty ? "Untitled Team" : team.name)
                                                .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text).lineLimit(1)
                                            Text("\(team.players.count) player\(team.players.count == 1 ? "" : "s")")
                                                .font(.system(size: 12)).foregroundColor(Theme.text3)
                                        }
                                        Spacer()
                                        if usedByOther {
                                            Text("Other side").font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.text3)
                                        } else if tooFew {
                                            Text("Need 2+").font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.amber)
                                        }
                                    }
                                    .padding(.horizontal, 18).padding(.vertical, 16)
                                }
                            }
                            .disabled(disabled)
                            .opacity(disabled ? 0.5 : 1)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(side == .a ? "Choose Team A" : "Choose Team B")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
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
                        .background(appVM.tossWinner != nil ? AnyView(Theme.greenGrad) : AnyView(Theme.surface3))
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
            .background(isBatting ? AnyView(LinearGradient(colors: [Theme.bat.opacity(0.25), Theme.bat.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)) : isFielding ? AnyView(LinearGradient(colors: [Theme.bowl.opacity(0.15), Theme.bowl.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(Theme.surface2))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isBatting ? Theme.bat : isFielding ? Theme.bowl : Theme.border2, lineWidth: isBatting ? 2 : 1))
            .scaleEffect(isBatting ? 1.03 : 1.0)
        }
    }
}

// MARK: - Leaderboard
// All-time leaders across every finished match. Data comes from PlayerCareerStat,
// which is accumulated when a match ends (see ScoringViewModel.recordCareerStats).
struct LeaderboardView: View {
    @Query private var stats: [PlayerCareerStat]

    private var topScorers: [PlayerCareerStat] {
        stats.filter { $0.runs > 0 }.sorted { $0.runs > $1.runs }
    }
    private var topWicketTakers: [PlayerCareerStat] {
        stats.filter { $0.wickets > 0 }.sorted {
            $0.wickets != $1.wickets ? $0.wickets > $1.wickets : $0.economy < $1.economy
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Leaderboard", subtitle: "All-time leaders across every match")
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)

            if topScorers.isEmpty && topWicketTakers.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            if let s = topScorers.first {
                                highlightCard(title: "Highest Scorer", name: s.name, role: s.role,
                                              value: "\(s.runs)", unit: "runs", accent: Theme.bat)
                            }
                            if let w = topWicketTakers.first {
                                highlightCard(title: "Most Wickets", name: w.name, role: w.role,
                                              value: "\(w.wickets)", unit: "wkts", accent: Theme.bowl)
                            }
                        }
                        rankCard(title: "Top Run Scorers", accent: Theme.bat, players: topScorers,
                                 value: { "\($0.runs)" },
                                 sub: { "\($0.matches) \($0.matches == 1 ? "match" : "matches") · SR \(Int($0.strikeRate))" })
                        rankCard(title: "Top Wicket Takers", accent: Theme.bowl, players: topWicketTakers,
                                 value: { "\($0.wickets)" },
                                 sub: { "\($0.matches) \($0.matches == 1 ? "match" : "matches") · Econ \(String(format: "%.1f", $0.economy))" })
                    }
                    .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: Highlight cards
    private func highlightCard(title: String, name: String, role: PlayerRole,
                               value: String, unit: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1.5)
                .textCase(.uppercase).foregroundColor(Theme.text3)
            HStack(alignment: .bottom, spacing: 4) {
                Text(value).font(.system(size: 34, weight: .black)).foregroundColor(accent)
                Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text3).padding(.bottom, 6)
            }
            HStack(spacing: 8) {
                PlayerAvatar(name: name, role: role, size: 30)
                Text(name).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.35), lineWidth: 1))
    }

    // MARK: Ranked list card
    private func rankCard(title: String, accent: Color, players: [PlayerCareerStat],
                          value: @escaping (PlayerCareerStat) -> String,
                          sub: @escaping (PlayerCareerStat) -> String) -> some View {
        let shown = Array(players.prefix(10))
        return CricketCard {
            CardHeader(title: title)
            ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { idx, p in
                HStack(spacing: 12) {
                    Text("\(idx + 1)").font(.system(size: 13, weight: .black))
                        .foregroundColor(idx < 3 ? Theme.gold : Theme.text3).frame(width: 20)
                    PlayerAvatar(name: p.name, role: p.role, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text).lineLimit(1)
                        Text(sub(p)).font(.system(size: 11)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    Text(value(p)).font(.system(size: 20, weight: .black)).foregroundColor(accent)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                if idx < shown.count - 1 {
                    Divider().background(Theme.border).padding(.leading, 60)
                }
            }
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("🏆").font(.system(size: 54))
            Text("No stats yet").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
            Text("Finish a match to start building your\nall-time run scorers and wicket takers.")
                .font(.system(size: 13)).foregroundColor(Theme.text2)
                .multilineTextAlignment(.center).lineSpacing(3)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}

// MARK: - Players Registry
// A directory of self-registered players. Anyone can register with their name
// (required) plus an optional photo, phone, and email.
struct PlayersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RegisteredPlayer.createdAt, order: .reverse) private var players: [RegisteredPlayer]
    @State private var showRegister = false
    @State private var showBulkRegister = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PageHeader(title: "Players", subtitle: "Register & manage players").padding(.top, 8)

                    GoldButton(title: "Register Player", icon: "➕") { showRegister = true }
                    GreenButton(title: "Add Multiple", icon: "📋") { showBulkRegister = true }

                    if players.isEmpty {
                        VStack(spacing: 8) {
                            Text("🧍").font(.system(size: 40))
                            Text("No players registered")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                            Text("Tap “Register Player” to add yourself with your name and an optional photo, phone, and email.")
                                .font(.system(size: 13)).foregroundColor(Theme.text3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 20)
                    } else {
                        ForEach(players) { player in
                            RegisteredPlayerCard(player: player) { context.delete(player) }
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showRegister) {
            PlayerRegistrationView()
        }
        .sheet(isPresented: $showBulkRegister) {
            BulkPlayerRegistrationView()
        }
    }
}

// MARK: - Registered player card (registry row)
struct RegisteredPlayerCard: View {
    let player: RegisteredPlayer
    let onDelete: () -> Void
    var body: some View {
        CricketCard {
            HStack(spacing: 12) {
                RegisteredAvatar(player: player, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.fullName.isEmpty ? "Unnamed Player" : player.fullName)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text).lineLimit(1)
                    if !player.email.isEmpty {
                        contactLine(icon: "envelope.fill", text: player.email)
                    }
                    if !player.phone.isEmpty {
                        contactLine(icon: "phone.fill", text: player.phone)
                    }
                    if player.email.isEmpty && player.phone.isEmpty {
                        Text("No contact details").font(.system(size: 11)).foregroundColor(Theme.text3)
                    }
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.red).frame(width: 30, height: 30)
                        .background(Theme.red.opacity(0.12)).cornerRadius(8)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    private func contactLine(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(Theme.text3)
            Text(text).font(.system(size: 12)).foregroundColor(Theme.text2).lineLimit(1)
        }
    }
}

// MARK: - Registered player avatar (photo or initials)
struct RegisteredAvatar: View {
    let player: RegisteredPlayer
    var size: CGFloat = 46
    var body: some View {
        Group {
            if let data = player.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Text(player.initials.isEmpty ? "?" : player.initials)
                    .font(.system(size: size * 0.34, weight: .bold)).foregroundColor(Theme.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.gold.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.border2, lineWidth: 1))
    }
}

// MARK: - Player Registration form
struct PlayerRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var players: [RegisteredPlayer]

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var errorMessage: String?
    @FocusState private var focusedField: RegistrationField?

    private enum RegistrationField: Hashable { case firstName, lastName, phone, email }

    // Digits of the entered phone number, used for validation and duplicate checks.
    private var normalizedPhone: String { phone.filter(\.isNumber) }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        normalizedPhone.count >= 7
    }

    var body: some View {
        let previewImage = photoData.flatMap { UIImage(data: $0) }
        return NavigationStack {
            ScrollView {
                ScrollViewReader { proxy in
                VStack(spacing: 16) {
                    // Profile photo picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 8) {
                            ZStack {
                                if let previewImage {
                                    Image(uiImage: previewImage).resizable().scaledToFill()
                                        .frame(width: 96, height: 96).clipShape(Circle())
                                } else {
                                    Circle().fill(Theme.surface3).frame(width: 96, height: 96)
                                        .overlay(Image(systemName: "camera.fill")
                                            .font(.system(size: 24)).foregroundColor(Theme.text3))
                                }
                                Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 2).frame(width: 96, height: 96)
                            }
                            Text(previewImage == nil ? "Add Photo (optional)" : "Change Photo")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.gold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }

                    CricketCard {
                        CardHeader(title: "Name")
                        VStack(spacing: 10) {
                            styledField("First name", text: $firstName, icon: "person.fill", field: .firstName)
                            styledField("Last name", text: $lastName, icon: "person.fill", field: .lastName)
                        }
                        .padding(14)
                    }

                    CricketCard {
                        CardHeader(title: "Contact")
                        VStack(spacing: 10) {
                            styledField("Phone number (required)", text: $phone, icon: "phone.fill", field: .phone, keyboard: .phonePad)
                            styledField("Email address (optional)", text: $email, icon: "envelope.fill", field: .email, keyboard: .emailAddress)
                        }
                        .padding(14)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                // Keep the focused field visible above the keyboard. Without this the
                // Phone and Email fields sit behind the keyboard and can't be tapped.
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    
                    print("field=\(field)")
                    withAnimation { proxy.scrollTo(field, anchor: .center) }
                }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Register Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .alert("Cannot Register", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        // Phone number is mandatory and must be unique across registered players.
        guard normalizedPhone.count >= 7 else {
            errorMessage = "Please enter a valid phone number to register."
            return
        }
        if players.contains(where: { $0.normalizedPhone == normalizedPhone }) {
            errorMessage = "A player with this phone number is already registered."
            return
        }

        let player = RegisteredPlayer(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            photoData: photoData
        )
        context.insert(player)
        dismiss()
    }

    // Styled text field matching the app's editor fields. The whole row is a tap
    // target that focuses the field, and autofill/Contacts suggestions are disabled.
    @ViewBuilder
    private func styledField(_ placeholder: String, text: Binding<String>, icon: String,
                             field: RegistrationField, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            // Only the leading icon focuses the field on tap. The tap gesture is kept
            // off the TextField so it doesn't compete with the field's own editing
            // gestures (which previously dropped focus after a single character).
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Theme.text3).frame(width: 18)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = field }
            TextField(placeholder, text: text)
                .font(.system(size: 14)).foregroundColor(Theme.text)
                .keyboardType(keyboard)
                .textContentType(nil)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit { advanceFocus(from: field) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.surface3).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(focusedField == field ? Theme.green : Theme.border2,
                    lineWidth: focusedField == field ? 2 : 1))
        .id(field)
    }

    private func advanceFocus(from field: RegistrationField) {
        switch field {
        case .firstName: focusedField = .lastName
        case .lastName:  focusedField = .phone
        case .phone:     focusedField = .email
        case .email:     focusedField = nil
        }
    }
}

// MARK: - Bulk Player Registration
// Register many players at once by pasting a list of names — one name per line
// (commas also work). Each non-empty line becomes a player: the first word is the
// first name and the rest is the last name. Names already registered, and repeats
// within the pasted list, are skipped automatically (case-insensitive).
struct BulkPlayerRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var players: [RegisteredPlayer]

    @State private var text = ""
    @FocusState private var editorFocused: Bool

    private let placeholder = "Paste names here, one per line:\n\nNikhil\nRajesh\nArun Kumar"

    // Names parsed from the pasted text: split on new lines and commas, cleaned
    // of common list markers (so lists copied from WhatsApp/Notes paste cleanly),
    // trimmed, empties removed, and de-duplicated within the list (case-insensitive).
    private var parsedNames: [String] {
        let raw = text
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { Self.cleanName($0) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        var result: [String] = []
        for name in raw where seen.insert(name.lowercased()).inserted {
            result.append(name)
        }
        return result
    }

    // Strips leading list markers left over from pasted lists, e.g.
    // "1. Nikhil", "2) Rajesh", "- Arun", "• Vijay", "* Sam" -> just the name.
    private static func cleanName(_ line: String) -> String {
        var name = line.trimmingCharacters(in: .whitespaces)
        // Remove a leading numbered marker like "1.", "12)", "3 -".
        if let range = name.range(of: "^\\d+[\\.\\)\\-:]?\\s+", options: .regularExpression) {
            name.removeSubrange(range)
        }
        // Remove a leading bullet / dash marker like "-", "•", "*", "‣".
        if let range = name.range(of: "^[\\-\\u{2022}\\u{2023}\\*·]+\\s*", options: .regularExpression) {
            name.removeSubrange(range)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    private var existingNames: Set<String> {
        Set(players.map { $0.fullName.lowercased() })
    }

    // Only names not already registered are actually added.
    private var newNames: [String] {
        parsedNames.filter { !existingNames.contains($0.lowercased()) }
    }

    private var skippedCount: Int { parsedNames.count - newNames.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CricketCard {
                        CardHeader(title: "Player Names", trailing: AnyView(
                            Button(action: pasteFromClipboard) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.green)
                            }
                        ))
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(placeholder)
                                    .font(.system(size: 14)).foregroundColor(Theme.text3)
                                    .padding(.horizontal, 5).padding(.vertical, 8)
                            }
                            TextEditor(text: $text)
                                .font(.system(size: 14)).foregroundColor(Theme.text)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 240)
                                .focused($editorFocused)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(editorFocused ? Theme.green : Color.clear, lineWidth: 2))
                    }

                    // Live summary of what will be added.
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.badge.plus").font(.system(size: 13)).foregroundColor(Theme.green)
                        Text("\(newNames.count) player\(newNames.count == 1 ? "" : "s") to add")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text)
                        if skippedCount > 0 {
                            Text("· \(skippedCount) skipped")
                                .font(.system(size: 12)).foregroundColor(Theme.text3)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    Text("One name per line. The first word is the first name, the rest is the last name. Names already registered or repeated are skipped.")
                        .font(.system(size: 12)).foregroundColor(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Add Multiple Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(newNames.isEmpty ? "Add" : "Add \(newNames.count)", action: save)
                        .disabled(newNames.isEmpty)
                }
            }
            .onAppear { editorFocused = true }
        }
    }

    // Pull names straight from the system clipboard. This is a reliable paste
    // path when the TextEditor's long-press paste menu doesn't appear. Existing
    // text is preserved and the clipboard contents are appended on a new line.
    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string,
              !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if text.isEmpty {
            text = pasted
        } else {
            let separator = text.hasSuffix("\n") ? "" : "\n"
            text += separator + pasted
        }
    }

    private func save() {
        for name in newNames {
            let parts = name.split(separator: " ").map(String.init)
            let first = parts.first ?? name
            let last = parts.dropFirst().joined(separator: " ")
            context.insert(RegisteredPlayer(firstName: first, lastName: last))
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Calories burned estimate
// Cricket-specific estimate of energy expended by each player, derived from their
// all-time PlayerCareerStat totals (accumulated when a match ends). There is no
// HealthKit / sensor data here, so these are transparent approximations based on
// the physical activity each contribution implies:
//   • Facing a ball    — footwork, stance, reaction
//   • Running a run     — a ~20 m sprint down the pitch (boundaries aren't run)
//   • Boundary shot     — an explosive, powerful stroke
//   • Bowling a ball    — run-up plus delivery action
//   • Playing a match   — general fielding / time on the field
extension PlayerCareerStat {
    /// Runs that required running between the wickets (boundaries are excluded).
    var runningRuns: Int { max(0, runs - fours * 4 - sixes * 6) }

    var battingCalories: Double {
        Double(balls) * 0.6            // footwork per ball faced
        + Double(runningRuns) * 3.5    // sprint per run taken
        + Double(fours) * 2.0          // power in a four
        + Double(sixes) * 4.0          // power in a six
    }

    var bowlingCalories: Double {
        Double(ballsBowled) * 3.0      // run-up + delivery per ball
    }

    var fieldingCalories: Double {
        Double(matches) * 45.0         // general fielding per match played
    }

    /// Total estimated calories burned across every match.
    var caloriesBurned: Int {
        Int((battingCalories + bowlingCalories + fieldingCalories).rounded())
    }
}

// MARK: - Calories Tab
// A personal fitness view for the logged-in user (matched by name to their
// profile). Shows today's burn first, a batting/bowling/fielding pie split, and
// a rolling 30-day daily history. Data comes from dated CalorieEntry records.
struct CaloriesView: View {
    @Query(sort: \CalorieEntry.date, order: .reverse) private var entries: [CalorieEntry]
    @Query private var profiles: [UserProfile]

    private let calendar = Calendar.current

    private var profile: UserProfile? { profiles.first }

    // Start of the 30-day window (today plus the previous 29 days).
    private var windowStart: Date {
        calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .now
    }

    /// This user's calorie entries within the last 30 days.
    private var myEntries: [CalorieEntry] {
        let target = (profile?.fullName ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard !target.isEmpty else { return [] }
        return entries.filter {
            $0.playerName.trimmingCharacters(in: .whitespaces).lowercased() == target && $0.date >= windowStart
        }
    }

    private var todayEntries: [CalorieEntry] { myEntries.filter { calendar.isDateInToday($0.date) } }
    private var todayTotal: Int { todayEntries.reduce(0) { $0 + $1.total } }

    // The pie shows today's split when the user played today, otherwise the
    // last-30-days split so the chart is still meaningful on rest days.
    private var pieUsesToday: Bool { !todayEntries.isEmpty }
    private var pieSource: [CalorieEntry] { pieUsesToday ? todayEntries : myEntries }
    private var pieBatting: Double { pieSource.reduce(0) { $0 + $1.battingCalories } }
    private var pieBowling: Double { pieSource.reduce(0) { $0 + $1.bowlingCalories } }
    private var pieFielding: Double { pieSource.reduce(0) { $0 + $1.fieldingCalories } }

    private var segments: [CalorieSegment] {
        [CalorieSegment(label: "Batting", value: pieBatting, color: Theme.gold),
         CalorieSegment(label: "Bowling", value: pieBowling, color: Theme.green),
         CalorieSegment(label: "Fielding", value: pieFielding, color: Theme.cyan)]
            .filter { $0.value > 0 }
    }

    // 30-day history aggregated per calendar day, newest first.
    private var dailyHistory: [DayTotal] {
        let groups = Dictionary(grouping: myEntries) { calendar.startOfDay(for: $0.date) }
        return groups.map { day, items in
            DayTotal(date: day,
                     batting: Int(items.reduce(0) { $0 + $1.battingCalories }.rounded()),
                     bowling: Int(items.reduce(0) { $0 + $1.bowlingCalories }.rounded()),
                     fielding: Int(items.reduce(0) { $0 + $1.fieldingCalories }.rounded()),
                     total: items.reduce(0) { $0 + $1.total })
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Calories", subtitle: "Your energy burned · last 30 days")
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)

            if myEntries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        todayCard
                        pieCard
                        historyCard
                        disclaimer
                    }
                    .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: Today card
    private var todayCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.system(size: 14)).foregroundColor(Theme.gold)
                Text("TODAY").font(.system(size: 11, weight: .bold)).tracking(2).foregroundColor(Theme.text3)
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text3)
            }
            HStack(alignment: .bottom, spacing: 6) {
                Text("\(todayTotal)").font(.system(size: 52, weight: .black)).foregroundColor(Theme.gold)
                Text("kcal").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text3).padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            Text(todayTotal > 0
                 ? "Burned in \(todayEntries.count) \(todayEntries.count == 1 ? "match" : "matches") today"
                 : "No matches played today")
                .font(.system(size: 12)).foregroundColor(Theme.text3)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.surface1).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.35), lineWidth: 1))
    }

    // MARK: Pie card
    private var pieCard: some View {
        let total = Int((pieBatting + pieBowling + pieFielding).rounded())
        return CricketCard {
            CardHeader(title: pieUsesToday ? "Today's Breakdown" : "Breakdown · Last 30 Days")
            VStack(spacing: 16) {
                ZStack {
                    Chart(segments) { seg in
                        SectorMark(
                            angle: .value("kcal", seg.value),
                            innerRadius: .ratio(0.60),
                            angularInset: 2
                        )
                        .cornerRadius(4)
                        .foregroundStyle(seg.color)
                    }
                    .frame(height: 180)

                    VStack(spacing: 1) {
                        Text("\(total)").font(.system(size: 26, weight: .black)).foregroundColor(Theme.text)
                        Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text3)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(segments) { seg in
                        HStack(spacing: 10) {
                            Circle().fill(seg.color).frame(width: 10, height: 10)
                            Text(seg.label).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                            Spacer()
                            Text("\(Int(seg.value.rounded())) kcal")
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text)
                            Text(total > 0 ? "\(Int((seg.value / Double(total) * 100).rounded()))%" : "0%")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text3)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: 30-day history list
    private var historyCard: some View {
        CricketCard {
            CardHeader(title: "Last 30 Days")
            ForEach(Array(dailyHistory.enumerated()), id: \.element.id) { idx, day in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel(day.date)).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text)
                        Text("Bat \(day.batting) · Bowl \(day.bowling) · Field \(day.fielding)")
                            .font(.system(size: 11)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 3) {
                        Text("\(day.total)").font(.system(size: 20, weight: .black)).foregroundColor(Theme.gold)
                        Text("kcal").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.text3).padding(.bottom, 3)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                if idx < dailyHistory.count - 1 {
                    Divider().background(Theme.border).padding(.leading, 16)
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var disclaimer: some View {
        Text("Estimated from your batting, bowling and fielding activity. For fun, not medical accuracy.")
            .font(.system(size: 11)).foregroundColor(Theme.text3)
            .multilineTextAlignment(.center).lineSpacing(2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("🔥").font(.system(size: 54))
            Text("No calories yet").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
            Text("Play a match as \(profile?.displayName ?? "yourself") to see how\nmany calories you burned batting and bowling.")
                .font(.system(size: 13)).foregroundColor(Theme.text2)
                .multilineTextAlignment(.center).lineSpacing(3)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}

// A single wedge of the calories pie chart.
private struct CalorieSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

// Calories burned on one calendar day, aggregated across that day's matches.
private struct DayTotal: Identifiable {
    var id: Date { date }
    let date: Date
    let batting: Int
    let bowling: Int
    let fielding: Int
    let total: Int
}
