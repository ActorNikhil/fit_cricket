import SwiftUI
import SwiftData

// MARK: - Match History (played match list)
// Lists every completed match, newest first, from the durable CompletedMatch
// store. Each row shows both innings' scores, the winner, and the margin so
// past results persist across launches.
struct MatchHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CompletedMatch.date, order: .reverse) private var matches: [CompletedMatch]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PageHeader(title: "Match History", subtitle: "Your completed matches").padding(.top, 8)

                    if matches.isEmpty {
                        VStack(spacing: 8) {
                            Text("🏆").font(.system(size: 40))
                            Text("No matches yet")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                            Text("Finish a match and it will be saved here with the final scores and winner.")
                                .font(.system(size: 13)).foregroundColor(Theme.text3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 20)
                    } else {
                        ForEach(matches) { match in
                            CompletedMatchCard(match: match) { context.delete(match) }
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarHidden(true).background(Color.clear)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Completed match card (history row)
struct CompletedMatchCard: View {
    let match: CompletedMatch
    let onDelete: () -> Void

    private var dateText: String {
        match.date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        CricketCard {
            VStack(spacing: 0) {
                // Header: date + overs
                HStack {
                    Text(dateText)
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text3)
                    Spacer()
                    Text("\(match.totalOvers) ov")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.purple)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.purple.opacity(0.12)).cornerRadius(6)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                Divider().background(Theme.border)

                // Innings scores
                HStack(spacing: 0) {
                    inningsColumn(team: match.firstBattingTeam,
                                  score: "\(match.firstRuns)/\(match.firstWickets)",
                                  overs: match.firstOvers,
                                  isWinner: !match.isTie && match.winnerName == match.firstBattingTeam,
                                  accent: Theme.green)
                    VStack(spacing: 6) {
                        Text("VS").font(.system(size: 10, weight: .black)).tracking(1).foregroundColor(Theme.gold)
                    }
                    .frame(width: 40)
                    inningsColumn(team: match.secondBattingTeam,
                                  score: "\(match.secondRuns)/\(match.secondWickets)",
                                  overs: match.secondOvers,
                                  isWinner: !match.isTie && match.winnerName == match.secondBattingTeam,
                                  accent: Theme.cyan)
                }
                .padding(.horizontal, 12).padding(.vertical, 14)

                Divider().background(Theme.border)

                // Result + delete
                HStack(spacing: 10) {
                    Text(match.isTie ? "🤝" : "🏆").font(.system(size: 15))
                    Text(match.resultText)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.gold)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.red).frame(width: 28, height: 28)
                            .background(Theme.red.opacity(0.12)).cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)

                if !match.manOfTheMatch.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(Theme.gold)
                        Text("MoM: \(match.manOfTheMatch)")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text3)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
        }
    }

    private func inningsColumn(team: String, score: String, overs: String, isWinner: Bool, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(team.isEmpty ? "—" : team)
                .font(.system(size: 12, weight: .bold)).foregroundColor(accent)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(score)
                .font(.system(size: 24, weight: .black)).foregroundColor(Theme.text).lineLimit(1)
            Text(overs.isEmpty ? "" : "(\(overs) ov)")
                .font(.system(size: 10)).foregroundColor(Theme.text3)
            if isWinner {
                Text("WON")
                    .font(.system(size: 9, weight: .black)).tracking(1).foregroundColor(Theme.gold)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.gold.opacity(0.14)).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}
