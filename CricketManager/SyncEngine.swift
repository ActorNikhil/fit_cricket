import Foundation
import SwiftData
import Supabase

// MARK: - SyncEngine
// Mirrors the user's local SwiftData between the device and Supabase so their
// data follows them across devices. SwiftData stays the source of truth (the app
// works fully offline); this engine reconciles it with the cloud whenever we're
// online — on sign-in, when the app comes to the foreground, and on a short timer.
//
// Reconciliation model (per table): we diff three sets of row ids — what's local
// now, what's on the server now, and what we last synced (persisted in
// UserDefaults). From that we derive creates, updates and deletes on both sides,
// so deletions propagate without needing tombstones and without changing any of
// the existing views. Push happens before pull each cycle; conflicts are resolved
// "last writer wins" (fine for a single user syncing their own devices).
//
// Deferred to a follow-up: player_career_stats (needs name-keyed merge for its
// unique(user_id,name) constraint) and photo blobs (Storage upload/download).
@MainActor
final class SyncEngine {
    private let client = SupabaseManager.shared.client
    private let context: ModelContext

    private var userID: UUID?
    private var isSyncing = false
    private var timer: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Lifecycle

    func start(userID: UUID) {
        self.userID = userID
        requestSync()
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await self?.syncAll()
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        userID = nil
    }

    /// Fire-and-forget sync (safe to call often; overlapping calls are ignored).
    func requestSync() {
        Task { await syncAll() }
    }

    func syncAll() async {
        guard let userID, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await syncProfile(userID)
            try await syncSavedTeams(userID)
            try await syncSavedPlayers(userID)
            try await syncCalorieEntries(userID)
            try await syncCompletedMatches(userID)
            try await syncRegisteredPlayers(userID)
        } catch {
            #if DEBUG
            print("[Sync] error: \(error)")
            #endif
        }
    }

    // MARK: Generic reconcile

    private func reconcile<Row: Codable & Sendable>(
        table: String,
        userID: UUID,
        localRows: [UUID: Row],
        idOf: (Row) -> UUID?,
        applyLocal: (Row) -> Void,
        deleteLocal: (UUID) -> Void
    ) async throws {
        // Current server state (RLS already scopes to this user, but we filter too).
        let remoteArray: [Row] = try await client.from(table)
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        var remoteRows: [UUID: Row] = [:]
        for row in remoteArray { if let id = idOf(row) { remoteRows[id] = row } }

        let prev = loadSynced(table)
        let localIDs = Set(localRows.keys)
        let remoteIDs = Set(remoteRows.keys)

        // Rows we had and synced before, now gone locally → delete on server.
        let localDeleted = prev.subtracting(localIDs).intersection(remoteIDs)
        for id in localDeleted {
            _ = try await client.from(table).delete().eq("id", value: id.uuidString).execute()
        }

        // Rows we synced before, now gone on the server → delete locally.
        let remoteDeleted = prev.subtracting(remoteIDs).intersection(localIDs)
        for id in remoteDeleted { deleteLocal(id) }

        // Push local creates/updates (everything local we're not deleting).
        let toPush = localRows.compactMap { localDeleted.contains($0.key) ? nil : $0.value }
        if !toPush.isEmpty {
            _ = try await client.from(table).upsert(toPush).execute()
        }

        // Pull remote creates/updates into SwiftData.
        for (id, row) in remoteRows where !localDeleted.contains(id) && !remoteDeleted.contains(id) {
            applyLocal(row)
        }

        var newSynced = localIDs.union(remoteIDs)
        newSynced.subtract(localDeleted)
        newSynced.subtract(remoteDeleted)
        saveSynced(table, newSynced)
        try? context.save()
    }

    // MARK: Profile (single row keyed by the auth user id)

    private func syncProfile(_ userID: UUID) async throws {
        guard let p = try context.fetch(FetchDescriptor<UserProfile>()).first else { return }

        let remote: [SyncProfileRow] = try await client.from("profiles")
            .select().eq("id", value: userID.uuidString).execute().value
        let serverHasName = remote.first.map { !($0.first_name.isEmpty && $0.last_name.isEmpty) } ?? false
        let localHasName = !(p.firstName.isEmpty && p.lastName.isEmpty)

        if serverHasName, !localHasName, let r = remote.first {
            // Local profile is blank (e.g. just signed in on a fresh device) but
            // the account already has details in the cloud → adopt the cloud copy.
            p.firstName = r.first_name
            p.lastName = r.last_name
            if !r.phone.isEmpty { p.phone = r.phone }
            if !r.email.isEmpty { p.email = r.email }
            if let role = r.role, !role.isEmpty { p.role = role }
            try? context.save()
        } else {
            // Local is the source of truth → push it up.
            let row = SyncProfileRow(id: userID.uuidString, first_name: p.firstName,
                                     last_name: p.lastName, phone: p.phone, email: p.email,
                                     role: p.role)
            _ = try await client.from("profiles").upsert(row).execute()
        }
    }

    // MARK: Saved teams

    private func syncSavedTeams(_ userID: UUID) async throws {
        let teams = try context.fetch(FetchDescriptor<SavedTeam>())
        var byID = Dictionary(teams.map { ($0.remoteID, $0) }, uniquingKeysWith: { a, _ in a })
        var local: [UUID: SyncTeamRow] = [:]
        for t in teams {
            local[t.remoteID] = SyncTeamRow(id: t.remoteID.uuidString, user_id: userID.uuidString,
                                        name: t.name, created_at: ISO.string(t.createdAt))
        }
        try await reconcile(
            table: "saved_teams", userID: userID, localRows: local,
            idOf: { UUID(uuidString: $0.id) },
            applyLocal: { row in
                guard let rid = UUID(uuidString: row.id) else { return }
                if let existing = byID[rid] {
                    existing.name = row.name
                } else {
                    let t = SavedTeam(name: row.name, createdAt: ISO.date(row.created_at) ?? .now)
                    t.remoteID = rid
                    self.context.insert(t)
                    byID[rid] = t
                }
            },
            deleteLocal: { rid in
                if let t = byID[rid] { self.context.delete(t); byID[rid] = nil }
            }
        )
    }

    // MARK: Saved players

    private func syncSavedPlayers(_ userID: UUID) async throws {
        let players = try context.fetch(FetchDescriptor<SavedPlayer>())
        let teams = try context.fetch(FetchDescriptor<SavedTeam>())
        let teamByRemote = Dictionary(teams.map { ($0.remoteID, $0) }, uniquingKeysWith: { a, _ in a })
        var byID = Dictionary(players.map { ($0.remoteID, $0) }, uniquingKeysWith: { a, _ in a })
        var local: [UUID: SyncPlayerRow] = [:]
        for p in players {
            local[p.remoteID] = SyncPlayerRow(id: p.remoteID.uuidString, user_id: userID.uuidString,
                                          team_id: p.team?.remoteID.uuidString, name: p.name,
                                          role: p.role.rawValue, sort_order: p.order)
        }
        try await reconcile(
            table: "saved_players", userID: userID, localRows: local,
            idOf: { UUID(uuidString: $0.id) },
            applyLocal: { row in
                guard let rid = UUID(uuidString: row.id) else { return }
                let team = row.team_id.flatMap { UUID(uuidString: $0) }.flatMap { teamByRemote[$0] }
                if let existing = byID[rid] {
                    existing.name = row.name
                    existing.role = PlayerRole(rawValue: row.role) ?? .bat
                    existing.order = row.sort_order
                    existing.team = team
                } else {
                    let p = SavedPlayer(name: row.name, role: PlayerRole(rawValue: row.role) ?? .bat,
                                        order: row.sort_order)
                    p.remoteID = rid
                    p.team = team
                    self.context.insert(p)
                    byID[rid] = p
                }
            },
            deleteLocal: { rid in
                if let p = byID[rid] { self.context.delete(p); byID[rid] = nil }
            }
        )
    }

    // MARK: Calorie entries

    private func syncCalorieEntries(_ userID: UUID) async throws {
        let entries = try context.fetch(FetchDescriptor<CalorieEntry>())
        var byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var local: [UUID: SyncCalorieRow] = [:]
        for e in entries {
            local[e.id] = SyncCalorieRow(id: e.id.uuidString, user_id: userID.uuidString,
                                     date: ISO.string(e.date), player_name: e.playerName,
                                     batting_calories: e.battingCalories,
                                     bowling_calories: e.bowlingCalories,
                                     fielding_calories: e.fieldingCalories)
        }
        try await reconcile(
            table: "calorie_entries", userID: userID, localRows: local,
            idOf: { UUID(uuidString: $0.id) },
            applyLocal: { row in
                guard let rid = UUID(uuidString: row.id) else { return }
                if let existing = byID[rid] {
                    existing.date = ISO.date(row.date) ?? existing.date
                    existing.playerName = row.player_name
                    existing.battingCalories = row.batting_calories
                    existing.bowlingCalories = row.bowling_calories
                    existing.fieldingCalories = row.fielding_calories
                } else {
                    let e = CalorieEntry(id: rid, date: ISO.date(row.date) ?? .now,
                                         playerName: row.player_name,
                                         battingCalories: row.batting_calories,
                                         bowlingCalories: row.bowling_calories,
                                         fieldingCalories: row.fielding_calories)
                    self.context.insert(e)
                    byID[rid] = e
                }
            },
            deleteLocal: { rid in
                if let e = byID[rid] { self.context.delete(e); byID[rid] = nil }
            }
        )
    }

    // MARK: Completed matches

    private func syncCompletedMatches(_ userID: UUID) async throws {
        let matches = try context.fetch(FetchDescriptor<CompletedMatch>())
        var byID = Dictionary(matches.map { ($0.remoteID, $0) }, uniquingKeysWith: { a, _ in a })
        var local: [UUID: SyncMatchRow] = [:]
        for m in matches {
            local[m.remoteID] = SyncMatchRow(
                id: m.remoteID.uuidString, user_id: userID.uuidString, date: ISO.string(m.date),
                first_batting_team: m.firstBattingTeam, first_runs: m.firstRuns,
                first_wickets: m.firstWickets, first_overs: m.firstOvers,
                second_batting_team: m.secondBattingTeam, second_runs: m.secondRuns,
                second_wickets: m.secondWickets, second_overs: m.secondOvers,
                winner_name: m.winnerName, result_text: m.resultText,
                total_overs: m.totalOvers, man_of_the_match: m.manOfTheMatch, is_tie: m.isTie)
        }
        try await reconcile(
            table: "completed_matches", userID: userID, localRows: local,
            idOf: { UUID(uuidString: $0.id) },
            applyLocal: { row in
                guard let rid = UUID(uuidString: row.id) else { return }
                if byID[rid] != nil { return }   // matches are immutable snapshots
                let m = CompletedMatch(
                    date: ISO.date(row.date) ?? .now,
                    firstBattingTeam: row.first_batting_team, firstRuns: row.first_runs,
                    firstWickets: row.first_wickets, firstOvers: row.first_overs,
                    secondBattingTeam: row.second_batting_team, secondRuns: row.second_runs,
                    secondWickets: row.second_wickets, secondOvers: row.second_overs,
                    winnerName: row.winner_name, resultText: row.result_text,
                    totalOvers: row.total_overs, manOfTheMatch: row.man_of_the_match, isTie: row.is_tie)
                m.remoteID = rid
                self.context.insert(m)
                byID[rid] = m
            },
            deleteLocal: { rid in
                if let m = byID[rid] { self.context.delete(m); byID[rid] = nil }
            }
        )
    }

    // MARK: Registered players

    private func syncRegisteredPlayers(_ userID: UUID) async throws {
        let players = try context.fetch(FetchDescriptor<RegisteredPlayer>())
        var byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var local: [UUID: SyncRegisteredRow] = [:]
        for p in players {
            local[p.id] = SyncRegisteredRow(id: p.id.uuidString, user_id: userID.uuidString,
                                        first_name: p.firstName, last_name: p.lastName,
                                        phone: p.phone, email: p.email,
                                        created_at: ISO.string(p.createdAt))
        }
        try await reconcile(
            table: "registered_players", userID: userID, localRows: local,
            idOf: { UUID(uuidString: $0.id) },
            applyLocal: { row in
                guard let rid = UUID(uuidString: row.id) else { return }
                if let existing = byID[rid] {
                    existing.firstName = row.first_name
                    existing.lastName = row.last_name
                    existing.phone = row.phone
                    existing.email = row.email
                } else {
                    let p = RegisteredPlayer(id: rid, firstName: row.first_name, lastName: row.last_name,
                                             phone: row.phone, email: row.email)
                    p.createdAt = ISO.date(row.created_at) ?? .now
                    self.context.insert(p)
                    byID[rid] = p
                }
            },
            deleteLocal: { rid in
                if let p = byID[rid] { self.context.delete(p); byID[rid] = nil }
            }
        )
    }

    // MARK: Last-synced id sets (UserDefaults)

    private static let syncedTables = [
        "profiles", "saved_teams", "saved_players", "player_career_stats",
        "calorie_entries", "completed_matches", "registered_players"
    ]

    /// Clears the last-synced bookkeeping (used when switching accounts on a device).
    static func clearSyncCursors() {
        for table in syncedTables {
            UserDefaults.standard.removeObject(forKey: "sync.synced.\(table)")
        }
    }

    private func syncedKey(_ table: String) -> String { "sync.synced.\(table)" }

    private func loadSynced(_ table: String) -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: syncedKey(table)) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    private func saveSynced(_ table: String, _ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: syncedKey(table))
    }
}

// MARK: - Wire DTOs (property names mirror the Postgres columns exactly)

private struct SyncProfileRow: Codable, Sendable {
    var id: String
    var first_name: String
    var last_name: String
    var phone: String
    var email: String
    var role: String?
}

private struct SyncTeamRow: Codable, Sendable {
    var id: String
    var user_id: String
    var name: String
    var created_at: String?
}

private struct SyncPlayerRow: Codable, Sendable {
    var id: String
    var user_id: String
    var team_id: String?
    var name: String
    var role: String
    var sort_order: Int
}

private struct SyncCalorieRow: Codable, Sendable {
    var id: String
    var user_id: String
    var date: String
    var player_name: String
    var batting_calories: Double
    var bowling_calories: Double
    var fielding_calories: Double
}

private struct SyncMatchRow: Codable, Sendable {
    var id: String
    var user_id: String
    var date: String
    var first_batting_team: String
    var first_runs: Int
    var first_wickets: Int
    var first_overs: String
    var second_batting_team: String
    var second_runs: Int
    var second_wickets: Int
    var second_overs: String
    var winner_name: String
    var result_text: String
    var total_overs: Int
    var man_of_the_match: String
    var is_tie: Bool
}

private struct SyncRegisteredRow: Codable, Sendable {
    var id: String
    var user_id: String
    var first_name: String
    var last_name: String
    var phone: String
    var email: String
    var created_at: String?
}

// MARK: - ISO8601 helpers (robust to Postgres microsecond timestamps)

private enum ISO {
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

    static func string(_ date: Date) -> String { withFractional.string(from: date) }

    static func date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let d = withFractional.date(from: string) { return d }
        // Postgres returns up to 6 fractional digits; trim to 3 for the formatter.
        let trimmed = string.replacingOccurrences(
            of: #"\.(\d{3})\d+"#, with: ".$1", options: .regularExpression)
        if let d = withFractional.date(from: trimmed) { return d }
        let noFraction = string.replacingOccurrences(
            of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: noFraction)
    }
}
