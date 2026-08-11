import SwiftUI

// MARK: - Player Role
enum PlayerRole: String, CaseIterable, Codable, Identifiable {
    case bat = "BAT", bowl = "BOW", allRounder = "AR", wicketKeeper = "WK"
    var id: String { rawValue }
    var label: String {
        switch self { case .bat: return "Batter"; case .bowl: return "Bowler"; case .allRounder: return "All-Rounder"; case .wicketKeeper: return "Wicket-Keeper" }
    }
    var short: String { rawValue }
    var icon: String {
        switch self { case .bat: return "🏏"; case .bowl: return "🎯"; case .allRounder: return "⚡"; case .wicketKeeper: return "🧤" }
    }
    var color: Color {
        switch self { case .bat: return Theme.bat; case .bowl: return Theme.bowl; case .allRounder: return Theme.allr; case .wicketKeeper: return Theme.wk }
    }
}

// MARK: - Player
struct Player: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var role: PlayerRole
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined().prefix(2).string
    }
}

extension Substring { var string: String { String(self) } }
extension String { var prefix2: String { String(prefix(2)) } }

// MARK: - Team
struct CricketTeam: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var players: [Player] = []
}

// MARK: - Ball event
enum BallEvent: Equatable {
    case runs(Int)
    case wide(Int)
    case noBall(Int)
    case bye(Int)
    case legBye(Int)
    case wicket(DismissalType, Int)  // type + runs scored

    var displayText: String {
        switch self {
        case .runs(let r): return r == 0 ? "•" : "\(r)"
        case .wide: return "Wd"
        case .noBall: return "NB"
        case .bye(let r): return "B\(r)"
        case .legBye(let r): return "LB\(r)"
        case .wicket(_, let r): return r > 0 ? "\(r)W" : "W"
        }
    }

    var isBoundary: Bool {
        if case .runs(let r) = self { return r == 4 || r == 6 }
        return false
    }
    var isSix: Bool {
        if case .runs(6) = self { return true }
        return false
    }
    var countsAsBall: Bool {
        switch self {
        case .wide, .noBall: return false
        default: return true
        }
    }
    var runsScored: Int {
        switch self {
        case .runs(let r): return r
        case .wide(let r): return r
        case .noBall(let r): return r
        case .bye(let r): return r
        case .legBye(let r): return r
        case .wicket(_, let r): return r
        }
    }
    var isWicket: Bool {
        if case .wicket = self { return true }
        return false
    }

    var color: Color {
        switch self {
        case .runs(let r):
            if r == 6 { return Theme.gold }
            if r == 4 { return Theme.green }
            return Theme.text
        case .wide, .noBall: return Theme.purple
        case .bye, .legBye: return Theme.cyan
        case .wicket: return Theme.red
        }
    }
    var bgColor: Color {
        switch self {
        case .runs(let r):
            if r == 6 { return Theme.gold.opacity(0.15) }
            if r == 4 { return Theme.green.opacity(0.15) }
            return Theme.surface3
        case .wide, .noBall: return Theme.purple.opacity(0.12)
        case .bye, .legBye: return Theme.cyan.opacity(0.12)
        case .wicket: return Theme.red.opacity(0.15)
        }
    }
}

// MARK: - Dismissal
enum DismissalType: String, CaseIterable, Codable {
    case caught = "Caught", bowled = "Bowled", lbw = "LBW", runOut = "Run Out", stumped = "Stumped", hitWicket = "Hit Wicket"
}

// MARK: - Batter stats
struct BatterStats: Identifiable {
    var id: UUID = UUID()
    var player: Player
    var runs: Int = 0
    var balls: Int = 0
    var fours: Int = 0
    var sixes: Int = 0
    var isOut: Bool = false
    var dismissal: String = ""
    var isOnStrike: Bool = false
    var strikeRate: Double { balls > 0 ? Double(runs) / Double(balls) * 100 : 0 }
}

// MARK: - Bowler stats
struct BowlerStats: Identifiable {
    var id: UUID = UUID()
    var player: Player
    var overs: Int = 0
    var balls: Int = 0  // balls in current over
    var runs: Int = 0
    var wickets: Int = 0
    var wides: Int = 0
    var noBalls: Int = 0
    var totalBalls: Int { overs * 6 + balls }
    var economy: Double { totalBalls > 0 ? Double(runs) / (Double(totalBalls) / 6.0) : 0 }
    var overString: String { "\(overs)-\(balls)-\(runs)-\(wickets)" }
}

// MARK: - Innings
class Innings: ObservableObject, Identifiable {
    var id: UUID = UUID()
    var battingTeam: CricketTeam
    var bowlingTeam: CricketTeam
    var totalOvers: Int

    @Published var runs: Int = 0
    @Published var wickets: Int = 0
    @Published var balls: Int = 0          // legal balls in current over
    @Published var totalBalls: Int = 0     // total legal balls bowled
    @Published var extras: Int = 0
    @Published var wides: Int = 0
    @Published var noBalls: Int = 0
    @Published var byes: Int = 0
    @Published var legByes: Int = 0

    @Published var batterStats: [BatterStats] = []
    @Published var bowlerStats: [BowlerStats] = []
    @Published var currentOver: [BallEvent] = []
    @Published var allOvers: [[BallEvent]] = []
    @Published var fallOfWickets: [(Int, Int, String)] = []  // (runs, wickets, player)

    @Published var isComplete: Bool = false
    @Published var ballHistory: [[BallEvent]] = []  // for undo — snapshot per ball

    var currentStrikerIndex: Int = 0
    var currentNonStrikerIndex: Int = 1
    var currentBowlerIndex: Int = 0

    var striker: BatterStats? {
        guard currentStrikerIndex < batterStats.count else { return nil }
        return batterStats[currentStrikerIndex]
    }
    var nonStriker: BatterStats? {
        guard currentNonStrikerIndex < batterStats.count else { return nil }
        return batterStats[currentNonStrikerIndex]
    }
    var currentBowler: BowlerStats? {
        guard currentBowlerIndex < bowlerStats.count else { return nil }
        return bowlerStats[currentBowlerIndex]
    }

    var overNumber: Int { totalBalls / 6 }
    var ballInOver: Int { totalBalls % 6 }
    var oversDisplay: String { "\(overNumber).\(ballInOver)" }
    var runRate: Double { totalBalls > 0 ? Double(runs) / (Double(totalBalls) / 6.0) : 0 }
    var remainingBalls: Int { totalOvers * 6 - totalBalls }
    var remainingOvers: String {
        let b = remainingBalls
        return "\(b / 6).\(b % 6)"
    }

    init(batting: CricketTeam, bowling: CricketTeam, overs: Int) {
        self.battingTeam = batting
        self.bowlingTeam = bowling
        self.totalOvers = overs
        setupInitialBatters()
    }

    func setupInitialBatters() {
        let players = battingTeam.players
        if players.count > 0 {
            var s1 = BatterStats(player: players[0]); s1.isOnStrike = true
            batterStats.append(s1)
        }
        if players.count > 1 {
            batterStats.append(BatterStats(player: players[1]))
        }
    }
}

// MARK: - Match
class Match: ObservableObject {
    var teamA: CricketTeam
    var teamB: CricketTeam
    var totalOvers: Int
    var battingFirstSide: TeamSide

    @Published var currentInnings: Int = 1
    @Published var innings1: Innings
    @Published var innings2: Innings?
    @Published var isMatchOver: Bool = false
    @Published var result: String = ""

    var battingFirst: CricketTeam { battingFirstSide == .a ? teamA : teamB }
    var fieldingFirst: CricketTeam { battingFirstSide == .a ? teamB : teamA }

    init(teamA: CricketTeam, teamB: CricketTeam, overs: Int, battingFirst: TeamSide) {
        self.teamA = teamA; self.teamB = teamB
        self.totalOvers = overs; self.battingFirstSide = battingFirst
        let bat = battingFirst == .a ? teamA : teamB
        let bowl = battingFirst == .a ? teamB : teamA
        self.innings1 = Innings(batting: bat, bowling: bowl, overs: overs)
    }

    var activeInnings: Innings { innings2 ?? innings1 }

    func startSecondInnings() {
        let bat = battingFirstSide == .a ? teamB : teamA
        let bowl = battingFirstSide == .a ? teamA : teamB
        innings2 = Innings(batting: bat, bowling: bowl, overs: totalOvers)
        currentInnings = 2
    }

    var target: Int? { currentInnings == 2 ? innings1.runs + 1 : nil }

    var runsNeeded: Int? {
        guard let t = target, let i2 = innings2 else { return nil }
        return max(0, t - i2.runs)
    }
    var ballsRemaining2nd: Int? { innings2.map { $0.remainingBalls } }
    var requiredRunRate: Double? {
        guard let rn = runsNeeded, let br = ballsRemaining2nd, br > 0 else { return nil }
        return Double(rn) / (Double(br) / 6.0)
    }
    var chaseProgress: Double? {
        guard let t = target, let i2 = innings2 else { return nil }
        return min(1.0, Double(i2.runs) / Double(t))
    }
}

enum TeamSide { case a, b }
