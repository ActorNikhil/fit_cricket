import SwiftUI
import SwiftData
import PhotosUI
import Supabase

// MARK: - User Profile (SwiftData)
// The signed-in user's profile. `userID` ties it to the Supabase account so that
// when a different account signs in on the same device we can tell the profile
// belongs to someone else and reset it, rather than showing stale details.
@Model
final class UserProfile {
    var userID: String = ""     // Supabase auth user id this profile belongs to
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var email: String = ""
    var role: String = PlayerRole.bat.rawValue   // preferred playing role (BAT/BOW/AR/WK)
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date.now

    init(phone: String) {
        self.phone = phone
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    var displayName: String {
        fullName.isEmpty ? "Cricket Fan" : fullName
    }
    var initials: String {
        let f = firstName.first.map { String($0) } ?? ""
        let l = lastName.first.map { String($0) } ?? ""
        return (f + l).uppercased()
    }
}

// MARK: - Auth gate
// Decides whether to show the login flow or the main app based on the Supabase
// auth session (owned by AuthModel). While the session is being restored on
// launch we show a brief loading screen so we don't flash the login form.
struct RootAuthGate: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        switch auth.phase {
        case .loading:
            AuthLoadingView()
        case .signedOut:
            LoginView()
        case .signedIn:
            RootView()
        }
    }
}

// MARK: - Auth loading
// Shown for the moment it takes to restore a saved session at launch.
private struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#125036"), Color(hex: "#0c3122"), Color(hex: "#06120d")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ProgressView().tint(Theme.gold)
        }
    }
}

// MARK: - Login (Supabase email + password)
// Signs in against Supabase with an email and password. Creating an account is a
// separate pushed screen (SignUpView) reached via the link at the bottom. The
// session is stored by the SDK, so signing in with the same email on another
// device makes the user's synced data appear there.
struct LoginView: View {
    @Environment(AuthModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isBusy = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isBusy
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()
                ScrollView {
                    VStack(spacing: 26) {
                        header
                        form
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 70)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // Focus the email field so the keyboard is up on appear.
            try? await Task.sleep(for: .milliseconds(400))
            focusedField = .email
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            Image("LaunchLogo")
                .resizable().scaledToFit()
                .frame(width: 110, height: 110)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("Fit").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    Text("Cricket").font(.system(size: 24, weight: .bold)).foregroundColor(Theme.gold)
                }
                Text("Sign in to sync your cricket")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 18) {
            CricketCard {
                CardHeader(title: "Sign In")
                VStack(spacing: 12) {
                    fieldRow(icon: "envelope.fill", placeholder: "Email address",
                             text: $email, secure: false, keyboard: .emailAddress,
                             content: .emailAddress, field: .email)
                    fieldRow(icon: "lock.fill", placeholder: "Password (min 6 characters)",
                             text: $password, secure: true, keyboard: .default,
                             content: .password, field: .password)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
            }

            GoldButton(
                title: isBusy ? "Please wait…" : "Sign In",
                disabled: !canSubmit
            ) { submit() }

            NavigationLink {
                SignUpView()
            } label: {
                Text("New here? Create an account")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private func fieldRow(icon: String, placeholder: String, text: Binding<String>,
                          secure: Bool, keyboard: UIKeyboardType,
                          content: UITextContentType, field: Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14)).foregroundColor(Theme.gold).frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.text)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.surface2).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focusedField == field ? Theme.green : Theme.border2,
                    lineWidth: focusedField == field ? 2 : 1))
    }

    // MARK: Actions

    private func submit() {
        let cleanEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let pass = password
        errorText = nil
        isBusy = true
        focusedField = nil
        Task {
            do {
                try await auth.signIn(email: cleanEmail, password: pass)
            } catch {
                errorText = error.localizedDescription
            }
            isBusy = false
        }
    }
}

// MARK: - Auth background
// The shared gradient backdrop used by both the login and sign-up screens.
private struct AuthBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#125036"), Color(hex: "#0c3122"), Color(hex: "#06120d")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Theme.gold.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 360
            ).ignoresSafeArea()
        }
    }
}

// A styled auth text/secure field matching the login form's look.
private struct AuthFieldRow<Field: Hashable>: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default
    var content: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .never
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14)).foregroundColor(Theme.gold).frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused(focus, equals: field)
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.surface2).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focus.wrappedValue == field ? Theme.green : Theme.border2,
                    lineWidth: focus.wrappedValue == field ? 2 : 1))
    }
}

// MARK: - Sign Up (separate page)
// Collects the mandatory player details (name, phone, email, password) plus a
// playing role, creates the Supabase account, and writes the full profile row.
// On success the auth session flips to signed-in and RootAuthGate swaps in the
// main app, so this pushed screen is torn down automatically.
struct SignUpView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role: PlayerRole = .bat
    @State private var errorText: String?
    @State private var isBusy = false
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName, phone, email, password }

    // Every field is mandatory before the account can be created.
    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && phone.trimmingCharacters(in: .whitespaces).count >= 7
            && email.contains("@")
            && password.count >= 6
            && !isBusy
    }

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView {
                VStack(spacing: 20) {
                    backBar
                    header
                    form
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Focus the first field so the keyboard is up on appear.
            try? await Task.sleep(for: .milliseconds(400))
            focusedField = .firstName
        }
    }

    // MARK: Pieces

    private var backBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Sign In").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Theme.gold)
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Create your account")
                .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            Text("Set up your player profile to get started")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(spacing: 18) {
            CricketCard {
                CardHeader(title: "Create Account")
                VStack(spacing: 12) {
                    AuthFieldRow(icon: "person.fill", placeholder: "First name",
                                 text: $firstName, content: .givenName, capitalization: .words,
                                 focus: $focusedField, field: .firstName)
                    AuthFieldRow(icon: "person.fill", placeholder: "Last name",
                                 text: $lastName, content: .familyName, capitalization: .words,
                                 focus: $focusedField, field: .lastName)
                    AuthFieldRow(icon: "phone.fill", placeholder: "Phone number",
                                 text: $phone, keyboard: .phonePad, content: .telephoneNumber,
                                 focus: $focusedField, field: .phone)
                    AuthFieldRow(icon: "envelope.fill", placeholder: "Email address",
                                 text: $email, keyboard: .emailAddress, content: .emailAddress,
                                 focus: $focusedField, field: .email)
                    AuthFieldRow(icon: "lock.fill", placeholder: "Password (min 6 characters)",
                                 text: $password, secure: true, content: .newPassword,
                                 focus: $focusedField, field: .password)

                    roleSelector

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
            }

            GoldButton(
                title: isBusy ? "Please wait…" : "Create Account",
                disabled: !canSubmit
            ) { submit() }
        }
    }

    private var roleSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Playing role")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(PlayerRole.allCases) { r in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { role = r } } label: {
                        VStack(spacing: 3) {
                            Text(r.icon).font(.system(size: 16))
                            Text(r.short).font(.system(size: 9, weight: .bold)).tracking(1)
                        }
                        .foregroundColor(role == r ? r.color : Theme.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(role == r ? r.color.opacity(0.15) : Theme.surface3)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(role == r ? r.color : Color.clear, lineWidth: 1.5))
                    }
                }
            }
        }
    }

    // MARK: Action

    private func submit() {
        errorText = nil
        isBusy = true
        let fn = firstName.trimmingCharacters(in: .whitespaces)
        let ln = lastName.trimmingCharacters(in: .whitespaces)
        let ph = phone.trimmingCharacters(in: .whitespaces)
        let em = email.trimmingCharacters(in: .whitespaces).lowercased()
        let pass = password
        let selectedRole = role.rawValue
        Task {
            do {
                try await auth.signUp(firstName: fn, lastName: ln, phone: ph,
                                      email: em, password: pass, role: selectedRole)
                // Success → RootAuthGate switches to the main app automatically.
            } catch {
                errorText = error.localizedDescription
                isBusy = false
            }
        }
    }
}

// MARK: - Home (Home tab)
// The landing screen for the "Home" tab, following a dashboard layout: a title
// bar with quick actions, a highlighted feature card, a "You" row that opens the
// profile, and a list of the user's recent matches. Tapping the profile icon
// slides in the full profile details/editor (ProfileView), reusing the same
// state-driven push + back bar pattern as MoreView to keep the dark theme.
struct HomeView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Query private var profiles: [UserProfile]
    @Query(sort: \CompletedMatch.date, order: .reverse) private var matches: [CompletedMatch]
    @State private var showDetails = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if showDetails {
                detailsScreen
            } else {
                home
            }
        }
    }

    // MARK: Home dashboard
    private var home: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                featureCard
                youRow
                matchesSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // Title bar: "Home" with quick-action icons on the right.
    private var header: some View {
        HStack(alignment: .center) {
            Text("Home").font(.system(size: 30, weight: .black)).foregroundColor(Theme.text)
            Spacer()
            HStack(spacing: 12) {
                circleIcon("bubble.left.and.bubble.right.fill")
                circleIcon("bell.fill")
                Button { appVM.selectedTab = 1 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.green).clipShape(Circle())
                }
            }
        }
        .padding(.top, 4)
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text2)
            .frame(width: 40, height: 40)
            .background(Theme.surface2).clipShape(Circle())
            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
    }

    // Highlighted feature card (banner-style call to action).
    private var featureCard: some View {
        VStack(spacing: 10) {
            Text("Where do you score most?")
                .font(.system(size: 17, weight: .bold)).foregroundColor(Theme.text)
            Text("Track your batting, bowling & calories")
                .font(.system(size: 13)).foregroundColor(Theme.text3)
            Button { appVM.selectedTab = 1 } label: {
                Text("Start a match")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Theme.green).clipShape(Capsule())
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 16)
        .background(Theme.surface1).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }

    // "You" row: tappable profile icon + a prompt bubble.
    private var youRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDetails = true }
            } label: {
                VStack(spacing: 6) {
                    ZStack(alignment: .bottomTrailing) {
                        profileAvatar(size: 60)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18)).foregroundColor(Theme.green)
                            .background(Circle().fill(Theme.bg))
                    }
                    Text("You").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text2)
                }
            }
            .buttonStyle(FeedbackButtonStyle())

            Text("Tap your photo to view and edit your profile details.")
                .font(.system(size: 13)).foregroundColor(Theme.text3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }

    // MARK: Matches of your interest
    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Matches of your interest")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                Button { appVM.selectedTab = 3 } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text3)
                }
            }

            if matches.isEmpty {
                VStack(spacing: 8) {
                    Text("🏏").font(.system(size: 36))
                    Text("No matches yet")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text)
                    Text("Finish a match and it will show up here.")
                        .font(.system(size: 12)).foregroundColor(Theme.text3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
                .background(Theme.surface1).cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
            } else {
                ForEach(matches.prefix(3)) { match in
                    HomeMatchCard(match: match)
                }
            }
        }
    }

    // MARK: Profile details (pushed screen)
    private var detailsScreen: some View {
        VStack(spacing: 0) {
            // Back bar returning to the Home dashboard.
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showDetails = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        Text("Home").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(Theme.gold)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 2)

            ProfileView()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // Circular profile icon: the user's photo if set, otherwise their initials.
    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        let image = profile?.photoData.flatMap { UIImage(data: $0) }
        let initials = (profile?.initials.isEmpty == false) ? (profile?.initials ?? "?") : "?"
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Circle().fill(Theme.gold.opacity(0.15)).frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.34, weight: .bold)).foregroundColor(Theme.gold)
                    )
            }
            Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 2).frame(width: size, height: size)
        }
    }
}

// MARK: - Home match card
// A compact recent-match summary shown on the Home tab, styled after the
// "Matches of your interest" cards: teams, both innings' scores, and the result.
private struct HomeMatchCard: View {
    let match: CompletedMatch

    private var dateText: String { match.date.formatted(date: .abbreviated, time: .omitted) }

    var body: some View {
        CricketCard {
            VStack(alignment: .leading, spacing: 0) {
                // Title row: teams + result badge
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12)).foregroundColor(Theme.gold)
                    Text("\(match.firstBattingTeam) vs \(match.secondBattingTeam)")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer()
                    Text(match.isTie ? "Tie" : "Result")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.green).clipShape(Capsule())
                }
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text("\(dateText) · \(match.totalOvers) ov")
                        .font(.system(size: 11)).foregroundColor(Theme.text3)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.bottom, 10)

                Divider().background(Theme.border)

                // Scores
                VStack(spacing: 8) {
                    scoreRow(team: match.firstBattingTeam,
                             score: "\(match.firstRuns)/\(match.firstWickets)",
                             overs: match.firstOvers)
                    scoreRow(team: match.secondBattingTeam,
                             score: "\(match.secondRuns)/\(match.secondWickets)",
                             overs: match.secondOvers)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)

                Divider().background(Theme.border)

                Text(match.resultText.isEmpty ? "Match completed" : match.resultText)
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.gold)
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
    }

    private func scoreRow(team: String, score: String, overs: String) -> some View {
        HStack {
            Text(team.isEmpty ? "—" : team)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer()
            HStack(alignment: .bottom, spacing: 6) {
                Text(score).font(.system(size: 15, weight: .black)).foregroundColor(Theme.text)
                Text(overs.isEmpty ? "" : "(\(overs) Ov)")
                    .font(.system(size: 11)).foregroundColor(Theme.text3)
            }
        }
    }
}

// MARK: - Profile
// Shows and edits the owner's profile. Editing writes straight through to the
// SwiftData model via @Bindable. Includes a Log Out control that returns to the
// login gate (the profile itself is kept, so signing back in restores it).
struct ProfileView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(title: "Profile", subtitle: "Your account details").padding(.top, 8)

                if let profile = profiles.first {
                    ProfileEditorView(profile: profile)
                } else {
                    // Shouldn't normally happen (login creates one), but keeps the
                    // view robust if the store was cleared out from under us.
                    Text("No profile found.")
                        .font(.system(size: 14)).foregroundColor(Theme.text3)
                        .padding(.vertical, 40)
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Profile editor
// Editing form for the owner's profile. Edits are kept in local draft state and
// only written to the SwiftData model when the user taps Save, so nothing is
// persisted until they confirm.
private struct ProfileEditorView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AuthModel.self) private var auth

    // Draft copies of the editable fields; committed to the model on Save.
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var didSave = false
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName, email }

    // Whether the draft differs from what's currently stored.
    private var hasChanges: Bool {
        firstName != profile.firstName
        || lastName != profile.lastName
        || email != profile.email
        || photoData != profile.photoData
    }

    var body: some View {
        let previewImage = photoData.flatMap { UIImage(data: $0) }
        let trimmed = (firstName.first.map { String($0) } ?? "") + (lastName.first.map { String($0) } ?? "")
        let avatarInitials = trimmed.isEmpty ? "?" : trimmed.uppercased()

        VStack(spacing: 16) {
            // Avatar + photo picker
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: 8) {
                    ZStack {
                        if let previewImage {
                            Image(uiImage: previewImage).resizable().scaledToFill()
                                .frame(width: 104, height: 104).clipShape(Circle())
                        } else {
                            Circle().fill(Theme.gold.opacity(0.15)).frame(width: 104, height: 104)
                                .overlay(
                                    Text(avatarInitials)
                                        .font(.system(size: 34, weight: .bold)).foregroundColor(Theme.gold)
                                )
                        }
                        Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 2).frame(width: 104, height: 104)
                    }
                    Text(previewImage == nil ? "Add Photo" : "Change Photo")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.gold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }

            CricketCard {
                CardHeader(title: "Name")
                VStack(spacing: 10) {
                    profileField("First name", text: $firstName, icon: "person.fill", field: .firstName)
                    profileField("Last name", text: $lastName, icon: "person.fill", field: .lastName)
                }
                .padding(14)
            }

            CricketCard {
                CardHeader(title: "Contact")
                VStack(spacing: 10) {
                    // Phone is the login identity — shown read-only here.
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill").font(.system(size: 13)).foregroundColor(Theme.text3).frame(width: 18)
                        Text(profile.phone.isEmpty ? "—" : profile.phone)
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text2)
                        Spacer()
                        BadgeView(text: "Login")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(Theme.surface2).cornerRadius(10)

                    profileField("Email address", text: $email, icon: "envelope.fill", field: .email, keyboard: .emailAddress)
                }
                .padding(14)
            }

            GoldButton(title: didSave ? "Saved ✓" : "Save", disabled: !hasChanges) { save() }
                .padding(.top, 4)
        }
        .onAppear(perform: loadDraft)
        // Fetch the latest details straight from the database each time the page opens.
        .task { await fetchFromDatabase() }
        // Decode the picked image off the model, then mirror it into the draft —
        // this keeps the SwiftData model off the concurrent task entirely.
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    // Load the stored values into the draft when the editor appears.
    private func loadDraft() {
        firstName = profile.firstName
        lastName = profile.lastName
        email = profile.email
        photoData = profile.photoData
    }

    // Pull the account details (name, phone, email) from the Supabase `profiles`
    // row for the signed-in user, so the page always shows the database's copy.
    // The values are mirrored into the local model (and the editable drafts) so
    // the read-only phone updates and everything stays in sync offline.
    private func fetchFromDatabase() async {
        guard let uid = auth.userID?.uuidString else { return }
        do {
            let rows: [RemoteProfileRow] = try await SupabaseManager.shared.client
                .from("profiles")
                .select("first_name,last_name,phone,email")
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value
            guard let r = rows.first else { return }

            // Persist to the local model (source of truth for the read-only phone).
            profile.firstName = r.first_name
            profile.lastName = r.last_name
            profile.phone = r.phone
            profile.email = r.email
            try? context.save()

            // Reflect into the editable drafts (only if the user hasn't started editing).
            if !hasChanges {
                firstName = r.first_name
                lastName = r.last_name
                email = r.email
            }
        } catch {
            #if DEBUG
            print("[Profile] database fetch error: \(error)")
            #endif
        }
    }

    // Commit the draft to the SwiftData model.
    private func save() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.lastName = lastName.trimmingCharacters(in: .whitespaces)
        profile.email = email.trimmingCharacters(in: .whitespaces)
        profile.photoData = photoData
        try? context.save()

        withAnimation { didSave = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation { didSave = false }
        }
    }

    // Styled text field matching the app's editor fields.
    @ViewBuilder
    private func profileField(_ placeholder: String, text: Binding<String>, icon: String,
                              field: Field, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Theme.text3).frame(width: 18)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .font(.system(size: 15)).foregroundColor(Theme.text)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Theme.surface2).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(focusedField == field ? Theme.green : Theme.border,
                    lineWidth: focusedField == field ? 2 : 1))
    }
}

// The account-detail columns read back from the Supabase `profiles` table.
private struct RemoteProfileRow: Decodable {
    let first_name: String
    let last_name: String
    let phone: String
    let email: String
}
