import SwiftUI
import UIKit

struct Theme {
    // Structural colors adapt to the active color scheme (driven by the theme
    // picker in SettingsView). Accent colors stay constant across both modes.
    static let bg       = Color(light: "#eef2f8", dark: "#080c14")
    static let surface1 = Color(light: "#ffffff", dark: "#0e1521")
    static let surface2 = Color(light: "#f1f4fa", dark: "#131d2e")
    static let surface3 = Color(light: "#e3e9f3", dark: "#1a2640")
    static let border   = Color(light: .black.opacity(0.08), dark: .white.opacity(0.06))
    static let border2  = Color(light: .black.opacity(0.14), dark: .white.opacity(0.12))
    static let gold     = Color(hex: "#f6c90e")
    static let gold2    = Color(hex: "#d4a60a")
    static let green    = Color(hex: "#16a34a")
    static let green2   = Color(hex: "#15803d")
    static let cyan     = Color(hex: "#06b6d4")
    static let red      = Color(hex: "#ef4444")
    static let amber    = Color(hex: "#f59e0b")
    static let purple   = Color(hex: "#a855f7")
    static let text     = Color(light: "#0f1a2e", dark: "#e8eef8")
    static let text2    = Color(light: "#52627d", dark: "#7a90b8")
    static let text3    = Color(light: "#9aa8bf", dark: "#3d5070")
    static let bat      = Color(hex: "#f97316")
    static let bowl     = Color(hex: "#38bdf8")
    static let allr     = Color(hex: "#a78bfa")
    static let wk       = Color(hex: "#fbbf24")

    static var goldGrad:  LinearGradient { LinearGradient(colors: [gold, gold2], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var greenGrad: LinearGradient { LinearGradient(colors: [green, green2], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var teamAGrad: LinearGradient { LinearGradient(colors: [Color(hex:"#064e1a"), Color(hex:"#0d6b28")], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var teamBGrad: LinearGradient { LinearGradient(colors: [Color(hex:"#0c2461"), Color(hex:"#1e3a8a")], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var bgGrad: LinearGradient {
        LinearGradient(stops: [
            .init(color: green.opacity(0.07), location: 0),
            .init(color: bg, location: 0.5),
            .init(color: cyan.opacity(0.05), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    /// Scheme-adaptive color built from two hex strings.
    init(light: String, dark: String) {
        self.init(light: Color(hex: light), dark: Color(hex: dark))
    }
    /// Scheme-adaptive color: resolves `light` in light mode, `dark` in dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,255,255,255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Reusable Components

struct CricketCard<Content: View>: View {
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface1)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }
}

struct CardHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(2).foregroundColor(Theme.text2).textCase(.uppercase)
            Spacer()
            if let t = trailing { t }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }
}

struct GoldButton: View {
    let title: String; var icon: String? = nil; var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let i = icon { Text(i) }
                Text(title).font(.system(size: 15, weight: .bold)).tracking(2).textCase(.uppercase)
            }
            .foregroundColor(Color(hex: "#0a0e1a")).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(disabled ? AnyView(Theme.surface3) : AnyView(Theme.goldGrad)).cornerRadius(14)
        }.disabled(disabled)
    }
}

struct GreenButton: View {
    let title: String; var icon: String? = nil; var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let i = icon { Text(i) }
                Text(title).font(.system(size: 15, weight: .bold)).tracking(2).textCase(.uppercase)
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(disabled ? AnyView(Theme.surface3) : AnyView(Theme.greenGrad)).cornerRadius(14)
            .shadow(color: disabled ? .clear : Theme.green.opacity(0.3), radius: 10, y: 5)
        }.disabled(disabled)
    }
}

struct RolePill: View {
    let role: PlayerRole
    var body: some View {
        Text(role.short).font(.system(size: 9, weight: .bold)).tracking(1)
            .foregroundColor(role.color).padding(.horizontal, 8).padding(.vertical, 3)
            .background(role.color.opacity(0.15)).cornerRadius(999)
    }
}

struct PlayerAvatar: View {
    let name: String; let role: PlayerRole; var size: CGFloat = 34
    var body: some View {
        Text(initials(name)).font(.system(size: size * 0.32, weight: .bold))
            .foregroundColor(role.color).frame(width: size, height: size)
            .background(role.color.opacity(0.18)).cornerRadius(size * 0.28)
    }
    func initials(_ n: String) -> String {
        String(n.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined().prefix(2))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 9, weight: .bold)).tracking(2)
            .textCase(.uppercase).foregroundColor(Theme.text3).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BadgeView: View {
    let text: String; var color: Color = Theme.gold
    var body: some View {
        Text(text).font(.system(size: 9, weight: .bold)).tracking(1)
            .foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12)).cornerRadius(6)
    }
}

struct GridTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 44
            var x: CGFloat = 0
            while x <= size.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(.white.opacity(0.012)), lineWidth: 1); x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.012)), lineWidth: 1); y += step
            }
        }
    }
}
