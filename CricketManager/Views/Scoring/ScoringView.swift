import SwiftUI

// MARK: - Scoring Root
struct ScoringRootView: View {
    @StateObject var vm: ScoringViewModel
    @EnvironmentObject var appVM: AppViewModel

    init(match: Match) {
        _vm = StateObject(wrappedValue: ScoringViewModel(match: match))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Theme.bgGrad.ignoresSafeArea().opacity(0.6)
            GridTexture().ignoresSafeArea().opacity(0.3)

            if vm.match.isMatchOver {
                MatchResultView(vm: vm).environmentObject(appVM)
            } else {
                ScoringView(vm: vm)
            }
        }
        .sheet(isPresented: $vm.showChangeBatterSheet) { ChangeBatterSheet(vm: vm) .presentationDetents([.fraction(0.7)]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showChangeBowlerSheet) { ChangeBowlerSheet(vm: vm).presentationDetents([.fraction(0.65)]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showWicketSheet) { WicketSheet(vm: vm).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showExtrasSheet) { ExtrasSheet(vm: vm).presentationDetents([.fraction(0.6)]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showEndOfOverSheet) { EndOfOverSheet(vm: vm).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showScorecardSheet) { ScorecardSheet(vm: vm).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $vm.showStartInnings2) { StartInnings2Sheet(vm: vm).presentationDetents([.fraction(0.55)]).presentationDragIndicator(.visible) }
    }
}

// MARK: - Main Scoring Screen
struct ScoringView: View {
    @ObservedObject var vm: ScoringViewModel
    var inn: Innings { vm.innings }

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            scoringNavBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Score header
                    ScoreboardHeader(vm: vm)

                    // Chase metrics (2nd innings only)
                    if vm.match.currentInnings == 2 { ChaseMetricsBar(vm: vm) }

                    // Batters
                    BatterSection(vm: vm)

                    // Bowler
                    BowlerSection(vm: vm)

                    // This over
                    ThisOverSection(vm: vm)
                }
            }

            // Run buttons (always visible at bottom)
            RunInputPanel(vm: vm)
        }
    }

    var scoringNavBar: some View {
        HStack {
            Button { vm.showScorecardSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet").font(.system(size: 13))
                    Text("Scorecard").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Theme.text2)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.surface2).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
            Spacer()
            VStack(spacing: 1) {
                Text("\(vm.match.currentInnings == 1 ? "1st" : "2nd") Innings").font(.system(size: 9, weight: .bold)).tracking(1).textCase(.uppercase).foregroundColor(Theme.text3)
                Text(inn.battingTeam.name).font(.system(size: 12, weight: .bold)).foregroundColor(vm.match.currentInnings == 1 ? Theme.green : Theme.cyan)
            }
            Spacer()
            // Innings indicator
            HStack(spacing: 4) {
                Circle().fill(vm.match.currentInnings == 1 ? Theme.green : Theme.surface3).frame(width: 6, height: 6)
                Circle().fill(vm.match.currentInnings == 2 ? Theme.cyan : Theme.surface3).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surface1.opacity(0.9))
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }
}

// MARK: - Scoreboard Header
struct ScoreboardHeader: View {
    @ObservedObject var vm: ScoringViewModel
    var inn: Innings { vm.innings }
    var body: some View {
        VStack(spacing: 0) {
            // Main score
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(inn.runs)").font(.system(size: 58, weight: .bold)).foregroundColor(Theme.text).lineLimit(1)
                Text("/\(inn.wickets)").font(.system(size: 26, weight: .bold)).foregroundColor(Theme.red).padding(.bottom, 8)
            }
            // Stats row
            HStack(spacing: 0) {
                ScoreStatChip(value: inn.oversDisplay, label: "Overs")
                Rectangle().fill(Theme.border).frame(width: 1, height: 32)
                ScoreStatChip(value: String(format: "%.2f", inn.runRate), label: "Run Rate", color: Theme.cyan)
                Rectangle().fill(Theme.border).frame(width: 1, height: 32)
                ScoreStatChip(value: inn.remainingOvers, label: "Remaining", color: Theme.purple)
                Rectangle().fill(Theme.border).frame(width: 1, height: 32)
                ScoreStatChip(value: "\(inn.extras)", label: "Extras", color: Theme.text2)
            }
            .background(Theme.surface2).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 8)
        }
        .padding(.top, 14)
        .background(Theme.surface1)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }
}

struct ScoreStatChip: View {
    let value: String; let label: String; var color: Color = Theme.gold
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 8, weight: .semibold)).tracking(0.8).textCase(.uppercase).foregroundColor(Theme.text3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}

// MARK: - Chase Metrics
struct ChaseMetricsBar: View {
    @ObservedObject var vm: ScoringViewModel
    var body: some View {
        VStack(spacing: 8) {
            // Target row
            if let t = vm.match.target, let rn = vm.match.runsNeeded, let br = vm.match.ballsRemaining2nd {
                HStack {
                    Text("Target: \(t)").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.text2)
                    Spacer()
                    Text("Need \(rn) off \(br) balls").font(.system(size: 11, weight: .bold)).foregroundColor(vm.rrrColor)
                }
                .padding(.horizontal, 14).padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.surface3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(vm.rrrColor)
                            .frame(width: geo.size.width * CGFloat(vm.match.chaseProgress ?? 0), height: 5)
                    }
                }
                .frame(height: 5).padding(.horizontal, 14)

                // RRR metrics
                HStack(spacing: 0) {
                    ChaseChip(value: "\(rn)", label: "Needed", color: Theme.red)
                    Rectangle().fill(Theme.border).frame(width: 1, height: 28)
                    ChaseChip(value: "\(br)", label: "Balls", color: Theme.amber)
                    Rectangle().fill(Theme.border).frame(width: 1, height: 28)
                    ChaseChip(value: String(format: "%.2f", vm.innings.runRate), label: "Curr RR", color: Theme.cyan)
                    Rectangle().fill(Theme.border).frame(width: 1, height: 28)
                    ChaseChip(value: String(format: "%.2f", vm.match.requiredRunRate ?? 0), label: "Req RR", color: vm.rrrColor)
                }
                .background(Theme.surface2).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 14).padding(.bottom, 8)
            }
        }
        .background(Theme.surface1.opacity(0.8))
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }
}

struct ChaseChip: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 7, weight: .semibold)).tracking(0.8).textCase(.uppercase).foregroundColor(Theme.text3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
    }
}

// MARK: - Batter Section
struct BatterSection: View {
    @ObservedObject var vm: ScoringViewModel
    var inn: Innings { vm.innings }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "Batters at crease")
                Spacer()
                Button {
                    vm.replacingStrikerIndex = true
                    vm.showChangeBatterSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Add batter").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Theme.gold).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.gold.opacity(0.1)).cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.gold.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

            if let striker = inn.striker {
                BatterRow(stats: striker, isStriker: true, vm: vm)
            } else {
                noPlayerPrompt(text: "Tap Add batter to set striker", color: Theme.gold)
            }
            if let ns = inn.nonStriker {
                BatterRow(stats: ns, isStriker: false, vm: vm)
            } else {
                noPlayerPrompt(text: "Tap Add batter to set non-striker", color: Theme.text3)
            }
        }
        .padding(.bottom, 6)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }

    func noPlayerPrompt(text: String, color: Color) -> some View {
        Text(text).font(.system(size: 11)).foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

struct BatterRow: View {
    let stats: BatterStats; let isStriker: Bool; @ObservedObject var vm: ScoringViewModel
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(isStriker ? Theme.gold : Theme.text3).frame(width: 6, height: 6)
            PlayerAvatar(name: stats.player.name, role: stats.player.role, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(stats.player.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text)
                    if isStriker { Text("*").font(.system(size: 11)).foregroundColor(Theme.gold) }
                }
                Text(isStriker ? "on strike" : "non-striker").font(.system(size: 9)).foregroundColor(Theme.text3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(stats.runs)").font(.system(size: 18, weight: .bold)).foregroundColor(isStriker ? Theme.gold : Theme.text)
                Text("\(stats.balls)b · SR \(String(format: "%.0f", stats.strikeRate))").font(.system(size: 9)).foregroundColor(Theme.text3)
            }
            // Change button
            Button {
                vm.replacingStrikerIndex = isStriker
                vm.showChangeBatterSheet = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 9))
                    Text("Change").font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(Theme.text3).padding(.horizontal, 8).padding(.vertical, 5)
                .background(Theme.surface2).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
    }
}

// MARK: - Bowler Section
struct BowlerSection: View {
    @ObservedObject var vm: ScoringViewModel
    var inn: Innings { vm.innings }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "Bowling")
                Spacer()
                Button { vm.showChangeBowlerSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10))
                        Text("Change bowler").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Theme.bowl).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.bowl.opacity(0.1)).cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.bowl.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

            if let bowler = inn.currentBowler {
                HStack(spacing: 9) {
                    Circle().fill(Theme.bowl).frame(width: 8, height: 8)
                    PlayerAvatar(name: bowler.player.name, role: .bowl, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(bowler.player.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text)
                        Text("bowling").font(.system(size: 9)).foregroundColor(Theme.text3)
                    }
                    Spacer()
                    Text(bowler.overString).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.bowl)
                    Button { vm.showChangeBowlerSheet = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 9))
                            Text("Change").font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(Theme.text3).padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Theme.surface2).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
            } else {
                Button { vm.showChangeBowlerSheet = true } label: {
                    Text("Tap to select bowler").font(.system(size: 11)).foregroundColor(Theme.bowl)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
        .padding(.bottom, 6)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }
}

// MARK: - This Over
struct ThisOverSection: View {
    @ObservedObject var vm: ScoringViewModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Over \(vm.innings.overNumber + 1)").font(.system(size: 9, weight: .bold)).tracking(1.5).textCase(.uppercase).foregroundColor(Theme.text3)
                    Spacer()
                }
                HStack(spacing: 5) {
                    ForEach(0..<6, id: \.self) { i in
                        if i < vm.innings.currentOver.count {
                            let e = vm.innings.currentOver[i]
                            ZStack {
                                RoundedRectangle(cornerRadius: 7).fill(e.bgColor)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(e.color.opacity(0.5), lineWidth: 1))
                                Text(e.displayText).font(.system(size: 11, weight: .bold)).foregroundColor(e.color)
                            }
                            .frame(width: 30, height: 30)
                        } else {
                            RoundedRectangle(cornerRadius: 7).stroke(Theme.text3.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3]))
                                .frame(width: 30, height: 30)
                        }
                    }
                }
            }
            Spacer()
            // Undo
            Button {
                withAnimation { vm.undoLastBall() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .bold))
                    Text("Undo").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(vm.canUndo ? Theme.red : Theme.text3)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background((vm.canUndo ? Theme.red : Theme.text3).opacity(0.1)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke((vm.canUndo ? Theme.red : Theme.text3).opacity(0.3), lineWidth: 1))
            }
            .disabled(!vm.canUndo)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Run Input Panel
struct RunInputPanel: View {
    @ObservedObject var vm: ScoringViewModel
    let runCols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    let bottomCols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    let extrasCols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        VStack(spacing: 8) {
            Divider().background(Theme.border)
            // Runs 0-3
            LazyVGrid(columns: runCols, spacing: 6) {
                ForEach([0,1,2,3], id: \.self) { r in
                    RunButton(label: "\(r)", color: r == 0 ? Theme.text3 : Theme.text, bg: Theme.surface2, border: Theme.border) {
                        vm.addBall(.runs(r))
                    }
                }
            }
            // 4, 6, OUT
            LazyVGrid(columns: bottomCols, spacing: 6) {
                RunButton(label: "4", color: Theme.green, bg: Theme.green.opacity(0.15), border: Theme.green.opacity(0.5)) { vm.addBall(.runs(4)) }
                RunButton(label: "6", color: Theme.gold, bg: Theme.gold.opacity(0.15), border: Theme.gold.opacity(0.5)) { vm.addBall(.runs(6)) }
                RunButton(label: "OUT", color: Theme.red, bg: Theme.red.opacity(0.15), border: Theme.red.opacity(0.4), fontSize: 14) {
                    vm.showWicketSheet = true
                }
            }
            // Extras
            LazyVGrid(columns: extrasCols, spacing: 5) {
                ForEach(ExtrasType.allCases, id: \.self) { et in
                    Button {
                        vm.extrasType = et
                        vm.selectedExtrasRuns = et.baseRuns
                        vm.showExtrasSheet = true
                    } label: {
                        Text(et.rawValue).font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.text2).frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Theme.surface2).cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 16).padding(.top, 4)
        .background(Theme.surface1)
    }
}

struct RunButton: View {
    let label: String; let color: Color; let bg: Color; let border: Color
    var fontSize: CGFloat = 20
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: fontSize, weight: .bold)).foregroundColor(color)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(bg).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1.5))
        }
    }
}
