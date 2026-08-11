import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Tap feedback
// Central place for the light vibration + "tick" sound played whenever the
// user taps a button or a tab. Applied app-wide via `FeedbackButtonStyle`.
enum Feedback {
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    /// A short haptic tap paired with the system keyboard "tock" tick sound.
    static func tap() {
        impact.impactOccurred()
        impact.prepare()             // keep the generator warm for the next tap
        AudioServicesPlaySystemSound(1104)   // 1104 = keyboard "Tock" tick
    }
}

// MARK: - Feedback button style
// A drop-in button style that adds a subtle press animation and fires
// `Feedback.tap()` the instant a button is pressed. Because SwiftUI propagates
// button styles through the environment, setting this once at a view hierarchy's
// root gives every descendant `Button` the same vibration + tick.
struct FeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Feedback.tap() }
            }
    }
}
