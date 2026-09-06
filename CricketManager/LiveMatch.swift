import Foundation
import Supabase

// MARK: - Live match sync
// A match in progress lives only in memory (Match / Innings). To let other
// participants follow it in real time, the scoring device mirrors a compact
// snapshot of the scorecard into the Supabase `live_matches` table on every
// scoring event. Participant devices (whose profile phone is in the roster) poll
// that table and show a "LIVE" card in "Matches of your interest". The row is
// deleted when the match ends or the scoring screen is dismissed; once finished,
// the durable CompletedMatch takes over (pulled read-only by the sync engine).

// Wire DTO — property names mirror the Postgres columns exactly.
struct LiveMatchRow: Codable, Sendable, Identifiable {
    var id: String
    var user_id: String
    var updated_at: String
    var first_batting_team: String
    var first_runs: Int
    var first_wickets: Int
    var first_overs: String
    var second_batting_team: String
    var second_runs: Int
    var second_wickets: Int
    var second_overs: String
    var current_innings: Int
    var total_overs: Int
    var target: Int?
    var batting_team: String        // team currently at the crease
    var player_names: [String]
    var player_phones: [String]
    // Full scorecard (both innings) as JSON, so participants see the complete
    // batting/bowling detail — not just the summary. Optional so rows written
    // before the column existed still decode.
    var scorecard: String?

    // Live rows are only meaningful while the scorer is actively pushing. If the
    // app was killed mid-match the row can linger, so readers hide anything that
    // hasn't been updated recently.
    var isRecent: Bool {
        guard let d = LiveMatchDate.parse(updated_at) else { return true }
        return Date.now.timeIntervalSince(d) < 300   // 5 minutes
    }
}

// MARK: - Full scorecard snapshot
// A Codable capture of the complete match scorecard (both innings, every batter
// and bowler, extras and fall of wickets). The scoring device serialises this to
// JSON on every ball; participant devices decode it and rebuild Innings objects
// to render the exact same scorecard views.
struct ScorecardSnapshot: Codable, Sendable {
    struct Batter: Codable, Sendable {
        var name: String
        var runs: Int, balls: Int, fours: Int, sixes: Int
        var isOut: Bool, dismissal: String, onStrike: Bool
    }
    struct Bowler: Codable, Sendable {
        var name: String
        var overs: Int, balls: Int, runs: Int, wickets: Int, wides: Int, noBalls: Int
    }
    struct Fow: Codable, Sendable { var runs: Int, wickets: Int, name: String }
    struct Inn: Codable, Sendable {
        var battingTeam: String, bowlingTeam: String
        var runs: Int, wickets: Int, totalBalls: Int
        var extras: Int, wides: Int, noBalls: Int, byes: Int, legByes: Int
        var batters: [Batter], bowlers: [Bowler], fow: [Fow]
    }
    var totalOvers: Int
    var currentInnings: Int
    var target: Int?
    var innings: [Inn]

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> ScorecardSnapshot? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ScorecardSnapshot.self, from: data)
    }
}

extension Match {
    /// Build a LiveMatchRow purely for rendering the Home "LIVE" card of the
    /// user's own in-progress match (parked when they leave the scoring screen).
    /// Only the display fields are populated; roster/scorecard aren't needed here.
    func displayLiveRow() -> LiveMatchRow {
        let i1 = innings1
        let i2 = innings2
        return LiveMatchRow(
            id: liveID.uuidString,
            user_id: "",
            updated_at: LiveMatchDate.now(),
            first_batting_team: battingFirst.name,
            first_runs: i1.runs, first_wickets: i1.wickets, first_overs: i1.oversDisplay,
            second_batting_team: fieldingFirst.name,
            second_runs: i2?.runs ?? 0, second_wickets: i2?.wickets ?? 0,
            second_overs: i2?.oversDisplay ?? "",
            current_innings: currentInnings,
            total_overs: totalOvers,
            target: target,
            batting_team: activeInnings.battingTeam.name,
            player_names: [], player_phones: [], scorecard: nil)
    }

    /// Snapshot the live scorecard for broadcast / persistence.
    func scorecardSnapshot() -> ScorecardSnapshot {
        func snap(_ inn: Innings) -> ScorecardSnapshot.Inn {
            ScorecardSnapshot.Inn(
                battingTeam: inn.battingTeam.name, bowlingTeam: inn.bowlingTeam.name,
                runs: inn.runs, wickets: inn.wickets, totalBalls: inn.totalBalls,
                extras: inn.extras, wides: inn.wides, noBalls: inn.noBalls,
                byes: inn.byes, legByes: inn.legByes,
                batters: inn.batterStats.map {
                    .init(name: $0.player.name, runs: $0.runs, balls: $0.balls,
                          fours: $0.fours, sixes: $0.sixes, isOut: $0.isOut,
                          dismissal: $0.dismissal, onStrike: $0.isOnStrike)
                },
                bowlers: inn.bowlerStats.map {
                    .init(name: $0.player.name, overs: $0.overs, balls: $0.balls,
                          runs: $0.runs, wickets: $0.wickets, wides: $0.wides, noBalls: $0.noBalls)
                },
                fow: inn.fallOfWickets.map { .init(runs: $0.0, wickets: $0.1, name: $0.2) })
        }
        var list = [snap(innings1)]
        if let i2 = innings2 { list.append(snap(i2)) }
        return ScorecardSnapshot(totalOvers: totalOvers, currentInnings: currentInnings,
                                 target: target, innings: list)
    }
}

extension ScorecardSnapshot {
    /// Rebuild Innings objects so the existing BattingCard/BowlingCard/
    /// FallOfWicketsCard views can render this synced scorecard unchanged.
    func makeInnings() -> [Innings] {
        innings.map { i in
            let inn = Innings(batting: CricketTeam(name: i.battingTeam),
                              bowling: CricketTeam(name: i.bowlingTeam), overs: totalOvers)
            inn.batterStats = i.batters.map { b in
                var s = BatterStats(player: Player(name: b.name, role: .bat))
                s.runs = b.runs; s.balls = b.balls; s.fours = b.fours; s.sixes = b.sixes
                s.isOut = b.isOut; s.dismissal = b.dismissal; s.isOnStrike = b.onStrike
                return s
            }
            inn.bowlerStats = i.bowlers.map { b in
                var s = BowlerStats(player: Player(name: b.name, role: .bowl))
                s.overs = b.overs; s.balls = b.balls; s.runs = b.runs
                s.wickets = b.wickets; s.wides = b.wides; s.noBalls = b.noBalls
                return s
            }
            inn.runs = i.runs; inn.wickets = i.wickets; inn.totalBalls = i.totalBalls
            inn.extras = i.extras; inn.wides = i.wides; inn.noBalls = i.noBalls
            inn.byes = i.byes; inn.legByes = i.legByes
            inn.fallOfWickets = i.fow.map { ($0.runs, $0.wickets, $0.name) }
            return inn
        }
    }
}

// MARK: - Broadcaster (scoring device)

@MainActor
final class LiveMatchService {
    private let client = SupabaseManager.shared.client
    private let id: UUID
    private var latest: LiveMatchRow?
    private var publishing = false
    private var ended = false

    init(id: UUID) { self.id = id }

    /// Queue the newest scorecard snapshot for upload. Coalescing keeps a single
    /// upsert in flight at a time and preserves order, so rapid balls don't race.
    func publish(_ row: LiveMatchRow) {
        guard !ended else { return }
        latest = row
        guard !publishing else { return }
        pump()
    }

    private func pump() {
        guard let row = latest else { return }
        latest = nil
        publishing = true
        Task { [weak self] in
            do {
                _ = try await self?.client.from("live_matches").upsert(row).execute()
            } catch {
                #if DEBUG
                print("[Live] publish error: \(error)")
                #endif
            }
            guard let self else { return }
            self.publishing = false
            if self.latest != nil, !self.ended { self.pump() }
        }
    }

    /// Remove the live row (match finished or scoring screen dismissed). Idempotent.
    func end() {
        guard !ended else { return }
        ended = true
        latest = nil
        let idStr = id.uuidString
        let client = self.client
        Task {
            do {
                _ = try await client.from("live_matches").delete().eq("id", value: idStr).execute()
            } catch {
                #if DEBUG
                print("[Live] end error: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Reader (participant devices)

enum LiveMatchReader {
    /// Live matches the signed-in user is part of but is not scoring themselves.
    /// Matched on the profile phone appearing in the row's `player_phones`; the
    /// scorer's own row is excluded (they see it on the scoring screen).
    static func fetch(myPhone: String, myUserID: String) async -> [LiveMatchRow] {
        let phone = CompletedMatch.normalizePhone(myPhone)
        guard !phone.isEmpty else { return [] }
        do {
            let rows: [LiveMatchRow] = try await SupabaseManager.shared.client
                .from("live_matches")
                .select()
                .contains("player_phones", value: [phone])
                .execute()
                .value
            return rows.filter { $0.user_id != myUserID && $0.isRecent }
        } catch {
            #if DEBUG
            print("[Live] fetch error: \(error)")
            #endif
            return []
        }
    }
}

// MARK: - ISO8601 helpers (robust to Postgres microsecond timestamps)

enum LiveMatchDate {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func now() -> String { withFractional.string(from: .now) }

    static func parse(_ string: String) -> Date? {
        if let d = withFractional.date(from: string) { return d }
        let trimmed = string.replacingOccurrences(
            of: #"\.(\d{3})\d+"#, with: ".$1", options: .regularExpression)
        if let d = withFractional.date(from: trimmed) { return d }
        let noFraction = string.replacingOccurrences(
            of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: noFraction)
    }
}
