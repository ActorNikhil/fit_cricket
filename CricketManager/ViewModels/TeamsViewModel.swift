import SwiftUI

class TeamsViewModel: ObservableObject {
    @Published var isAddingPlayerA: Bool = false
    @Published var isAddingPlayerB: Bool = false
    @Published var newNameA: String = ""
    @Published var newRoleA: PlayerRole = .bat
    @Published var newNameB: String = ""
    @Published var newRoleB: PlayerRole = .bat

    func addPlayer(to side: TeamSide, appVM: AppViewModel) {
        let name = side == .a ? newNameA.trimmingCharacters(in: .whitespaces) : newNameB.trimmingCharacters(in: .whitespaces)
        let role = side == .a ? newRoleA : newRoleB
        guard !name.isEmpty else { return }
        appVM.addPlayer(to: side, name: name, role: role)
        if side == .a { newNameA = "" } else { newNameB = "" }
    }
}

class MatchSetupViewModel: ObservableObject {
    // Drives Match Setup page logic
}
