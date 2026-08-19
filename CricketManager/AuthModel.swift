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
        let response = try await SupabaseManager.shared.client.auth.signUp(
            email: email, password: password
        )
        guard let session = response.session else {
            // Confirmation is off, so this shouldn't happen — surface it clearly.
            throw AuthError.noSession
        }
        // Fill in the profile row the sign-up trigger created (id = the new user).
        let row = ProfileUpsert(
            id: session.user.id.uuidString,
            first_name: firstName, last_name: lastName,
            phone: phone, email: email, role: role
        )
        _ = try await SupabaseManager.shared.client
            .from("profiles").upsert(row).execute()

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
