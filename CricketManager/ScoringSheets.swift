import SwiftUI

// MARK: - Wicket Sheet
struct WicketSheet: View {
    @ObservedObject var vm: ScoringViewModel
    @State private var selectedDismissal: DismissalType = .caught
    @State private var runs: Int = 0
    @State private var selectedBatter: Player? = nil
    let dismissals = DismissalType.allCases
    let dismissalCols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 6) {
                            Text("🚨").font(.system(size: 36))
                            Text("WICKET!").font(.system(size: 22, weight: .black)).tracking(3).foregroundColor(Theme.text)
                            if let s = vm.innings.striker {
                                Text("\(s.player.name) is out").font(.system(size: 13)).foregroundColor(Theme.text2)
                            }
                        }.padding(.top, 4)

                        // Runs scored on the ball
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Runs scored on this ball")
                            HStack(spacing: 8) {
                                ForEach([0,1,2,3], id: \.self) { r in
                                    Button { withAnimation { runs = r } } label: {
                                        Text("\(r)").font(.system(size: 18, weight: .bold))
                                            .foregroundColor(runs == r ? Theme.red : Theme.text2)
                                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                                            .background(runs == r ? Theme.red.opacity(0.15) : Theme.surface2)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(runs == r ? Theme.red.opacity(0.5) : Theme.border, lineWidth: runs == r ? 1.5 : 1))
                                    }
                                }
                            }
                        }

                        // Dismissal type
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Dismissal type")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach(dismissals, id: \.self) { d in
                                    Button { withAnimation { selectedDismissal = d } } label: {
                                        Text(d.rawValue).font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(selectedDismissal == d ? Theme.red : Theme.text2)
                                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                                            .background(selectedDismissal == d ? Theme.red.opacity(0.15) : Theme.surface2)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedDismissal == d ? Theme.red.opacity(0.5) : Theme.border, lineWidth: selectedDismissal == d ? 1.5 : 1))
                                    }
                                }
                            }
                        }

                        // Next batter
                        if !vm.availableBatters.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "Next batter in")
                                VStack(spacing: 6) {
                                    ForEach(vm.availableBatters.prefix(5)) { p in
                                        Button { withAnimation { selectedBatter = p } } label: {
                                            HStack(spacing: 10) {
                                                PlayerAvatar(name: p.name, role: p.role, size: 32)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                                                    Text(p.role.label).font(.system(size: 10)).foregroundColor(Theme.text3)
                                                }
                                                Spacer()
                                                RolePill(role: p.role)
                                                if selectedBatter?.id == p.id {
                                                    Circle().fill(Theme.gold).frame(width: 18, height: 18)
                                                        .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.black))
                                                } else {
                                                    Circle().stroke(Theme.border2, lineWidth: 1.5).frame(width: 18, height: 18)
                                                }
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(selectedBatter?.id == p.id ? Theme.gold.opacity(0.08) : Theme.surface2)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedBatter?.id == p.id ? Theme.gold.opacity(0.3) : Theme.border, lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }

                        // Confirm — allowed only once the next batter is picked.
                        // (When no batters remain, this is the final wicket and none
                        // is needed, so confirming is allowed.)
                        let needsNextBatter = !vm.availableBatters.isEmpty
                        let canConfirm = selectedBatter != nil || !needsNextBatter

                        VStack(spacing: 8) {
                            if needsNextBatter && selectedBatter == nil {
                                Text("Select the next batter to continue")
                                    .font(.system(size: 12)).foregroundColor(Theme.text3)
                            }
                            Button {
                                vm.addBall(.wicket(selectedDismissal, runs))
                                vm.showWicketSheet = false
                                if let b = selectedBatter { vm.sendInBatter(b, asStriker: true) }
                            } label: {
                                Text("Confirm Wicket").font(.system(size: 15, weight: .bold)).tracking(1.5)
                                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(Theme.red.opacity(canConfirm ? 0.8 : 0.3)).cornerRadius(14)
                            }
                            .disabled(!canConfirm)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Extras Sheet
struct ExtrasSheet: View {
    @ObservedObject var vm: ScoringViewModel
    let runCols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var runsRange: [Int] {
        switch vm.extrasType {
        case .wide: return [1,2,3,4]
        case .noBall: return [1,2,3,4,5,7]
        case .bye, .legBye: return [1,2,3,4]
        }
    }

    var runsLabel: (Int) -> String {
        { r in
            switch vm.extrasType {
            case .wide: return r == 1 ? "Wide only" : "Wd + \(r-1) run\(r-1>1 ? "s":"")"
            case .noBall:
                if r == 1 { return "NB only" }
                if r == 5 { return "NB + 4 (boundary)" }
                if r == 7 { return "NB + 6 (six!)" }
                return "NB + \(r-1) run\(r-1>1 ? "s":"")"
            case .bye: return "\(r) bye\(r>1 ? "s":"")"
            case .legBye: return "\(r) leg bye\(r>1 ? "s":"")"
            }
        }
    }

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vm.extrasType.rawValue).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
                            Text(vm.extrasType.note).font(.system(size: 11)).foregroundColor(Theme.text2).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text(vm.extrasType.rawValue.prefix(2).uppercased() + " + runs")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(vm.extrasType.color)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(vm.extrasType.color.opacity(0.15)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(vm.extrasType.color.opacity(0.35), lineWidth: 1))
                    }
                    .padding(.horizontal, 20).padding(.top, 8)

                    // Run grid
                    LazyVGrid(columns: runCols, spacing: 10) {
                        ForEach(runsRange, id: \.self) { r in
                            Button { withAnimation { vm.selectedExtrasRuns = r } } label: {
                                VStack(spacing: 3) {
                                    Text("+\(r)").font(.system(size: 24, weight: .bold))
                                        .foregroundColor(vm.selectedExtrasRuns == r ? vm.extrasType.color : Theme.text2)
                                    Text(runsLabel(r)).font(.system(size: 10)).foregroundColor(vm.selectedExtrasRuns == r ? vm.extrasType.color.opacity(0.7) : Theme.text3)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(vm.selectedExtrasRuns == r ? vm.extrasType.color.opacity(0.15) : Theme.surface2)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(vm.selectedExtrasRuns == r ? vm.extrasType.color.opacity(0.6) : Theme.border, lineWidth: vm.selectedExtrasRuns == r ? 1.5 : 1))
                                .scaleEffect(vm.selectedExtrasRuns == r ? 1.02 : 1.0)
                            }
                        }
                    }.padding(.horizontal, 20)

                    // Confirm
                    Button {
                        let r = vm.selectedExtrasRuns
                        switch vm.extrasType {
                        case .wide: vm.addBall(.wide(r))
                        case .noBall: vm.addBall(.noBall(r))
                        case .bye: vm.addBall(.bye(r))
                        case .legBye: vm.addBall(.legBye(r))
                        }
                        vm.showExtrasSheet = false
                    } label: {
                        Text("Confirm · +\(vm.selectedExtrasRuns) (\(vm.extrasType.rawValue))")
                            .font(.system(size: 14, weight: .bold)).tracking(0.5)
                            .foregroundColor(vm.extrasType.color).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(vm.extrasType.color.opacity(0.15)).cornerRadius(13)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(vm.extrasType.color.opacity(0.45), lineWidth: 1.5))
                    }.padding(.horizontal, 20)

                    // Undo last ball option
                    if vm.canUndo {
                        Button { vm.undoLastBall(); vm.showExtrasSheet = false } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 13))
                                Text("Undo last ball instead").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Theme.red).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.red.opacity(0.08)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red.opacity(0.25), lineWidth: 1))
                        }.padding(.horizontal, 20)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Change Batter Sheet
struct ChangeBatterSheet: View {
    @ObservedObject var vm: ScoringViewModel
    @State private var newName: String = ""
    @State private var newRole: PlayerRole = .bat
    @State private var selectedPlayer: Player? = nil
    @FocusState private var nameFocused: Bool

    var replacing: String {
        let idx = vm.replacingStrikerIndex
        let s = idx ? vm.innings.striker : vm.innings.nonStriker
        return s?.player.name ?? "Batter"
    }

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                ScrollView {
                    VStack(spacing: 18) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Change Batter").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
                                Text("Replacing \(replacing)").font(.system(size: 12)).foregroundColor(Theme.text2)
                            }
                            Spacer()
                            BadgeView(text: vm.replacingStrikerIndex ? "Striker" : "Non-Striker", color: Theme.gold)
                        }.padding(.horizontal, 20).padding(.top, 8)

                        // Add new
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Add new player").padding(.horizontal, 20)
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    ForEach(PlayerRole.allCases) { r in
                                        Button { newRole = r } label: {
                                            VStack(spacing: 2) {
                                                Text(r.icon).font(.system(size: 14))
                                                Text(r.short).font(.system(size: 8, weight: .bold)).tracking(0.5)
                                            }
                                            .foregroundColor(newRole == r ? r.color : Theme.text3)
                                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                                            .background(newRole == r ? r.color.opacity(0.15) : Theme.surface3).cornerRadius(9)
                                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(newRole == r ? r.color : Color.clear, lineWidth: 1.5))
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    TextField("Player name…", text: $newName)
                                        .autocorrectionDisabled()
                                        .focused($nameFocused)
                                        .font(.system(size: 14)).foregroundColor(Theme.text)
                                        .padding(.horizontal, 13).padding(.vertical, 10)
                                        .background(Theme.surface3).cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(nameFocused ? Theme.gold : Theme.gold.opacity(0.3), lineWidth: nameFocused ? 2 : 1.5))
                                    Button {
                                        let n = newName.trimmingCharacters(in: .whitespaces)
                                        guard !n.isEmpty else { return }
                                        vm.addNewBatterAndSend(name: n, role: newRole, asStriker: vm.replacingStrikerIndex)
                                    } label: {
                                        Text("+ Send In").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex:"#0a0e1a"))
                                            .padding(.horizontal, 14).padding(.vertical, 10).background(Theme.goldGrad).cornerRadius(10)
                                    }
                                }
                            }.padding(.horizontal, 20)
                        }

                        Divider().background(Theme.border).padding(.horizontal, 20)

                        // Squad list
                        if !vm.availableBatters.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "Pick from squad").padding(.horizontal, 20)
                                VStack(spacing: 5) {
                                    ForEach(vm.availableBatters) { p in
                                        Button { withAnimation { selectedPlayer = p } } label: {
                                            HStack(spacing: 10) {
                                                PlayerAvatar(name: p.name, role: p.role, size: 32)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                                                    Text(p.role.label).font(.system(size: 10)).foregroundColor(Theme.text3)
                                                }
                                                Spacer()
                                                RolePill(role: p.role)
                                                selectionIndicator(selected: selectedPlayer?.id == p.id, color: Theme.gold)
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(selectedPlayer?.id == p.id ? Theme.gold.opacity(0.08) : Theme.surface2)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPlayer?.id == p.id ? Theme.gold.opacity(0.4) : Theme.border, lineWidth: selectedPlayer?.id == p.id ? 1.5 : 1))
                                        }
                                    }
                                }.padding(.horizontal, 20)
                            }

                            if let p = selectedPlayer {
                                Button { vm.sendInBatter(p, asStriker: vm.replacingStrikerIndex) } label: {
                                    Text("Send in \(p.name)").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.gold)
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .background(Theme.gold.opacity(0.12)).cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.4), lineWidth: 1.5))
                                }.padding(.horizontal, 20)
                            }
                        }
                        Spacer(minLength: 24)
                    }
                }
            }
        }
    }
}

// MARK: - Change Bowler Sheet
struct ChangeBowlerSheet: View {
    @ObservedObject var vm: ScoringViewModel
    @State private var newName: String = ""
    @State private var selectedPlayer: Player? = nil
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                ScrollView {
                    VStack(spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Change Bowler").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
                                Text("Over \(vm.innings.overNumber + 1) · who bowls next?").font(.system(size: 12)).foregroundColor(Theme.text2)
                            }
                            Spacer()
                            BadgeView(text: "Over \(vm.innings.overNumber + 1)", color: Theme.bowl)
                        }.padding(.horizontal, 20).padding(.top, 8)

                        // Add new
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Add new player").padding(.horizontal, 20)
                            HStack(spacing: 8) {
                                TextField("Player name…", text: $newName)
                                    .autocorrectionDisabled()
                                    .focused($nameFocused)
                                    .font(.system(size: 14)).foregroundColor(Theme.text)
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                    .background(Theme.surface3).cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(nameFocused ? Theme.bowl : Theme.bowl.opacity(0.3), lineWidth: nameFocused ? 2 : 1.5))
                                Button {
                                    let n = newName.trimmingCharacters(in: .whitespaces)
                                    guard !n.isEmpty else { return }
                                    vm.addNewBowlerAndSet(name: n)
                                } label: {
                                    Text("+ Set").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(Theme.bowl.opacity(0.8)).cornerRadius(10)
                                }
                            }.padding(.horizontal, 20)
                        }

                        Divider().background(Theme.border).padding(.horizontal, 20)

                        // Bowling squad
                        if !vm.availableBowlers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "Bowling squad").padding(.horizontal, 20)
                                VStack(spacing: 5) {
                                    ForEach(vm.availableBowlers) { p in
                                        let stats = vm.innings.bowlerStats.first(where: { $0.player.id == p.id })
                                        let isCurrent = vm.innings.currentBowler?.player.id == p.id && vm.innings.balls == 0 && vm.innings.allOvers.count > 0
                                        Button {
                                            if !isCurrent { withAnimation { selectedPlayer = p } }
                                        } label: {
                                            HStack(spacing: 10) {
                                                PlayerAvatar(name: p.name, role: .bowl, size: 30)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundColor(isCurrent ? Theme.text3 : Theme.text)
                                                    Text(stats != nil ? stats!.overString : "yet to bowl").font(.system(size: 10)).foregroundColor(Theme.text3)
                                                }
                                                Spacer()
                                                if isCurrent {
                                                    Text("Just bowled").font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.text3)
                                                        .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.surface3).cornerRadius(5)
                                                } else {
                                                    selectionIndicator(selected: selectedPlayer?.id == p.id, color: Theme.bowl)
                                                }
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(selectedPlayer?.id == p.id ? Theme.bowl.opacity(0.1) : Theme.surface2)
                                            .opacity(isCurrent ? 0.45 : 1)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPlayer?.id == p.id ? Theme.bowl.opacity(0.4) : Theme.border, lineWidth: selectedPlayer?.id == p.id ? 1.5 : 1))
                                        }
                                        .disabled(isCurrent)
                                    }
                                }.padding(.horizontal, 20)
                            }

                            if let p = selectedPlayer {
                                Button { vm.setBowler(p) } label: {
                                    Text("\(p.name) to bowl over \(vm.innings.overNumber + 1)")
                                        .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.bowl)
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .background(Theme.bowl.opacity(0.12)).cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.bowl.opacity(0.4), lineWidth: 1.5))
                                }.padding(.horizontal, 20)
                            }
                        }
                        Spacer(minLength: 24)
                    }
                }
            }
        }
    }
}

// MARK: - End of Over Sheet
struct EndOfOverSheet: View {
    @ObservedObject var vm: ScoringViewModel
    var lastOver: [BallEvent] { vm.innings.allOvers.last ?? [] }
    var overRuns: Int { lastOver.reduce(0) { $0 + $1.runsScored } }

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Over \(vm.innings.allOvers.count) Complete").font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                        HStack {
                            Text("\(vm.innings.runs)/\(vm.innings.wickets)").font(.system(size: 28, weight: .bold)).foregroundColor(Theme.text)
                            Text("· \(vm.innings.allOvers.count) ov").font(.system(size: 15)).foregroundColor(Theme.text3)
                        }
                    }.padding(.top, 8)

                    // Over balls
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Over \(vm.innings.allOvers.count) summary")
                        HStack(spacing: 6) {
                            ForEach(0..<lastOver.count, id: \.self) { i in
                                let e = lastOver[i]
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(e.bgColor)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(e.color.opacity(0.5), lineWidth: 1))
                                    Text(e.displayText).font(.system(size: 13, weight: .bold)).foregroundColor(e.color)
                                }.frame(width: 36, height: 36)
                            }
                        }
                        HStack {
                            Text("Runs this over:").font(.system(size: 13)).foregroundColor(Theme.text2)
                            Spacer()
                            Text("\(overRuns)").font(.system(size: 20, weight: .bold)).foregroundColor(Theme.gold)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.surface2).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }

                    // Select next bowler (embedded)
                    ChangeBowlerInline(vm: vm)
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
    }
}

struct ChangeBowlerInline: View {
    @ObservedObject var vm: ScoringViewModel
    @State private var selectedPlayer: Player? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Select bowler for over \(vm.innings.allOvers.count + 1)")
            VStack(spacing: 5) {
                ForEach(vm.availableBowlers) { p in
                    let isCurrent = vm.innings.currentBowler?.player.id == p.id && vm.innings.allOvers.count > 0
                    Button {
                        if !isCurrent { withAnimation { selectedPlayer = p } }
                    } label: {
                        HStack(spacing: 10) {
                            PlayerAvatar(name: p.name, role: .bowl, size: 28)
                            Text(p.name).font(.system(size: 12, weight: .semibold)).foregroundColor(isCurrent ? Theme.text3 : Theme.text)
                            Spacer()
                            if isCurrent {
                                Text("Just bowled").font(.system(size: 9)).foregroundColor(Theme.text3)
                            } else {
                                let stats = vm.innings.bowlerStats.first(where: { $0.player.id == p.id })
                                Text(stats?.overString ?? "0-0-0-0").font(.system(size: 10)).foregroundColor(Theme.text2)
                            }
                            selectionIndicator(selected: selectedPlayer?.id == p.id, color: Theme.bowl)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selectedPlayer?.id == p.id ? Theme.bowl.opacity(0.1) : Theme.surface2)
                        .opacity(isCurrent ? 0.4 : 1).cornerRadius(9)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selectedPlayer?.id == p.id ? Theme.bowl.opacity(0.4) : Theme.border, lineWidth: 1))
                    }.disabled(isCurrent)
                }
            }
            if let p = selectedPlayer {
                Button { vm.setBowler(p) } label: {
                    Text("Start Over \(vm.innings.allOvers.count + 1) with \(p.name)")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.greenGrad).cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Scorecard Sheet
struct ScorecardSheet: View {
    @ObservedObject var vm: ScoringViewModel
    @State private var selectedTab: Int = 0
    @State private var expanded: Set<Int> = [0]   // which innings sections are open
    let tabs = ["Batting","Bowling","Fall of Wkts"]

    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHandle()
                // Mini score
                HStack {
                    VStack(alignment: .leading) {
                        Text(vm.innings.battingTeam.name).font(.system(size: 12, weight: .bold)).foregroundColor(vm.match.currentInnings == 1 ? Theme.green : Theme.cyan)
                        HStack(alignment: .bottom, spacing: 3) {
                            Text("\(vm.innings.runs)").font(.system(size: 28, weight: .bold)).foregroundColor(Theme.text)
                            Text("/\(vm.innings.wickets)").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.red).padding(.bottom, 3)
                        }
                        Text("(\(vm.innings.oversDisplay) ov)").font(.system(size: 11)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    if vm.match.currentInnings == 2, let t = vm.match.target {
                        VStack(alignment: .trailing) {
                            Text("Target").font(.system(size: 11)).foregroundColor(Theme.text2)
                            Text("\(t)").font(.system(size: 24, weight: .bold)).foregroundColor(Theme.gold)
                        }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)

                // Tabs
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        Button { withAnimation { selectedTab = i } } label: {
                            Text(tabs[i]).font(.system(size: 11, weight: .semibold)).tracking(0.5)
                                .foregroundColor(selectedTab == i ? Theme.gold : Theme.text3)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .overlay(Rectangle().fill(selectedTab == i ? Theme.gold : Color.clear).frame(height: 2), alignment: .bottom)
                        }
                    }
                }
                .background(Theme.surface2)
                .overlay(Divider().background(Theme.border), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(inningsList.indices, id: \.self) { idx in
                            let inn = inningsList[idx]
                            VStack(spacing: 0) {
                                InningsHeader(innings: inn, index: idx,
                                              isBowling: selectedTab == 1,
                                              isExpanded: expanded.contains(idx)) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expanded.contains(idx) { expanded.remove(idx) }
                                        else { expanded.insert(idx) }
                                    }
                                }
                                if expanded.contains(idx) {
                                    switch selectedTab {
                                    case 0: BattingCard(innings: inn)
                                    case 1: BowlingCard(innings: inn)
                                    default: FallOfWicketsCard(innings: inn)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // Both innings (2nd only once it exists) so the scorecard shows both teams.
    private var inningsList: [Innings] {
        var list = [vm.match.innings1]
        if let i2 = vm.match.innings2 { list.append(i2) }
        return list
    }
}

// Team/innings header shown above each card so both teams are clearly separated.
struct InningsHeader: View {
    @ObservedObject var innings: Innings
    let index: Int
    // On the Bowling tab the rows are the fielding side, so name that team instead.
    var isBowling: Bool = false
    var isExpanded: Bool = true
    var onTap: () -> Void = {}
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.text3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text(isBowling ? innings.bowlingTeam.name : innings.battingTeam.name)
                    .font(.system(size: 13, weight: .bold)).tracking(0.5)
                    .foregroundColor(index == 0 ? Theme.green : Theme.cyan)
                Text("Innings \(index + 1)").font(.system(size: 9, weight: .bold)).tracking(1)
                    .foregroundColor(Theme.text3)
                Spacer()
                Text("\(innings.runs)/\(innings.wickets) (\(innings.oversDisplay) ov)")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.gold)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.surface2)
            .overlay(Divider().background(Theme.border), alignment: .bottom)
        }
        .buttonStyle(FeedbackButtonStyle())
    }
}

struct BattingCard: View {
    @ObservedObject var innings: Innings
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batter").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(maxWidth: .infinity, alignment: .leading)
                Text("R").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 28, alignment: .center)
                Text("B").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 28, alignment: .center)
                Text("4s").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 24, alignment: .center)
                Text("6s").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 24, alignment: .center)
                Text("SR").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.surface2)

            ForEach(innings.batterStats) { b in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text(b.player.name).font(.system(size: 12, weight: b.isOnStrike ? .bold : .semibold)).foregroundColor(b.isOut ? Theme.text3 : Theme.text)
                            if b.isOnStrike { Text("*").font(.system(size: 10)).foregroundColor(Theme.gold) }
                        }
                        Text(b.isOut ? b.dismissal : "not out").font(.system(size: 9)).foregroundColor(Theme.text3)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(b.runs)").font(.system(size: 14, weight: .bold)).foregroundColor(b.isOnStrike ? Theme.gold : Theme.text).frame(width: 28, alignment: .center)
                    Text("\(b.balls)").font(.system(size: 12)).foregroundColor(Theme.text2).frame(width: 28, alignment: .center)
                    Text("\(b.fours)").font(.system(size: 12)).foregroundColor(Theme.green).frame(width: 24, alignment: .center)
                    Text("\(b.sixes)").font(.system(size: 12)).foregroundColor(Theme.gold).frame(width: 24, alignment: .center)
                    Text(String(format: "%.0f", b.strikeRate)).font(.system(size: 11)).foregroundColor(Theme.text2).frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(b.isOnStrike ? Theme.gold.opacity(0.04) : Theme.surface1)
                Divider().background(Theme.border).padding(.horizontal, 8)
            }

            // Extras + Total
            HStack {
                Text("Extras").font(.system(size: 12)).foregroundColor(Theme.text2)
                Spacer()
                Text("\(innings.extras) (wd \(innings.wides), nb \(innings.noBalls), b \(innings.byes), lb \(innings.legByes))")
                    .font(.system(size: 11)).foregroundColor(Theme.text2)
            }.padding(.horizontal, 16).padding(.vertical, 8)

            HStack {
                Text("Total").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                Text("\(innings.runs)/\(innings.wickets) (\(innings.oversDisplay) ov)")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.gold)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.gold.opacity(0.05))
        }
    }
}

struct BowlingCard: View {
    @ObservedObject var innings: Innings
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bowler").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(maxWidth: .infinity, alignment: .leading)
                Text("O").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 28, alignment: .center)
                Text("R").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 28, alignment: .center)
                Text("W").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 28, alignment: .center)
                Text("Econ").font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Theme.text3).frame(width: 40, alignment: .trailing)
            }.padding(.horizontal, 16).padding(.vertical, 8).background(Theme.surface2)

            if innings.bowlerStats.isEmpty {
                Text("No bowlers yet").font(.system(size: 13)).foregroundColor(Theme.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            }

            ForEach(innings.bowlerStats) { b in
                HStack {
                    Text(b.player.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(b.overs).\(b.balls)").font(.system(size: 12)).foregroundColor(Theme.text2).frame(width: 28, alignment: .center)
                    Text("\(b.runs)").font(.system(size: 12)).foregroundColor(Theme.text2).frame(width: 28, alignment: .center)
                    Text("\(b.wickets)").font(.system(size: 14, weight: .bold)).foregroundColor(b.wickets > 0 ? Theme.red : Theme.text2).frame(width: 28, alignment: .center)
                    Text(String(format: "%.1f", b.economy)).font(.system(size: 11)).foregroundColor(Theme.text2).frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 16).padding(.vertical, 9).background(Theme.surface1)
                Divider().background(Theme.border).padding(.horizontal, 8)
            }
        }
    }
}

struct FallOfWicketsCard: View {
    @ObservedObject var innings: Innings
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if innings.fallOfWickets.isEmpty {
                Text("No wickets fallen yet").font(.system(size: 13)).foregroundColor(Theme.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            ForEach(0..<innings.fallOfWickets.count, id: \.self) { i in
                let (r, w, name) = innings.fallOfWickets[i]
                HStack {
                    Text("\(w)/\(r)").font(.system(size: 15, weight: .bold)).foregroundColor(Theme.red).frame(width: 56)
                    Text(name).font(.system(size: 13)).foregroundColor(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                if i < innings.fallOfWickets.count - 1 { Divider().background(Theme.border).padding(.horizontal, 8) }
            }
        }.padding(.top, 8)
    }
}

// MARK: - Start Innings 2 Sheet
struct StartInnings2Sheet: View {
    @ObservedObject var vm: ScoringViewModel
    var body: some View {
        ZStack { Theme.surface1.ignoresSafeArea()
            VStack(spacing: 24) {
                SheetHandle()
                Text("🏏").font(.system(size: 44))
                Text("1st Innings Complete!").font(.system(size: 22, weight: .bold)).tracking(1).foregroundColor(Theme.text)
                VStack(spacing: 12) {
                    HStack {
                        Text(vm.match.innings1.battingTeam.name).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.green)
                        Spacer()
                        Text("\(vm.match.innings1.runs)/\(vm.match.innings1.wickets)").font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.surface2).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                    HStack {
                        Text("Target for \(vm.match.innings1.bowlingTeam.name)").font(.system(size: 13)).foregroundColor(Theme.text2)
                        Spacer()
                        Text("\(vm.match.innings1.runs + 1)").font(.system(size: 24, weight: .bold)).foregroundColor(Theme.gold)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.gold.opacity(0.06)).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                }.padding(.horizontal, 20)

                GreenButton(title: "Start 2nd Innings →") { vm.beginInnings2() }.padding(.horizontal, 20)
                Spacer()
            }
        }
    }
}


// MARK: - Helpers
struct SheetHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 999).fill(Theme.border2)
            .frame(width: 36, height: 3).padding(.vertical, 12)
    }
}

func selectionIndicator(selected: Bool, color: Color) -> some View {
    Group {
        if selected {
            Circle().fill(color).frame(width: 18, height: 18)
                .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.black))
        } else {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5).frame(width: 18, height: 18)
        }
    }
}
