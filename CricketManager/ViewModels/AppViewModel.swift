import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var showTossSheet: Bool = false
    @Published var showMatchStarted: Bool = false
    @Published var activeMatch: Match? = nil

    // Teams
    @Published var teamA = CricketTeam(name: "Team Alpha")
    @Published var teamB = CricketTeam(name: "Team Bravo")

    // Match config
    @Published var selectedOvers: Int? = nil
    @Published var tossWinner: TeamSide? = nil

    var isMatchReady: Bool { teamA.players.count > 0 && teamB.players.count > 0 && selectedOvers != nil }
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
