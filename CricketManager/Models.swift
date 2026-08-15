import SwiftUI
import SwiftData

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

// MARK: - Persistent team library (SwiftData)
// Match play uses value-type snapshots (CricketTeam/Player) so editing a saved
// team later never mutates a match that is already in progress or finished.
@Model
final class SavedTeam {
    var name: String = ""
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \SavedPlayer.team)
    var players: [SavedPlayer] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// Players in the order the user added them.
    var orderedPlayers: [SavedPlayer] { players.sorted { $0.order < $1.order } }

    /// Value-type snapshot used to start a match.
    func snapshot() -> CricketTeam {
        CricketTeam(name: name, players: orderedPlayers.map { Player(name: $0.name, role: $0.role) })
    }
}

@Model
final class SavedPlayer {
    var name: String = ""
    var role: PlayerRole = PlayerRole.bat
    var order: Int = 0
    var team: SavedTeam?

    init(name: String, role: PlayerRole, order: Int = 0) {
        self.name = name
        self.role = role
        self.order = order
    }
}

// MARK: - Career stats (SwiftData)
// All-time totals per player, keyed by name, accumulated each time a match finishes.
// This is what powers the leaderboard (top run scorers / wicket takers across matches).
@Model
final class PlayerCareerStat {
    var name: String = ""
    var role: PlayerRole = PlayerRole.bat
    var matches: Int = 0
    var runs: Int = 0
    var balls: Int = 0
    var fours: Int = 0
    var sixes: Int = 0
    var wickets: Int = 0
    var ballsBowled: Int = 0
    var runsConceded: Int = 0
    var highScore: Int = 0      // best runs in a single match
    var bestBowling: Int = 0    // most wickets in a single match

    init(name: String, role: PlayerRole) {
        self.name = name
        self.role = role
    }

    var strikeRate: Double { balls > 0 ? Double(runs) / Double(balls) * 100 : 0 }
    var economy: Double { ballsBowled > 0 ? Double(runsConceded) / (Double(ballsBowled) / 6.0) : 0 }
}

// MARK: - Calorie entry (SwiftData)
// A dated record of the calories a player burned in a single finished match,
// split by batting, bowling and fielding. Unlike PlayerCareerStat (which only
// keeps all-time totals), these carry a date so the Calories tab can show
// today's burn and a rolling 30-day history. One entry is created per player
// per match when the match ends.
@Model
final class CalorieEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date.now
    var playerName: String = ""
    var battingCalories: Double = 0
    var bowlingCalories: Double = 0
    var fieldingCalories: Double = 0

    init(id: UUID = UUID(), date: Date = .now, playerName: String,
         battingCalories: Double, bowlingCalories: Double, fieldingCalories: Double) {
        self.id = id
        self.date = date
        self.playerName = playerName
        self.battingCalories = battingCalories
        self.bowlingCalories = bowlingCalories
        self.fieldingCalories = fieldingCalories
    }

    var total: Int { Int((battingCalories + bowlingCalories + fieldingCalories).rounded()) }
}

// MARK: - Completed match (SwiftData)
// A durable record of a finished match, saved once when the result screen appears.
// This powers the History tab so past results (and their winners) persist across
// launches. Scores are stored as plain values — a snapshot of the final scorecard —
// so they never change if the underlying teams are later edited or deleted.
@Model
final class CompletedMatch {
    var date: Date = Date.now
    var firstBattingTeam: String = ""
    var firstRuns: Int = 0
    var firstWickets: Int = 0
    var firstOvers: String = ""
    var secondBattingTeam: String = ""
    var secondRuns: Int = 0
    var secondWickets: Int = 0
    var secondOvers: String = ""
    var winnerName: String = ""       // empty for a tie
    var resultText: String = ""       // e.g. "won by 5 wickets" / "Match tied!"
    var totalOvers: Int = 0
    var manOfTheMatch: String = ""
    var isTie: Bool = false

    init(date: Date = .now,
         firstBattingTeam: String, firstRuns: Int, firstWickets: Int, firstOvers: String,
         secondBattingTeam: String, secondRuns: Int, secondWickets: Int, secondOvers: String,
         winnerName: String, resultText: String, totalOvers: Int,
         manOfTheMatch: String, isTie: Bool) {
        self.date = date
        self.firstBattingTeam = firstBattingTeam
        self.firstRuns = firstRuns
        self.firstWickets = firstWickets
        self.firstOvers = firstOvers
        self.secondBattingTeam = secondBattingTeam
        self.secondRuns = secondRuns
        self.secondWickets = secondWickets
        self.secondOvers = secondOvers
        self.winnerName = winnerName
        self.resultText = resultText
        self.totalOvers = totalOvers
        self.manOfTheMatch = manOfTheMatch
        self.isTie = isTie
    }
}

// MARK: - Registered player (SwiftData)
// A self-registered player profile. First name, last name and phone number are
// required, and each player is identified by a unique id. Phone numbers must be
// unique across players (enforced at registration). Email and photo are optional;
// photo bytes are kept in external storage so large images don't bloat the store.
@Model
final class RegisteredPlayer {
    @Attribute(.unique) var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var email: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), firstName: String, lastName: String, phone: String = "", email: String = "", photoData: Data? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email
        self.photoData = photoData
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    var initials: String {
        let f = firstName.first.map { String($0) } ?? ""
        let l = lastName.first.map { String($0) } ?? ""
        return (f + l).uppercased()
    }
    /// Phone with only its digits, used to compare numbers regardless of formatting.
    var normalizedPhone: String { phone.filter(\.isNumber) }
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

enum TeamSide: Identifiable, Hashable { case a, b
    var id: Int { self == .a ? 0 : 1 }
}
