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
// Editing form for the owner's profile. Split into its own view so the SwiftData
// model can be bound with @Bindable (edits write straight through to the store)
// without capturing a local var inside SwiftUI's escaping view builders.
private struct ProfileEditorView: View {
    @Bindable var profile: UserProfile
    @AppStorage(loggedInPhoneStorageKey) private var loggedInPhone = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedPhotoData: Data?

    var body: some View {
        let previewImage = profile.photoData.flatMap { UIImage(data: $0) }
        let avatarInitials = profile.initials.isEmpty ? "?" : profile.initials

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
                    profileField("First name", text: $profile.firstName, icon: "person.fill")
                    profileField("Last name", text: $profile.lastName, icon: "person.fill")
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

                    profileField("Email address", text: $profile.email, icon: "envelope.fill", keyboard: .emailAddress)
                }
                .padding(14)
            }

            Button(role: .destructive) { loggedInPhone = "" } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Log Out").font(.system(size: 15, weight: .bold)).tracking(1)
                }
                .foregroundColor(Theme.red).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.red.opacity(0.12)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.red.opacity(0.3), lineWidth: 1))
            }
            .padding(.top, 4)
        }
        // Decode the picked image off the model, then mirror it in synchronously —
        // this keeps the SwiftData model off the concurrent task entirely.
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    pickedPhotoData = data
                }
            }
        }
        .onChange(of: pickedPhotoData) { _, newData in
            if let newData { profile.photoData = newData }
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
