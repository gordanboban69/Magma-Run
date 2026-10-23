import Foundation
import Testing
@testable import MagmaRun

/// Tests for the obsidian crust and heart shard mechanics.
@MainActor
struct CrustAndShardTests {
    private func session(loadout: HeroLoadout? = nil, seed: UInt64 = 7) -> RunSession {
        RunSession(loadout: loadout ?? .starter, seed: seed)
    }

    /// Advances in small steps until `condition` holds or `limit` seconds pass.
    @discardableResult
    private func advance(_ session: inout RunSession, until condition: (RunSession, TickResult) -> Bool, limit: TimeInterval = 60) -> Bool {
        var elapsed: TimeInterval = 0
        let step = 1.0 / 60.0
        while elapsed < limit {
            let tick = session.advance(by: step)
            elapsed += step
            if condition(session, tick) { return true }
        }
        return false
    }

    private func damage(_ session: inout RunSession) {
        // Wait out invulnerability from an earlier hit before applying the next one.
        _ = session.advance(by: GameBalance.invulnerabilityDuration + 0.01)
        _ = session.registerLavaBurn()
    }

    // MARK: - Obsidian crust

    @Test func drainedRiverLeavesCrustOverTheSameStrip() throws {
        var run = session()
        let formed = advance(&run) { _, tick in tick.crustFormed }
        #expect(formed)
        let crust = try #require(run.crust)
        #expect(abs(crust.end - crust.start - LavaRiver.width) < 0.0001)
        #expect(run.lavaRiver == nil)
        #expect(crust.remaining <= ObsidianCrust.duration)
    }

    @Test func crustExpiresAfterItsDuration() {
        var run = session()
        advance(&run) { _, tick in tick.crustFormed }
        #expect(run.crust != nil)
        _ = run.advance(by: ObsidianCrust.duration + 0.05)
        #expect(run.crust == nil)
    }

    @Test func standingOnCrustDoublesPassiveScore() throws {
        var onCrust = session()
        advance(&onCrust) { _, tick in tick.crustFormed }
        let crust = try #require(onCrust.crust)
        var offCrust = onCrust

        onCrust.updateHeroPosition(normalizedX: (crust.start + crust.end) / 2)
        let outside = crust.start > 0.5 ? 0.0 : 1.0
        offCrust.updateHeroPosition(normalizedX: outside)
        #expect(onCrust.isOnCrust)
        #expect(offCrust.isOnCrust == false)

        let startOn = onCrust.score
        let startOff = offCrust.score
        _ = onCrust.advance(by: 0.5)
        _ = offCrust.advance(by: 0.5)
        let gainOn = onCrust.score - startOn
        let gainOff = offCrust.score - startOff
        #expect(abs(gainOn - gainOff * RunSession.crustScoreMultiplier) < 0.001)
        #expect(onCrust.crustTime > 0.49)
        #expect(offCrust.crustTime == 0)
    }

    @Test func nearMissOnCrustBuildsDoubleRage() throws {
        var run = session()
        advance(&run) { _, tick in tick.crustFormed }
        let crust = try #require(run.crust)
        run.updateHeroPosition(normalizedX: crust.start + 0.01)
        let before = run.rage
        run.registerNearMiss()
        #expect(abs(run.rage - before - RunSession.ragePerNearMiss * 2) < 0.0001)
    }

    @Test func heroPositionIsClamped() {
        var run = session()
        run.updateHeroPosition(normalizedX: -3)
        #expect(run.heroNormalizedX == 0)
        run.updateHeroPosition(normalizedX: 9)
        #expect(run.heroNormalizedX == 1)
    }

    // MARK: - Heart shards

    @Test func hotSmashDropsAreRateLimited() {
        var run = session()
        let first = run.registerHotSmash()
        let second = run.registerHotSmash()
        _ = run.advance(by: RunSession.shardDropCooldown + 0.01)
        let afterCooldown = run.registerHotSmash()
        #expect(first)
        #expect(second == false)
        #expect(afterCooldown)
    }

    @Test func threeShardsRestoreALostHeart() {
        var run = session()
        damage(&run)
        #expect(run.hearts == run.loadout.maxHearts - 1)

        let outcomes = (0..<3).map { _ in run.registerShardPickup() }
        #expect(outcomes == [.stored(count: 1), .stored(count: 2), .heartRestored])
        #expect(run.hearts == run.loadout.maxHearts)
        #expect(run.heartShards == 0)
        #expect(run.heartsRestored == 1)
        #expect(run.shardsCollected == 3)
    }

    @Test func completeSetAtFullHealthPaysEmbers() {
        var loadout = HeroLoadout.starter
        loadout.setLevel(2, for: .fortune)
        var run = session(loadout: loadout)
        _ = run.registerShardPickup()
        _ = run.registerShardPickup()
        let outcome = run.registerShardPickup()
        let expected = RunSession.shardOverflowEmbers * loadout.emberValue
        #expect(outcome == .bonusEmbers(expected))
        #expect(run.embersCollected == expected)
        #expect(run.hearts == loadout.maxHearts)
    }

    @Test func shardsAreIgnoredAfterTheRunEnds() {
        var run = session()
        for _ in 0..<run.loadout.maxHearts {
            damage(&run)
        }
        #expect(run.isOver)
        let pickup = run.registerShardPickup()
        let drop = run.registerHotSmash()
        #expect(pickup == .stored(count: 0))
        #expect(drop == false)
        #expect(run.shardsCollected == 0)
    }

    @Test func summaryReportsShardsAndCrustTime() throws {
        var run = session()
        _ = run.registerShardPickup()
        advance(&run) { _, tick in tick.crustFormed }
        let crust = try #require(run.crust)
        run.updateHeroPosition(normalizedX: crust.start + 0.01)
        _ = run.advance(by: 1)
        #expect(run.summary.heartShards == 1)
        #expect(run.summary.crustTime > 0.99)
    }

    @Test func hudMirrorsShardsAndCrust() throws {
        var run = session()
        _ = run.registerShardPickup()
        advance(&run) { _, tick in tick.crustFormed }
        let crust = try #require(run.crust)
        run.updateHeroPosition(normalizedX: crust.start + 0.01)
        let hud = GameHUDState(session: run)
        #expect(hud.heartShards == 1)
        #expect(hud.hasCrust)
        #expect(hud.isOnCrust)
    }
}
