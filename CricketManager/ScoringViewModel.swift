import SwiftUI
import Combine

@MainActor
class ScoringViewModel: ObservableObject {
    @Published var match: Match
    @Published var showChangeBatterSheet: Bool = false
    @Published var showChangeBowlerSheet: Bool = false
    @Published var showWicketSheet: Bool = false
    @Published var showExtrasSheet: Bool = false
    @Published var showEndOfOverSheet: Bool = false
    @Published var showScorecardSheet: Bool = false
    @Published var showStartInnings2: Bool = false

    @Published var extrasType: ExtrasType = .wide
    @Published var selectedExtrasRuns: Int = 1
    @Published var selectedDismissal: DismissalType = .caught
    @Published var pendingRunsOnWicket: Int = 0

    @Published var replacingStrikerIndex: Bool = true  // true=striker false=nonStriker
    @Published var selectedNewBatter: Player? = nil
    @Published var newBatterName: String = ""
    @Published var selectedNewBowler: Player? = nil
    @Published var newBowlerName: String = ""

    // Undo stack — snapshots of innings state
    private var undoStack: [InningsSnapshot] = []

    // Set once this match's totals have been written to the career store,
    // so the leaderboard never double-counts a finished match.
    var statsRecorded = false

    // Set once this match has been saved to the History store, so a completed
    // match is never persisted twice (e.g. if the result screen reappears).
    var matchHistoryRecorded = false

    // Forwarding subscriptions for nested ObservableObjects (Match / Innings).
    // Mutating a nested object's @Published property does not fire this VM's
    // objectWillChange, so we re-emit it here to keep the scoring UI in sync.
    private var cancellables: Set<AnyCancellable> = []

    var innings: Innings { match.activeInnings }

    init(match: Match) {
        self.match = match
        observeModel()
        promptForOpeningBowler()
    }

    /// Re-subscribes so changes to the Match and its Innings objects invalidate this VM.
    /// Call again whenever a new Innings is created (e.g. start of the 2nd innings).
    private func observeModel() {
        cancellables.removeAll()
        let forward: () -> Void = { [weak self] in self?.objectWillChange.send() }
        match.objectWillChange.sink { forward() }.store(in: &cancellables)
        match.innings1.objectWillChange.sink { forward() }.store(in: &cancellables)
        if let i2 = match.innings2 {
            i2.objectWillChange.sink { forward() }.store(in: &cancellables)
        }
    }

    // MARK: - Ball Recording
    func addBall(_ event: BallEvent) {
        saveSnapshot()
        applyEvent(event, to: innings)
        checkInningsComplete()
    }

    private func applyEvent(_ event: BallEvent, to inn: Innings) {
        // Update scores
        inn.runs += event.runsScored
        if event.countsAsBall {
            inn.balls += 1
            inn.totalBalls += 1
            updateStriker(runs: event.runsScored, event: event)
        } else {
            inn.extras += event.runsScored
            switch event {
            case .wide: inn.wides += event.runsScored
            case .noBall: inn.noBalls += event.runsScored
            default: break
            }
        }
        switch event {
        case .bye(let r): inn.extras += r; inn.byes += r
        case .legBye(let r): inn.extras += r; inn.legByes += r
        default: break
        }

        // Update bowler
        if inn.currentBowlerIndex < inn.bowlerStats.count {
            inn.bowlerStats[inn.currentBowlerIndex].runs += event.runsScored
            if event.countsAsBall { inn.bowlerStats[inn.currentBowlerIndex].balls += 1 }
            switch event {
            case .wide: inn.bowlerStats[inn.currentBowlerIndex].wides += 1
            case .noBall: inn.bowlerStats[inn.currentBowlerIndex].noBalls += 1
            case .wicket: inn.bowlerStats[inn.currentBowlerIndex].wickets += 1
            default: break
            }
        }

        // Wicket
        if case .wicket(let d, let r) = event {
            inn.wickets += 1
            if inn.currentStrikerIndex < inn.batterStats.count {
                inn.batterStats[inn.currentStrikerIndex].isOut = true
                inn.batterStats[inn.currentStrikerIndex].dismissal = d.rawValue
            }
            inn.fallOfWickets.append((inn.runs, inn.wickets, inn.striker?.player.name ?? ""))
            showWicketSheet = true
        }

        // Rotate strike on odd runs
        if event.countsAsBall && !event.isWicket {
            if event.runsScored % 2 == 1 { rotateStrike() }
        }

        // End of over
        inn.currentOver.append(event)
        if event.countsAsBall && inn.balls >= 6 {
            inn.allOvers.append(inn.currentOver)
            inn.currentOver = []
            inn.balls = 0
            if inn.currentBowlerIndex < inn.bowlerStats.count {
                inn.bowlerStats[inn.currentBowlerIndex].overs += 1
                inn.bowlerStats[inn.currentBowlerIndex].balls = 0
            }
            rotateStrike()  // rotate at end of over
            // Check completion the moment the over ends so the innings-complete
            // sheet shows immediately instead of the end-of-over sheet.
            checkInningsComplete()
            if !inn.isComplete { showEndOfOverSheet = true }
        }
    }

    private func updateStriker(runs: Int, event: BallEvent) {
        guard innings.currentStrikerIndex < innings.batterStats.count else { return }
        innings.batterStats[innings.currentStrikerIndex].runs += runs
        innings.batterStats[innings.currentStrikerIndex].balls += 1
        if case .runs(4) = event { innings.batterStats[innings.currentStrikerIndex].fours += 1 }
        if case .runs(6) = event { innings.batterStats[innings.currentStrikerIndex].sixes += 1 }
    }

    // MARK: - Strike rotation
    func rotateStrike() {
        let old = innings.currentStrikerIndex
        innings.currentStrikerIndex = innings.currentNonStrikerIndex
        innings.currentNonStrikerIndex = old
        if innings.currentStrikerIndex < innings.batterStats.count {
            innings.batterStats[innings.currentStrikerIndex].isOnStrike = true
        }
        if innings.currentNonStrikerIndex < innings.batterStats.count {
            innings.batterStats[innings.currentNonStrikerIndex].isOnStrike = false
        }
    }

    // MARK: - Undo
    func undoLastBall() {
        guard let snap = undoStack.popLast() else { return }
        restoreSnapshot(snap)
    }

    var canUndo: Bool { !undoStack.isEmpty }

    private func saveSnapshot() {
        let snap = InningsSnapshot(
            runs: innings.runs, wickets: innings.wickets, balls: innings.balls,
            totalBalls: innings.totalBalls, extras: innings.extras,
            wides: innings.wides, noBalls: innings.noBalls, byes: innings.byes, legByes: innings.legByes,
            batterStats: innings.batterStats, bowlerStats: innings.bowlerStats,
            currentOver: innings.currentOver, allOvers: innings.allOvers,
            strikerIdx: innings.currentStrikerIndex, nonStrikerIdx: innings.currentNonStrikerIndex,
            bowlerIdx: innings.currentBowlerIndex, fallOfWickets: innings.fallOfWickets
        )
        undoStack.append(snap)
        if undoStack.count > 30 { undoStack.removeFirst() }
    }

    private func restoreSnapshot(_ snap: InningsSnapshot) {
        innings.runs = snap.runs; innings.wickets = snap.wickets
        innings.balls = snap.balls; innings.totalBalls = snap.totalBalls
        innings.extras = snap.extras; innings.wides = snap.wides
        innings.noBalls = snap.noBalls; innings.byes = snap.byes; innings.legByes = snap.legByes
        innings.batterStats = snap.batterStats; innings.bowlerStats = snap.bowlerStats
        innings.currentOver = snap.currentOver; innings.allOvers = snap.allOvers
        innings.currentStrikerIndex = snap.strikerIdx; innings.currentNonStrikerIndex = snap.nonStrikerIdx
        innings.currentBowlerIndex = snap.bowlerIdx; innings.fallOfWickets = snap.fallOfWickets
    }

    // MARK: - Change Batter
    func sendInBatter(_ player: Player, asStriker: Bool) {
        let creaseIndex = asStriker ? innings.currentStrikerIndex : innings.currentNonStrikerIndex
        let occupantIsOut = creaseIndex < innings.batterStats.count && innings.batterStats[creaseIndex].isOut
        let new = BatterStats(player: player, isOnStrike: asStriker)

        if creaseIndex < innings.batterStats.count && !occupantIsOut {
            // Manual change of a batter still at the crease: replace in place.
            innings.batterStats[creaseIndex] = new
        } else {
            // A dismissed batter (or empty crease) is being replaced: keep the out
            // batter's record in the scorecard and append the incoming batter, then
            // point the vacated crease at the new entry. This preserves the full
            // batting card and ensures an out batter can never be sent in again
            // (availableBatters excludes anyone already in batterStats).
            if creaseIndex < innings.batterStats.count {
                innings.batterStats[creaseIndex].isOnStrike = false
            }
            innings.batterStats.append(new)
            let newIndex = innings.batterStats.count - 1
            if asStriker {
                innings.currentStrikerIndex = newIndex
            } else {
                innings.currentNonStrikerIndex = newIndex
            }
        }

        showChangeBatterSheet = false
        newBatterName = ""
        selectedNewBatter = nil
    }

    func addNewBatterAndSend(name: String, role: PlayerRole, asStriker: Bool) {
        let p = Player(name: name, role: role)
        sendInBatter(p, asStriker: asStriker)
    }

    // MARK: - Change Bowler
    func setBowler(_ player: Player) {
        if let existing = innings.bowlerStats.firstIndex(where: { $0.player.id == player.id }) {
            innings.currentBowlerIndex = existing
        } else {
            let stats = BowlerStats(player: player)
            innings.bowlerStats.append(stats)
            innings.currentBowlerIndex = innings.bowlerStats.count - 1
        }
        showChangeBowlerSheet = false
        showEndOfOverSheet = false
        newBowlerName = ""
        selectedNewBowler = nil
    }

    func addNewBowlerAndSet(name: String, role: PlayerRole = .bowl) {
        let p = Player(name: name, role: role)
        setBowler(p)
    }

    private func promptForOpeningBowler() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.showChangeBowlerSheet = true
        }
    }

    // MARK: - Innings completion
    func checkInningsComplete() {
        let allOut = innings.wickets >= innings.battingTeam.players.count - 1 || innings.wickets >= 10
        let oversComplete = innings.totalBalls >= innings.totalOvers * 6
        // 2nd innings: target chased
        if match.currentInnings == 2, let target = match.target, innings.runs >= target {
            innings.isComplete = true
            computeResult()
            return
        }
        if allOut || oversComplete {
            innings.isComplete = true
            if match.currentInnings == 1 {
                showStartInnings2 = true
            } else {
                computeResult()
            }
        }
    }

    func beginInnings2() {
        match.startSecondInnings()
        observeModel()  // pick up the newly-created innings2 object
        showStartInnings2 = false
        undoStack = []
        promptForOpeningBowler()
    }

    private func computeResult() {
        guard let i2 = match.innings2 else { return }
        let target = match.innings1.runs + 1
        if i2.runs >= target {
            let wicketsLeft = (i2.battingTeam.players.count - 1) - i2.wickets
            match.result = "\(i2.battingTeam.name) won by \(wicketsLeft) wicket\(wicketsLeft == 1 ? "" : "s")!"
        } else {
            let diff = target - 1 - i2.runs
            match.result = "\(match.innings1.battingTeam.name) won by \(diff) run\(diff == 1 ? "" : "s")!"
        }
        match.isMatchOver = true
    }

    // MARK: - Helpers
    var availableBatters: [Player] {
        let usedIds = innings.batterStats.map { $0.player.id }
        return innings.battingTeam.players.filter { !usedIds.contains($0.id) }
    }

    var availableBowlers: [Player] {
        innings.bowlingTeam.players
    }

    func bowlerJustBowled(_ player: Player) -> Bool {
        guard innings.allOvers.count > 0 else { return false }
        // check if they bowled the previous over
        if let lastBowlerIdx = innings.bowlerStats.indices.last {
            _ = innings.bowlerStats[lastBowlerIdx]
        }
        // simplified: currentBowler can't bowl consecutive
        return false
    }

    func bowlerOversLeft(_ player: Player) -> Int {
        let maxPerBowler = innings.totalOvers / (innings.bowlingTeam.players.isEmpty ? 1 : max(1, innings.bowlingTeam.players.count / 2))
        let bowled = innings.bowlerStats.first(where: { $0.player.id == player.id })?.overs ?? 0
        return max(0, maxPerBowler - bowled)
    }

    var rrrColor: Color {
        guard let rrr = match.requiredRunRate else { return Theme.text }
        if rrr < 8 { return Theme.green }
        if rrr < 11 { return Theme.amber }
        return Theme.red
    }
}

// MARK: - Innings Snapshot for undo
struct InningsSnapshot {
    var runs, wickets, balls, totalBalls, extras, wides, noBalls, byes, legByes: Int
    var batterStats: [BatterStats]
    var bowlerStats: [BowlerStats]
    var currentOver: [BallEvent]
    var allOvers: [[BallEvent]]
    var strikerIdx, nonStrikerIdx, bowlerIdx: Int
    var fallOfWickets: [(Int, Int, String)]
}

enum ExtrasType: String, CaseIterable {
    case wide = "Wide", noBall = "No Ball", bye = "Bye", legBye = "Leg Bye"
    var color: Color {
        switch self { case .wide, .noBall: return Theme.purple; case .bye, .legBye: return Theme.cyan }
    }
    var maxRuns: Int {
        switch self { case .wide: return 4; case .noBall: return 7; case .bye, .legBye: return 4 }
    }
    var baseRuns: Int { self == .noBall || self == .wide ? 1 : 1 }
    var note: String {
        switch self {
        case .wide: return "+1 penalty. Select extra runs if byes scored."
        case .noBall: return "+1 penalty. Select runs hit off bat."
        case .bye: return "Runs scored without batter touching ball."
        case .legBye: return "Runs off pad/body without hitting bat."
        }
    }
}
