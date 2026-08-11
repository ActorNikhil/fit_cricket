import SwiftUI
import Combine
import SwiftData

class AppViewModel: ObservableObject {
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var showTossSheet: Bool = false
    @Published var showMatchStarted: Bool = false
    @Published var activeMatch: Match? = nil

    // Match slots — in-memory value snapshots loaded from the saved team library.
    // The durable store lives in SwiftData (SavedTeam); these are just the two
    // squads chosen for the current match setup.
    @Published var teamA = CricketTeam(name: "Select Team A")
    @Published var teamB = CricketTeam(name: "Select Team B")

    // Identity of the saved team loaded into each slot, used to prevent
    // picking the same team for both sides.
    @Published var selectedTeamAID: PersistentIdentifier?
    @Published var selectedTeamBID: PersistentIdentifier?

    func selectedTeamID(for side: TeamSide) -> PersistentIdentifier? {
        side == .a ? selectedTeamAID : selectedTeamBID
    }

    /// Load a saved team from the library into one of the two match slots.
    func load(_ saved: SavedTeam, into side: TeamSide) {
        let snap = saved.snapshot()
        if side == .a {
            teamA = snap
            selectedTeamAID = saved.persistentModelID
        } else {
            teamB = snap
            selectedTeamBID = saved.persistentModelID
        }
    }

    // Match config
    @Published var selectedOvers: Int? = nil
    @Published var tossWinner: TeamSide? = nil

    var isMatchReady: Bool { teamA.players.count >= 2 && teamB.players.count >= 2 && selectedOvers != nil }
    var bothTeamsSelected: Bool { !teamA.players.isEmpty && !teamB.players.isEmpty }
    let availableOvers = [5,6,7,8,9,10,12,15,20]

    func addPlayer(to side: TeamSide, name: String, role: PlayerRole) {
        let p = Player(name: name, role: role)
        if side == .a { teamA.players.append(p) } else { teamB.players.append(p) }
    }

    func removePlayer(from side: TeamSide, id: UUID) {
        if side == .a { teamA.players.removeAll { $0.id == id } }
        else { teamB.players.removeAll { $0.id == id } }
    }

    func confirmToss() {
        guard let w = tossWinner, let o = selectedOvers else { return }
        let m = Match(teamA: teamA, teamB: teamB, overs: o, battingFirst: w)
        activeMatch = m
        showTossSheet = false
        showMatchStarted = true
    }

    func resetMatch() {
        activeMatch = nil; tossWinner = nil; showMatchStarted = false; selectedOvers = nil
    }

    func team(for side: TeamSide) -> CricketTeam { side == .a ? teamA : teamB }
}
