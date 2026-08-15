import SwiftUI
import SwiftData
import PhotosUI

// MARK: - User Profile (SwiftData)
// The single owner of this app. Created the first time the user logs in with a
// phone number, then filled out (name / photo / email) from the Profile screen.
// This is a single-user app, so there is only ever one UserProfile in the store.
@Model
final class UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var email: String = ""
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

// MARK: - Storage key
// The phone number of the currently logged-in user. Empty means logged out and
// drives the login gate below. Kept in @AppStorage so it survives launches.
let loggedInPhoneStorageKey = "loggedInUserPhone"

// MARK: - Auth gate
// Decides whether to show the login flow or the main app. Because this is a
// single-user app, being "logged in" simply means a phone number is on file.
struct RootAuthGate: View {
    @AppStorage(loggedInPhoneStorageKey) private var loggedInPhone = ""

    var body: some View {
        if loggedInPhone.isEmpty {
            LoginView()
        } else {
            RootView()
        }
    }
}

// MARK: - Login (local phone-number flow)
// A backend-free phone login: the user enters a number, a 6-digit code is
// generated on-device (shown as a demo hint so the OTP flow works offline), and
// entering it logs the user in — creating the single UserProfile if needed.
struct LoginView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage(loggedInPhoneStorageKey) private var loggedInPhone = ""

    @State private var phone = ""
    @State private var codeSent = false
    @State private var generatedCode = ""
    @State private var enteredCode = ""
    @State private var errorText: String?
    @FocusState private var fieldFocused: Bool

    private var normalizedPhone: String { phone.filter { $0.isNumber } }
    private var canContinue: Bool { normalizedPhone.count >= 7 }
    private var canVerify: Bool { enteredCode.filter(\.isNumber).count == 6 }

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

            ScrollView {
                VStack(spacing: 26) {
                    header

                    if codeSent {
                        codeStep
                    } else {
                        phoneStep
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)
                .padding(.bottom, 40)
            }
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
                Text(codeSent ? "Enter the 6-digit code" : "Sign in with your phone")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: Phone step

    private var phoneStep: some View {
        VStack(spacing: 18) {
            CricketCard {
                CardHeader(title: "Phone Number")
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14)).foregroundColor(Theme.gold).frame(width: 20)
                        TextField("Enter phone number", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .focused($fieldFocused)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .background(Theme.surface2).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border2, lineWidth: 1))

                    Text("We'll generate a verification code for this device. No SMS is sent.")
                        .font(.system(size: 11)).foregroundColor(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }

            GoldButton(title: "Continue", disabled: !canContinue) { sendCode() }
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: Code step

    private var codeStep: some View {
        VStack(spacing: 18) {
            CricketCard {
                CardHeader(title: "Verification Code")
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14)).foregroundColor(Theme.gold).frame(width: 20)
                        TextField("6-digit code", text: $enteredCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(size: 20, weight: .bold)).tracking(6)
                            .foregroundColor(Theme.text)
                            .focused($fieldFocused)
                            .onChange(of: enteredCode) { _, _ in errorText = nil }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .background(Theme.surface2).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border2, lineWidth: 1))

                    // Demo hint — stands in for the SMS a real backend would send.
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill").font(.system(size: 11)).foregroundColor(Theme.gold)
                        Text("Demo code: \(generatedCode)")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Code sent to \(normalizedPhone)")
                        .font(.system(size: 11)).foregroundColor(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }

            GoldButton(title: "Verify & Continue", disabled: !canVerify) { verify() }

            Button {
                withAnimation { codeSent = false }
            } label: {
                Text("Change phone number")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: Actions

    private func sendCode() {
        generatedCode = String(format: "%06d", Int.random(in: 0...999_999))
        enteredCode = ""
        errorText = nil
        fieldFocused = false
        withAnimation { codeSent = true }
    }

    private func verify() {
        guard enteredCode.filter(\.isNumber) == generatedCode else {
            errorText = "Incorrect code. Please try again."
            return
        }
        // Single-user app: reuse the existing profile if there is one, otherwise
        // create it. Either way, record the phone the user signed in with.
        if let existing = profiles.first {
            existing.phone = normalizedPhone
        } else {
            context.insert(UserProfile(phone: normalizedPhone))
        }
        loggedInPhone = normalizedPhone
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

    // Draft copies of the editable fields; committed to the model on Save.
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var didSave = false

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
                    profileField("First name", text: $firstName, icon: "person.fill")
                    profileField("Last name", text: $lastName, icon: "person.fill")
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

                    profileField("Email address", text: $email, icon: "envelope.fill", keyboard: .emailAddress)
                }
                .padding(14)
            }

            GoldButton(title: didSave ? "Saved ✓" : "Save", disabled: !hasChanges) { save() }
                .padding(.top, 4)
        }
        .onAppear(perform: loadDraft)
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
                              keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Theme.text3).frame(width: 18)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .font(.system(size: 15)).foregroundColor(Theme.text)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Theme.surface2).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
