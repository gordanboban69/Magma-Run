import SwiftUI

/// Lifetime statistics, achievements and the recent run history.
struct RecordsView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var statColumns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var achievementColumns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        let profile = store.profile
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: statColumns, spacing: 12) {
                    StatTile(title: "Best score", value: Formatters.integer(profile.bestScore), systemImage: "trophy.fill")
                    StatTile(title: "Runs", value: Formatters.integer(profile.totalRuns), systemImage: "flag.checkered", tint: Theme.Colors.success)
                    StatTile(title: "Longest run", value: Formatters.duration(profile.longestSurvival), systemImage: "timer", tint: Color(red: 0.6, green: 0.8, blue: 1.0))
                    StatTile(title: "Embers collected", value: Formatters.integer(profile.totalEmbersCollected), systemImage: "flame.fill", tint: Theme.Colors.lava)
                }

                VStack(spacing: 12) {
                    SectionHeader(title: "Achievements", subtitle: "\(unlockedAchievements)/\(store.achievements.count) unlocked")
                    LazyVGrid(columns: achievementColumns, spacing: 12) {
                        ForEach(store.achievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }

                VStack(spacing: 12) {
                    SectionHeader(title: "Recent runs", subtitle: "Your last \(ProfileStore.recentRunLimit) eruptions")
                    if store.recentRuns.isEmpty {
                        emptyRuns
                    } else {
                        VStack(spacing: 8) {
                            ForEach(store.recentRuns) { run in
                                RunRow(run: run, isBest: run.score == profile.bestScore && run.score > 0)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 16))
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Records.screen)
    }

    private var unlockedAchievements: Int {
        store.achievements.filter(\.isUnlocked).count
    }

    private var emptyRuns: some View {
        VStack(spacing: 10) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No runs yet")
                .font(.display(17))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Finish a run and it will show up here with your score, embers and survival time.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Records.emptyState)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: achievement.progress, lineWidth: 3, tint: achievement.isUnlocked ? Theme.Colors.ember : Theme.Colors.ash)
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(achievement.isUnlocked ? Theme.Colors.ember : Theme.Colors.textTertiary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.display(15))
                    .foregroundStyle(achievement.isUnlocked ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                Text(achievement.detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.success)
            } else {
                Text("\(Int(achievement.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 2, isHighlighted: achievement.isUnlocked)
        .accessibilityElement(children: .combine)
    }
}

private struct RunRow: View {
    let run: RunRecord
    let isBest: Bool

    var body: some View {
        HStack(spacing: 12) {
            HeroAvatarView(skin: run.hero, size: 40, isAnimated: false)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(Formatters.integer(run.score))
                        .font(.display(17))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if isBest {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }
                Text(Formatters.runDate(run.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                    Text("+\(Formatters.integer(run.embersCollected))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                Text("\(Formatters.duration(run.duration)) · \(run.bouldersDodged) dodged")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(12)
        .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius)
        .accessibilityElement(children: .combine)
    }
}
