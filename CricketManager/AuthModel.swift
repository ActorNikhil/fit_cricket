import SwiftUI
import Supabase

// MARK: - AuthModel
// Owns the Supabase auth session and exposes a simple signed-in / signed-out
// state to the UI. Login uses email + password (email confirmation is turned off
// on the backend, so sign-up returns a usable session immediately). The session
// is restored on launch by observing `authStateChanges`, whose first event
// (`initialSession`) carries any session the SDK loaded from the Keychain.
@MainActor
@Observable
final class AuthModel {
    enum Phase {
        case loading    // still determining whether a session exists (launch)
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .loading
    private(set) var userID: UUID?
    private(set) var email: String?

    // Profile details entered during sign-up, held briefly so the signed-in UI
    // can seed the local profile (the offline-first source of truth) as soon as
    // it appears. The sync engine then pushes them up to Supabase reliably —
    // unlike the direct post-sign-up write, whose auth token may not yet be
    // attached, silently leaving the trigger-created row's name/phone empty.
    struct PendingSignUp {
        var firstName: String
        var lastName: String
        var phone: String
        var role: String
    }
    private(set) var pendingSignUp: PendingSignUp?

    /// Returns the pending sign-up details once, clearing them so they're only
    /// applied to the local profile a single time.
    func consumePendingSignUp() -> PendingSignUp? {
        defer { pendingSignUp = nil }
        return pendingSignUp
    }

    private var observeTask: Task<Void, Never>?

    var isSignedIn: Bool { phase == .signedIn }

    init() {
        observeAuthChanges()
    }

    // MARK: Session observation

    private func observeAuthChanges() {
        observeTask = Task { [weak self] in
            for await change in SupabaseManager.shared.client.auth.authStateChanges {
                guard let self, !Task.isCancelled else { break }
                switch change.event {
                case .initialSession:
                    if let session = change.session, !session.isExpired {
                        self.apply(session)
                    } else {
                        self.phase = .signedOut
                    }
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let session = change.session { self.apply(session) }
                case .signedOut:
                    self.clear()
                default:
                    break
                }
            }
        }
    }

    private func apply(_ session: Session) {
        userID = session.user.id
        email = session.user.email
        phase = .signedIn
    }

    private func clear() {
        userID = nil
        email = nil
        phase = .signedOut
    }

    // MARK: Actions

    /// Creates a new account with the player's full profile. With email
    /// confirmation disabled a session is returned right away, so we immediately
    /// write the profile row (name, phone, role) to Supabase while authenticated;
    /// the device then pulls those details down via the sync engine.
    func signUp(firstName: String, lastName: String, phone: String,
                email: String, password: String, role: String) async throws {
        // Stash the entered details BEFORE creating the account. `auth.signUp`
        // below emits a `.signedIn` event from *inside* the call, which flips the
        // UI to signed-in and runs `ensureProfile()` — that seeds the local
        // profile from `pendingSignUp`. Setting it first guarantees the name/phone
        // are already available whenever `ensureProfile()` runs, instead of racing
        // the assignment (which previously left a blank local profile, so the sync
        // engine pushed empty name/phone up and the entered details were lost).
        pendingSignUp = PendingSignUp(firstName: firstName, lastName: lastName,
                                      phone: phone, role: role)
        #if DEBUG
        print("[SignUp] pendingSignUp set: \(firstName) \(lastName) phone=\(phone)")
        print("[SignUp] starting for \(email)")
        #endif
        let response: AuthResponse
        do {
            response = try await SupabaseManager.shared.client.auth.signUp(
                email: email, password: password
            )
        } catch {
            pendingSignUp = nil   // account wasn't created — don't seed a stale profile
            throw error
        }
        guard let session = response.session else {
            // Confirmation is off, so this shouldn't happen — surface it clearly.
            pendingSignUp = nil
            #if DEBUG
            print("[SignUp] no session returned — aborting")
            #endif
            throw AuthError.noSession
        }
        #if DEBUG
        print("[SignUp] session ok, user=\(session.user.id.uuidString)")
        #endif
        // Best-effort direct write of the profile row the sign-up trigger created
        // (id = the new user). The auth token may not be attached yet, so a failure
        // here is non-fatal: the local profile is seeded from `pendingSignUp` and
        // the sync engine reliably pushes it up afterwards.
        let row = ProfileUpsert(
            id: session.user.id.uuidString,
            first_name: firstName, last_name: lastName,
            phone: phone, email: email, role: role
        )
        do {
            _ = try await SupabaseManager.shared.client
                .from("profiles").upsert(row).execute()
        } catch {
            #if DEBUG
            print("[SignUp] direct profile upsert failed (will sync later): \(error)")
            #endif
        }

        apply(session)
    }

    /// Signs an existing user in with email + password.
    func signIn(email: String, password: String) async throws {
        let session = try await SupabaseManager.shared.client.auth.signIn(
            email: email, password: password
        )
        apply(session)
    }

    func signOut() async {
        try? await SupabaseManager.shared.client.auth.signOut()
        clear()
    }
}

// MARK: - Supabase wire types

// Profile row written at sign-up (column names mirror the `profiles` table).
private struct ProfileUpsert: Encodable {
    var id: String
    var first_name: String
    var last_name: String
    var phone: String
    var email: String
    var role: String
}

enum AuthError: LocalizedError {
    case noSession

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "Account created, but no session was returned. Please sign in."
        }
    }
}
