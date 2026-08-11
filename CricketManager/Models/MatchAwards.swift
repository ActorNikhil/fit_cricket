import SwiftUI

// MARK: - Match Awards
struct MatchAwards {
    var manOfTheMatch: AwardPlayer
    var bestBatter: AwardPlayer
    var bestBowler: AwardBowler
    var keyMoments: [KeyMoment]
    var winMargin: WinMargin
}

struct AwardPlayer {
    var player: Player
    var teamName: String
    var runs: Int
    var balls: Int
    var fours: Int
    var sixes: Int
    var isNotOut: Bool
    var wickets: Int      // if all-rounder
    var bowlingRuns: Int  // if all-rounder
    var bowlingOvers: String
    var strikeRate: Double { balls > 0 ? Double(runs) / Double(balls) * 100 : 0 }
    var isAllRound: Bool { wickets > 0 && runs > 30 }
}

struct AwardBowler {
    var player: Player
    var teamName: String
    var wickets: Int
    var runs: Int
    var overs: Int
    var balls: Int
    var economy: Double { (overs * 6 + balls) > 0 ? Double(runs) / (Double(overs * 6 + balls) / 6.0) : 0 }
    var figures: String { "\(wickets)/\(runs)" }
    var oversDisplay: String { "\(overs).\(balls)" }
}

enum WinMargin {
    case wickets(Int, String)   // wickets remaining, winning team
    case runs(Int, String)      // run difference, winning team
    case tie
    var display: String {
        switch self {
        case .wickets(let w, let t): return "\(t) won by \(w) wicket\(w == 1 ? "" : "s")"
        case .runs(let r, let t): return "\(t) won by \(r) run\(r == 1 ? "" : "s")"
        case .tie: return "Match tied!"
        }
    }
    var marginText: String {
        switch self {
        case .wickets(let w, _): return "by \(w) wickets"
        case .runs(let r, _): return "by \(r) runs"
        case .tie: return "Tie"
        }
    }
    var winnerName: String {
        switch self {
        case .wickets(_, let t): return t
        case .runs(_, let t): return t
        case .tie: return "Both teams"
        }
    }
    var accentColor: Color {
        switch self {
        case .wickets: return Theme.green
        case .runs: return Theme.cyan
        case .tie: return Theme.gold
        }
    }
}

struct KeyMoment: Identifiable {
    var id = UUID()
    var icon: String
    var description: String
    var value: String
    var valueColor: Color
}

// MARK: - Awards Computation
extension ScoringViewModel {

    func computeAwards() -> MatchAwards {
        let inn1 = match.innings1
        let inn2 = match.innings2

        // Win margin
        let margin: WinMargin
        if let i2 = inn2 {
            let target = inn1.runs + 1
            if i2.runs >= target {
                let wLeft = max(0, i2.battingTeam.players.count - 1 - i2.wickets)
                margin = .wickets(wLeft, i2.battingTeam.name)
            } else if i2.runs == inn1.runs {
                margin = .tie
            } else {
                let diff = inn1.runs - i2.runs
                margin = .runs(diff, inn1.battingTeam.name)
            }
        } else {
            margin = .runs(0, inn1.battingTeam.name)
        }

        // All batter stats across both innings
        var allBatters: [(BatterStats, String)] = inn1.batterStats.map { ($0, inn1.battingTeam.name) }
        if let i2 = inn2 { allBatters += i2.batterStats.map { ($0, i2.battingTeam.name) } }

        // All bowler stats across both innings
        var allBowlers: [(BowlerStats, String)] = inn1.bowlerStats.map { ($0, inn1.bowlingTeam.name) }
        if let i2 = inn2 { allBowlers += i2.bowlerStats.map { ($0, i2.bowlingTeam.name) } }

        // Best batter: highest runs
        let bestBatterRaw = allBatters.max(by: { $0.0.runs < $1.0.runs })
        let bestBatterData = bestBatterRaw ?? (BatterStats(player: Player(name: "—", role: .bat)), "—")
        let bestBatter = AwardPlayer(
            player: bestBatterData.0.player,
            teamName: bestBatterData.1,
            runs: bestBatterData.0.runs,
            balls: bestBatterData.0.balls,
            fours: bestBatterData.0.fours,
            sixes: bestBatterData.0.sixes,
            isNotOut: !bestBatterData.0.isOut,
            wickets: 0, bowlingRuns: 0, bowlingOvers: ""
        )

        // Best bowler: most wickets, then lowest economy
        let bestBowlerRaw = allBowlers.max(by: {
            if $0.0.wickets != $1.0.wickets { return $0.0.wickets < $1.0.wickets }
            return $0.0.economy > $1.0.economy
        })
        let bestBowlerData = bestBowlerRaw ?? (BowlerStats(player: Player(name: "—", role: .bowl)), "—")
        let bestBowler = AwardBowler(
            player: bestBowlerData.0.player,
            teamName: bestBowlerData.1,
            wickets: bestBowlerData.0.wickets,
            runs: bestBowlerData.0.runs,
            overs: bestBowlerData.0.overs,
            balls: bestBowlerData.0.balls
        )

        // Man of the match: score each player
        // Batting score = runs + fours*2 + sixes*4 + (notout ? 10 : 0)
        // Bowling score = wickets*25 + (economy < 6 ? 15 : economy < 8 ? 8 : 0)
        func batterScore(_ b: BatterStats) -> Double {
            Double(b.runs) + Double(b.fours) * 2 + Double(b.sixes) * 4 + (b.isOut ? 0 : 10)
        }
        func bowlerScore(_ b: BowlerStats) -> Double {
            Double(b.wickets) * 25 + (b.economy < 6 ? 15 : b.economy < 8 ? 8 : 0)
        }

        var playerScores: [(Player, Double, String, BatterStats?, BowlerStats?)] = []
        for (bat, team) in allBatters {
            let bowlStats = allBowlers.first(where: { $0.0.player.id == bat.player.id })
            let bs = bowlStats.map { bowlerScore($0.0) } ?? 0
            playerScores.append((bat.player, batterScore(bat) + bs, team, bat, bowlStats?.0))
        }

        let motmEntry = playerScores.max(by: { $0.1 < $1.1 })
        let motmBat = motmEntry?.3
        let motmBowl = motmEntry?.4

        let motm = AwardPlayer(
            player: motmEntry?.0 ?? Player(name: "—", role: .bat),
            teamName: motmEntry?.2 ?? "—",
            runs: motmBat?.runs ?? 0,
            balls: motmBat?.balls ?? 0,
            fours: motmBat?.fours ?? 0,
            sixes: motmBat?.sixes ?? 0,
            isNotOut: !(motmBat?.isOut ?? true),
            wickets: motmBowl?.wickets ?? 0,
            bowlingRuns: motmBowl?.runs ?? 0,
            bowlingOvers: motmBowl.map { "\($0.overs).\($0.balls)" } ?? ""
        )

        // Key moments
        var moments: [KeyMoment] = []
        if bestBatter.sixes >= 3 {
            moments.append(KeyMoment(icon: "⚡", description: "\(bestBatter.player.name) hit \(bestBatter.sixes) sixes", value: "+\(bestBatter.sixes * 6)", valueColor: Theme.gold))
        }
        if bestBowler.wickets >= 3 {
            moments.append(KeyMoment(icon: "🎯", description: "\(bestBowler.player.name): \(bestBowler.wickets) wickets for \(bestBowler.runs)", value: "\(bestBowler.wickets)W", valueColor: Theme.red))
        }
        if bestBatter.runs >= 50 {
            moments.append(KeyMoment(icon: "🏏", description: "\(bestBatter.player.name) scored a \(bestBatter.runs >= 100 ? "century" : "half-century")", value: "\(bestBatter.runs)\(bestBatter.isNotOut ? "*" : "")", valueColor: Theme.bat))
        }
        if let i2 = inn2, i2.wickets >= 8 {
            moments.append(KeyMoment(icon: "💥", description: "Bowling collapse — \(i2.wickets) wickets fell", value: "\(i2.wickets)W", valueColor: Theme.purple))
        }

        return MatchAwards(
            manOfTheMatch: motm,
            bestBatter: bestBatter,
            bestBowler: bestBowler,
            keyMoments: moments,
            winMargin: margin
        )
    }
}
