import SwiftUI

// MARK: - Confetti Particle
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var speedY: CGFloat
    var driftX: CGFloat
    var rotation: Double
    var rotationSpeed: Double
    var shape: Int // 0=circle 1=rect 2=triangle
}

@MainActor
class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var animationTask: Task<Void, Never>?
    private let colors: [Color] = [
        Color(hex:"#f6c90e"), Color(hex:"#16a34a"), Color(hex:"#06b6d4"),
        Color(hex:"#a855f7"), Color(hex:"#ef4444"), Color(hex:"#f97316"),
        Color(hex:"#ffffff"), Color(hex:"#38bdf8")
    ]
    func launch(width: CGFloat) {
        particles = (0..<90).map { _ in
            Particle(x: CGFloat.random(in: 0...width), y: CGFloat.random(in: -80...(-5)),
                     color: colors.randomElement()!, size: CGFloat.random(in: 5...13),
                     speedY: CGFloat.random(in: 2.5...6.5), driftX: CGFloat.random(in: -1.2...1.2),
                     rotation: Double.random(in: 0...360), rotationSpeed: Double.random(in: -6...6), shape: Int.random(in: 0...2))
        }
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 16_000_000)
                if Task.isCancelled { return }
                guard let self, !self.particles.isEmpty else { return }
                for i in self.particles.indices {
                    self.particles[i].y += self.particles[i].speedY
                    self.particles[i].x += self.particles[i].driftX
                    self.particles[i].rotation += self.particles[i].rotationSpeed
                }
                self.particles.removeAll { $0.y > 950 }
            }
        }
    }
}

struct ParticleLayer: View {
    @ObservedObject var sys: ParticleSystem
    var body: some View {
        Canvas { ctx, _ in
            for p in sys.particles {
                let fade = p.y > 750 ? 1.0 - (p.y - 750) / 120 : 1.0
                ctx.opacity = max(0, fade)
                ctx.translateBy(x: p.x, y: p.y)
                ctx.rotate(by: .degrees(p.rotation))
                let rect = CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size)
                switch p.shape {
                case 0:
                    ctx.fill(Path(ellipseIn: rect), with: .color(p.color))
                case 1:
                    ctx.fill(Path(rect), with: .color(p.color))
                default:
                    var tp = Path()
                    tp.move(to: CGPoint(x: 0, y: -p.size/2))
                    tp.addLine(to: CGPoint(x: p.size/2, y: p.size/2))
                    tp.addLine(to: CGPoint(x: -p.size/2, y: p.size/2))
                    tp.closeSubpath()
                    ctx.fill(tp, with: .color(p.color))
                }
                ctx.translateBy(x: -p.x, y: -p.y)
                ctx.rotate(by: .degrees(-p.rotation))
                ctx.opacity = 1
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Main Result View
struct MatchResultView: View {
    @ObservedObject var vm: ScoringViewModel
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var confetti = ParticleSystem()
    @State private var showScorecard = false

    // Entry animations
    @State private var trophyS: CGFloat = 0.1
    @State private var trophyY: CGFloat = 30
    @State private var glow: Bool = false
    @State private var h1: Double = 0
    @State private var h2: Double = 0
    @State private var h3: Double = 0
    @State private var h4: Double = 0
    @State private var h5: Double = 0

    private var awards: MatchAwards { vm.computeAwards() }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // BG
                Color(hex: "#060a10").ignoresSafeArea()
                bgGlow.ignoresSafeArea()
                bgGrid.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                            .opacity(h1)
                        scoreBlock
                            .padding(.horizontal, 18).padding(.top, 22).opacity(h2)
                        motmCard
                            .padding(.horizontal, 18).padding(.top, 14).opacity(h3)
                        HStack(spacing: 10) {
                            batCard; bowlCard
                        }
                        .padding(.horizontal, 18).padding(.top, 10).opacity(h4)
                        if !awards.keyMoments.isEmpty {
                            momentsCard
                                .padding(.horizontal, 18).padding(.top, 10).opacity(h4)
                        }
                        statsStrip
                            .padding(.horizontal, 18).padding(.top, 10).opacity(h4)
                        btns
                            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 50).opacity(h5)
                    }
                }

                // Confetti on top
                ParticleLayer(sys: confetti)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            vm.recordCareerStats(into: modelContext)
            vm.recordCompletedMatch(into: modelContext)
            confetti.launch(width: UIScreen.main.bounds.width)
            animate()
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardSheet(vm: vm).presentationDetents([.large])
        }
    }

    // MARK: Backgrounds
    var bgGlow: some View {
        ZStack {
            RadialGradient(colors:[Color(hex:"#f6c90e").opacity(0.09), .clear], center:.top, startRadius:0, endRadius:280)
            RadialGradient(colors:[Color(hex:"#16a34a").opacity(0.06), .clear], center:.bottomLeading, startRadius:0, endRadius:320)
            RadialGradient(colors:[Color(hex:"#06b6d4").opacity(0.05), .clear], center:.bottomTrailing, startRadius:0, endRadius:280)
        }
    }
    var bgGrid: some View {
        Canvas { c,s in
            let st: CGFloat = 44
            for x in stride(from:CGFloat(0), through:s.width, by:st) {
                var p = Path(); p.move(to:CGPoint(x:x,y:0)); p.addLine(to:CGPoint(x:x,y:s.height))
                c.stroke(p, with:.color(.white.opacity(0.011)), lineWidth:1)
            }
            for y in stride(from:CGFloat(0), through:s.height, by:st) {
                var p = Path(); p.move(to:CGPoint(x:0,y:y)); p.addLine(to:CGPoint(x:s.width,y:y))
                c.stroke(p, with:.color(.white.opacity(0.011)), lineWidth:1)
            }
        }
    }

    // MARK: Hero
    var heroSection: some View {
        VStack(spacing: 14) {
            // Trophy with rings
            ZStack {
                Circle()
                    .stroke(Color(hex:"#f6c90e").opacity(glow ? 0.18 : 0.06), lineWidth: glow ? 22 : 14)
                    .frame(width: 150, height: 150)
                    .animation(.easeInOut(duration:2.4).repeatForever(autoreverses:true), value:glow)
                Circle()
                    .stroke(Color(hex:"#f6c90e").opacity(glow ? 0.07 : 0.02), lineWidth: 40)
                    .frame(width: 190, height: 190)
                    .animation(.easeInOut(duration:3).repeatForever(autoreverses:true), value:glow)
                Text("🏆")
                    .font(.system(size: 72))
                    .scaleEffect(trophyS)
                    .offset(y: trophyY)
            }
            .frame(height: 200)
            .padding(.top, 44)

            // Headline
            VStack(spacing: 6) {
                Text("Match Over")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(5)
                    .textCase(.uppercase)
                    .foregroundColor(Color(hex:"#3d5570"))
                Text(awards.winMargin.winnerName)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                // Win pill
                Text(awards.winMargin.marginText)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex:"#f6c90e"))
                    .padding(.horizontal, 22).padding(.vertical, 9)
                    .background(Color(hex:"#f6c90e").opacity(0.11))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex:"#f6c90e").opacity(0.28), lineWidth:1))
            }
        }
    }

    // MARK: Score block
    var scoreBlock: some View {
        let i1 = vm.match.innings1, i2 = vm.match.innings2
        return ZStack {
            RoundedRectangle(cornerRadius:20).fill(Color(hex:"#0c1624"))
            RoundedRectangle(cornerRadius:20).stroke(Color.white.opacity(0.07), lineWidth:1)
            HStack(spacing:0) {
                inningsCol(name: i1.battingTeam.name, runs: i1.runs, wkts: i1.wickets, overs: i1.oversDisplay, accent: Color(hex:"#4ade80"))
                VStack(spacing:8) {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(width:1, height:22)
                    Text("VS").font(.system(size:10,weight:.black)).tracking(2).foregroundColor(Color(hex:"#f6c90e"))
                    Rectangle().fill(Color.white.opacity(0.07)).frame(width:1, height:22)
                }
                if let i2 { inningsCol(name: i2.battingTeam.name, runs: i2.runs, wkts: i2.wickets, overs: i2.oversDisplay, accent: Color(hex:"#22d3ee")) }
            }
        }
    }
    func inningsCol(name:String, runs:Int, wkts:Int, overs:String, accent:Color) -> some View {
        VStack(spacing:4) {
            Text(name).font(.system(size:11,weight:.bold)).foregroundColor(accent).lineLimit(1).minimumScaleFactor(0.7)
            HStack(alignment:.bottom, spacing:3) {
                Text("\(runs)").font(.system(size:38,weight:.black)).foregroundColor(.white).lineLimit(1)
                Text("/\(wkts)").font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:"#ef4444")).padding(.bottom,5)
            }
            Text("(\(overs) ov)").font(.system(size:11)).foregroundColor(Color(hex:"#3d5070"))
        }
        .frame(maxWidth:.infinity).padding(.vertical,18)
    }

    // MARK: MoTM
    var motmCard: some View {
        let a = awards.manOfTheMatch
        return ZStack {
            RoundedRectangle(cornerRadius:22)
                .fill(Color(hex:"#0c1624"))
            // Gold border with gradient
            RoundedRectangle(cornerRadius:22)
                .stroke(LinearGradient(colors:[Color(hex:"#f6c90e").opacity(0.7), Color(hex:"#f6c90e").opacity(0.15), Color(hex:"#d4a60a").opacity(0.5)], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:1.5)
            VStack(spacing:0) {
                // Header
                HStack(spacing:9) {
                    ZStack {
                        Circle().fill(Color(hex:"#f6c90e").opacity(0.18)).frame(width:28,height:28)
                        Image(systemName:"star.fill").font(.system(size:12)).foregroundColor(Color(hex:"#f6c90e"))
                    }
                    Text("Man of the Match")
                        .font(.system(size:11,weight:.bold)).tracking(2.5).textCase(.uppercase)
                        .foregroundColor(Color(hex:"#f6c90e"))
                    Spacer()
                    Text("MVP")
                        .font(.system(size:9,weight:.black)).tracking(2)
                        .foregroundColor(Color(hex:"#b8922a"))
                        .padding(.horizontal,9).padding(.vertical,4)
                        .background(Color(hex:"#f6c90e").opacity(0.13))
                        .clipShape(Capsule())
                }
                .padding(.horizontal,18).padding(.vertical,13)
                .background(LinearGradient(colors:[Color(hex:"#f6c90e").opacity(0.09),.clear], startPoint:.leading, endPoint:.trailing))

                Divider().background(Color(hex:"#f6c90e").opacity(0.18))

                // Player row
                HStack(spacing:16) {
                    // Avatar with gold ring
                    ZStack {
                        Circle().stroke(LinearGradient(colors:[Color(hex:"#f6c90e"),Color(hex:"#d4a60a")], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:2.5).frame(width:64,height:64)
                        Circle().fill(a.player.role.color.opacity(0.18)).frame(width:56,height:56)
                        Text(ini2(a.player.name)).font(.system(size:17,weight:.black)).foregroundColor(a.player.role.color)
                    }
                    VStack(alignment:.leading, spacing:4) {
                        Text(a.player.name).font(.system(size:18,weight:.black)).foregroundColor(.white).lineLimit(1)
                        Text(a.teamName).font(.system(size:12)).foregroundColor(Color(hex:"#7a90b8"))
                        RolePill(role:a.player.role)
                    }
                    Spacer()
                    VStack(alignment:.trailing, spacing:2) {
                        if a.isAllRound {
                            Text("\(a.runs)\(a.isNotOut ? "*" : "")").font(.system(size:26,weight:.black)).foregroundColor(Color(hex:"#f6c90e"))
                            Text("\(a.wickets)/\(a.bowlingRuns)").font(.system(size:16,weight:.bold)).foregroundColor(Color(hex:"#38bdf8"))
                            Text("All-round").font(.system(size:9)).foregroundColor(Color(hex:"#3d5070"))
                        } else {
                            Text("\(a.runs)\(a.isNotOut ? "*" : "")").font(.system(size:34,weight:.black)).foregroundColor(Color(hex:"#f6c90e"))
                            Text("\(a.balls)b · SR \(Int(a.strikeRate))").font(.system(size:11)).foregroundColor(Color(hex:"#3d5070"))
                        }
                    }
                }
                .padding(.horizontal,18).padding(.vertical,16)

                // Pills
                ScrollView(.horizontal, showsIndicators:false) {
                    HStack(spacing:6) {
                        if a.runs > 0 { AwardPill(text:"\(a.runs) runs", color:Color(hex:"#f97316")) }
                        if a.fours > 0 { AwardPill(text:"\(a.fours)×4", color:Color(hex:"#16a34a")) }
                        if a.sixes > 0 { AwardPill(text:"\(a.sixes)×6", color:Color(hex:"#f6c90e")) }
                        if a.isNotOut { AwardPill(text:"Not out", color:Color(hex:"#06b6d4")) }
                        if a.wickets > 0 { AwardPill(text:"\(a.wickets) wkts", color:Color(hex:"#ef4444")) }
                        if a.bowlingOvers != "" { AwardPill(text:"Econ \(a.bowlingOvers)", color:Color(hex:"#a855f7")) }
                    }.padding(.horizontal,18)
                }
                .padding(.bottom,16)
            }
        }
    }

    // MARK: Bat card
    var batCard: some View {
        let a = awards.bestBatter
        return miniAwardCard(
            label:"Best batting", icon:"figure.cricket",
            accent:Color(hex:"#f97316"),
            playerName:a.player.name, teamName:a.teamName, role:a.player.role,
            bigText:"\(a.runs)\(a.isNotOut ? "*":"")",
            sub:"\(a.balls)b · SR \(Int(a.strikeRate))",
            tag:"\(a.fours)×4 · \(a.sixes)×6"
        )
    }
    // MARK: Bowl card
    var bowlCard: some View {
        let a = awards.bestBowler
        return miniAwardCard(
            label:"Best bowling", icon:"target",
            accent:Color(hex:"#38bdf8"),
            playerName:a.player.name, teamName:a.teamName, role:a.player.role,
            bigText:"\(a.wickets)/\(a.runs)",
            sub:"\(a.oversDisplay) ov",
            tag:"Econ \(String(format:"%.1f",a.economy))"
        )
    }
    func miniAwardCard(label:String, icon:String, accent:Color, playerName:String, teamName:String, role:PlayerRole, bigText:String, sub:String, tag:String) -> some View {
        VStack(alignment:.leading, spacing:0) {
            HStack(spacing:5) {
                Image(systemName:icon).font(.system(size:9)).foregroundColor(accent)
                Text(label).font(.system(size:9,weight:.bold)).tracking(1.2).textCase(.uppercase).foregroundColor(Color(hex:"#3d5570"))
            }
            .padding(.horizontal,13).padding(.top,13).padding(.bottom,10).frame(maxWidth:.infinity,alignment:.leading)
            .overlay(Divider().background(Color.white.opacity(0.06)), alignment:.bottom)

            HStack(spacing:8) {
                Text(ini2(playerName)).font(.system(size:11,weight:.black)).foregroundColor(role.color)
                    .frame(width:32,height:32).background(role.color.opacity(0.16)).clipShape(RoundedRectangle(cornerRadius:8))
                VStack(alignment:.leading,spacing:1) {
                    Text(playerName).font(.system(size:11,weight:.bold)).foregroundColor(.white).lineLimit(1)
                    Text(teamName).font(.system(size:9)).foregroundColor(Color(hex:"#3d5070")).lineLimit(1)
                }
            }.padding(.horizontal,13).padding(.top,11)

            Text(bigText).font(.system(size:26,weight:.black)).foregroundColor(accent).padding(.horizontal,13).padding(.top,8)
            Text(sub).font(.system(size:10)).foregroundColor(Color(hex:"#3d5070")).padding(.horizontal,13).padding(.top,2)
            Text(tag).font(.system(size:10,weight:.semibold)).foregroundColor(accent.opacity(0.6)).padding(.horizontal,13).padding(.top,3).padding(.bottom,13)
        }
        .frame(maxWidth:.infinity, alignment:.leading)
        .background(Color(hex:"#0c1624")).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius:18).stroke(accent.opacity(0.22), lineWidth:1))
    }

    // MARK: Moments
    var momentsCard: some View {
        VStack(spacing:0) {
            HStack(spacing:7) {
                Image(systemName:"bolt.fill").font(.system(size:10)).foregroundColor(Color(hex:"#f6c90e"))
                Text("Key moments").font(.system(size:10,weight:.bold)).tracking(2).textCase(.uppercase).foregroundColor(Color(hex:"#3d5570"))
            }.padding(.horizontal,16).padding(.vertical,13).frame(maxWidth:.infinity,alignment:.leading)
            .overlay(Divider().background(Color.white.opacity(0.06)), alignment:.bottom)
            ForEach(awards.keyMoments) { m in
                HStack(spacing:11) {
                    Text(m.icon).font(.system(size:13)).frame(width:30,height:30).background(m.valueColor.opacity(0.11)).clipShape(RoundedRectangle(cornerRadius:7))
                    Text(m.description).font(.system(size:13)).foregroundColor(Color(hex:"#b8cce8")).frame(maxWidth:.infinity,alignment:.leading)
                    Text(m.value).font(.system(size:14,weight:.black)).foregroundColor(m.valueColor)
                }.padding(.horizontal,16).padding(.vertical,11)
                if m.id != awards.keyMoments.last?.id { Divider().background(Color.white.opacity(0.05)).padding(.horizontal,10) }
            }
        }
        .background(Color(hex:"#0c1624")).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius:18).stroke(Color.white.opacity(0.07), lineWidth:1))
    }

    // MARK: Stats strip
    var statsStrip: some View {
        let totalRuns = vm.match.innings1.runs + (vm.match.innings2?.runs ?? 0)
        let totalWkts = vm.match.innings1.wickets + (vm.match.innings2?.wickets ?? 0)
        let totalExtras = vm.match.innings1.extras + (vm.match.innings2?.extras ?? 0)
        return HStack(spacing:0) {
            sChip(val:"\(vm.match.totalOvers) ov", lbl:"Overs", col:Color(hex:"#a855f7"))
            Rectangle().fill(Color.white.opacity(0.07)).frame(width:1,height:28)
            sChip(val:"\(totalExtras)", lbl:"Extras", col:Color(hex:"#f59e0b"))
            Rectangle().fill(Color.white.opacity(0.07)).frame(width:1,height:28)
            sChip(val:"\(totalWkts)", lbl:"Wickets", col:Color(hex:"#ef4444"))
            Rectangle().fill(Color.white.opacity(0.07)).frame(width:1,height:28)
            sChip(val:"\(totalRuns)", lbl:"Total runs", col:Color(hex:"#4ade80"))
        }
        .background(Color(hex:"#0c1624")).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius:14).stroke(Color.white.opacity(0.07),lineWidth:1))
    }
    func sChip(val:String, lbl:String, col:Color) -> some View {
        VStack(spacing:2) {
            Text(val).font(.system(size:15,weight:.black)).foregroundColor(col)
            Text(lbl).font(.system(size:7,weight:.bold)).tracking(0.5).textCase(.uppercase).foregroundColor(Color(hex:"#3d5070"))
        }.frame(maxWidth:.infinity).padding(.vertical,12)
    }

    // MARK: Buttons
    var btns: some View {
        VStack(spacing:10) {
            Button { showScorecard = true } label: {
                HStack(spacing:9) {
                    Image(systemName:"list.bullet.clipboard").font(.system(size:14,weight:.semibold))
                    Text("Full Scorecard").font(.system(size:15,weight:.bold)).tracking(1)
                }
                .foregroundColor(Color(hex:"#8899bb")).frame(maxWidth:.infinity).padding(.vertical,16)
                .background(Color(hex:"#0c1624")).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius:16).stroke(Color.white.opacity(0.09),lineWidth:1))
            }
            Button { appVM.showMatchStarted = false; appVM.resetMatch() } label: {
                HStack(spacing:9) {
                    Image(systemName:"arrow.counterclockwise").font(.system(size:14,weight:.bold))
                    Text("New Match").font(.system(size:15,weight:.bold)).tracking(1)
                }
                .foregroundColor(Color(hex:"#0a0e1a")).frame(maxWidth:.infinity).padding(.vertical,16)
                .background(LinearGradient(colors:[Color(hex:"#f6c90e"),Color(hex:"#d4a60a")], startPoint:.topLeading, endPoint:.bottomTrailing))
                .cornerRadius(16)
                .shadow(color:Color(hex:"#f6c90e").opacity(0.3), radius:14, y:5)
            }
        }
    }

    // MARK: Animate
    func animate() {
        glow = true
        withAnimation(.spring(response:0.75, dampingFraction:0.55).delay(0.1)) { trophyS = 1; trophyY = 0 }
        withAnimation(.easeOut(duration:0.45).delay(0.35)) { h1 = 1 }
        withAnimation(.easeOut(duration:0.4).delay(0.6)) { h2 = 1 }
        withAnimation(.easeOut(duration:0.4).delay(0.8)) { h3 = 1 }
        withAnimation(.easeOut(duration:0.4).delay(1.0)) { h4 = 1 }
        withAnimation(.easeOut(duration:0.35).delay(1.2)) { h5 = 1 }
    }

    func ini2(_ s: String) -> String {
        String(s.split(separator:" ").prefix(2).compactMap(\.first).map{String($0).uppercased()}.joined().prefix(2))
    }
}

// MARK: - Reuse existing AwardPill
struct AwardPill: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.system(size:10,weight:.bold)).foregroundColor(color)
            .padding(.horizontal,10).padding(.vertical,4)
            .background(color.opacity(0.12)).clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.22),lineWidth:0.5))
    }
}
