import Foundation
import Testing
@testable import MagmaRun

/// Tests for the four signature mechanics: rage shockwaves, lava rivers, overdrive and volcano moods.
@MainActor
struct MechanicsTests {
    private func session(seed: UInt64 = 7) -> RunSession {
        RunSession(loadout: .starter, seed: seed)
    }

    private func advance(_ session: inout RunSession, seconds: TimeInterval, step: TimeInterval = 1.0 / 60.0) -> [TickResult] {
        var results: [TickResult] = []
        var remaining = seconds
        while remaining > 0 {
            let dt = min(step, remaining)
            results.append(session.advance(by: dt))
            remaining -= dt
        }
        return results
    }

    // MARK: - Rage & shockwave

    @Test func fiveNearMissesChargeAShockwave() {
        var run = session()
        for _ in 0..<4 {
            run.registerNearMiss()
            #expect(run.isShockwaveReady == false)
        }
        #expect(abs(run.rage - 0.8) < 0.0001)
        run.registerNearMiss()
        #expect(run.rage == 1)
        #expect(run.isShockwaveReady)
        #expect(run.displayScore == Int(RunSession.nearMissScore * 5))

        let fired = run.consumeShockwave()
        let firedAgain = run.consumeShockwave()
        #expect(fired)
        #expect(firedAgain == false)
        #expect(run.rage == 0)
        #expect(run.shockwavesFired == 1)

        run.registerShockwaveSmash(count: 3)
        #expect(run.bouldersDodged == 3)
        #expect(run.displayScore == Int(RunSession.nearMissScore * 5 + RunSession.shockwaveScorePerBoulder * 3))
    }

    @Test func rageIsCappedAndIgnoredAfterDefeat() {
        var run = session()
        for _ in 0..<12 { run.registerNearMiss() }
        #expect(run.rage == 1)
        for _ in 0..<3 { _ = run.registerBoulderHit(); _ = run.advance(by: GameBalance.invulnerabilityDuration + 0.1) }
        #expect(run.isOver)
        #expect(run.consumeShockwave() == false)
    }

    // MARK: - Lava rivers

    @Test func lavaRiverWarnsThenFlowsThenDrains() {
        var run = session()
        #expect(run.lavaRiver == nil)

        _ = advance(&run, seconds: RunSession.firstRiverDelay + 0.05)
        let warning = try! #require(run.lavaRiver)
        #expect(warning.phase == .warning)
        #expect(abs((warning.end - warning.start) - LavaRiver.width) < 0.000001)
        #expect(warning.start >= 0 && warning.end <= 1)
        #expect(run.isLavaBurning(atNormalizedX: (warning.start + warning.end) / 2) == false)

        let results = advance(&run, seconds: LavaRiver.warningDuration + 0.05)
        #expect(results.contains { $0.lavaStartedFlowing })
        let flowing = try! #require(run.lavaRiver)
        #expect(flowing.phase == .flowing)
        let inside = (flowing.start + flowing.end) / 2
        let outside = flowing.end > 0.6 ? flowing.start - 0.05 : flowing.end + 0.05
        #expect(run.isLavaBurning(atNormalizedX: inside))
        #expect(run.isLavaBurning(atNormalizedX: outside) == false)

        _ = advance(&run, seconds: LavaRiver.flowDuration + 0.05)
        #expect(run.lavaRiver == nil)
        #expect(run.nextRiverIn >= 12 && run.nextRiverIn <= 20)
    }

    @Test func lavaBurnsOncePerInvulnerabilityWindow() {
        var run = session()
        #expect(run.registerLavaBurn() == .damaged(remainingHearts: 2))
        #expect(run.registerLavaBurn() == .ignored)
        _ = run.advance(by: GameBalance.invulnerabilityDuration + 0.05)
        #expect(run.registerLavaBurn() == .damaged(remainingHearts: 1))
    }

    @Test func lavaIgnoresOverdriveButShieldAbsorbsIt() {
        var loadout = HeroLoadout.starter
        loadout.setLevel(1, for: .shield)
        var run = RunSession(loadout: loadout, seed: 3)
        for _ in 0..<RunSession.overdriveComboLength { run.registerEmberPickup() }
        #expect(run.isOverdrive)
        #expect(run.registerLavaBurn() == .shieldAbsorbed)
        _ = run.advance(by: GameBalance.shieldGraceDuration + 0.05)
        #expect(run.registerLavaBurn() == .damaged(remainingHearts: 2))
    }

    // MARK: - Overdrive

    @Test func sixEmberStreakTriggersOverdrive() {
        var run = session()
        for index in 1..<RunSession.overdriveComboLength {
            run.registerEmberPickup()
            #expect(run.combo == index)
            #expect(run.isOverdrive == false)
        }
        run.registerEmberPickup()
        #expect(run.isOverdrive)
        #expect(run.overdrivesTriggered == 1)
        #expect(run.overdriveRemaining == RunSession.overdriveDuration)
        #expect(run.currentEmberValue == HeroLoadout.starter.emberValue * 2)

        let before = run.embersCollected
        run.registerEmberPickup()
        #expect(run.embersCollected == before + 2)

        #expect(run.registerBoulderHit() == .overdriveSmash)
        #expect(run.hearts == 3)

        _ = run.advance(by: RunSession.overdriveDuration + 0.05)
        #expect(run.isOverdrive == false)
        #expect(run.currentEmberValue == 1)
    }

    @Test func damageResetsTheComboButNotTheBank() {
        var run = session()
        run.registerEmberPickup()
        run.registerEmberPickup()
        #expect(run.combo == 2)
        _ = run.registerBoulderHit()
        #expect(run.combo == 0)
        #expect(run.embersCollected == 2)
    }

    // MARK: - Volcano moods

    @Test func moodsAreTelegraphedAndCycleBackToSteady() {
        var run = session(seed: 11)
        #expect(run.mood == .steady)

        _ = advance(&run, seconds: RunSession.firstMoodDelay + 0.05)
        let upcoming = try! #require(run.upcomingMood)
        #expect(VolcanoMood.specials.contains(upcoming))
        #expect(run.mood == .steady)

        let switchResults = advance(&run, seconds: VolcanoMood.warningDuration + 0.05)
        #expect(switchResults.contains { $0.moodChanged })
        #expect(run.mood == upcoming)
        #expect(run.upcomingMood == nil)

        let backResults = advance(&run, seconds: upcoming.duration + 0.05)
        #expect(backResults.contains { $0.moodChanged })
        #expect(run.mood == .steady)
        // A fresh calm window is 9...14 s, minus the few frames that elapsed after the switch.
        #expect(run.moodRemaining > 8.5 && run.moodRemaining <= 14)
    }

    @Test func moodsChangeSpawnRates() {
        #expect(VolcanoMood.fury.spawnIntervalMultiplier < VolcanoMood.steady.spawnIntervalMultiplier)
        #expect(VolcanoMood.emberShower.emberIntervalMultiplier < 1)
        #expect(VolcanoMood.ashRain.rainProbability == 0.9)
        #expect(VolcanoMood.steady.rainProbability == nil)
        #expect(VolcanoMood.fury.aimedProbability > VolcanoMood.steady.aimedProbability)
        for mood in VolcanoMood.specials {
            #expect(mood.duration > 0)
            #expect(mood.warningText.isEmpty == false)
        }
    }

    @Test func seededSessionsAreDeterministic() {
        var first = session(seed: 99)
        var second = session(seed: 99)
        _ = advance(&first, seconds: 40)
        _ = advance(&second, seconds: 40)
        #expect(first.mood == second.mood)
        #expect(first.upcomingMood == second.upcomingMood)
        #expect(first.lavaRiver == second.lavaRiver)
        #expect(first.displayScore == second.displayScore)
    }

    @Test func summaryCarriesMechanicCounters() {
        var run = session()
        for _ in 0..<5 { run.registerNearMiss() }
        _ = run.consumeShockwave()
        for _ in 0..<RunSession.overdriveComboLength { run.registerEmberPickup() }
        let summary = run.summary
        #expect(summary.shockwaves == 1)
        #expect(summary.overdrives == 1)
    }
}
