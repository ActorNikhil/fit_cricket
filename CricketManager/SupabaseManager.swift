import Foundation
import Supabase

// MARK: - Supabase configuration
// The project URL and the *publishable* client key. The publishable key is
// designed to ship inside client apps (it carries the same low privileges as the
// old anon key) — Row-Level Security on the backend is what actually protects the
// data, so it is safe to keep here.
enum SupabaseConfig {
    static let url = URL(string: "https://wqndwyrxvoqbvqunvbtp.supabase.co")!
    static let publishableKey = "sb_publishable_NvQkxKgYdz8g3_4I4RZoOA_hk_9wDOa"
}

// MARK: - Supabase client
// Single shared entry point to Supabase (auth, database, storage, realtime).
// The SDK persists the auth session in the Keychain automatically, so the user
// stays signed in across launches.
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }
}
