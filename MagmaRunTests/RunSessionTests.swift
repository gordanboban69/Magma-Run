import Foundation
import Testing
@testable import MagmaRun

/// Tests for the framework-free run simulation.
@MainActor
struct RunSessionTests {
    private func shieldedLoadout() -> HeroLoadout {
        var loadout = HeroLoadout.starter
        loadout.setLevel(5, for: .shield)
        return loadout
    }

    @Test func freshSessionStartsFromLoadout() {
        let session = RunSession(loadout: .starter)
        #expect(session.hearts == 3)
        #expect(session.displayScore == 0)
        #expect(session.elapsed == 0)
        #expect(session.hasShield == false)
        #expect(session.isShieldReady == false)
        #expect(session.isOver == false)
    }

    @Test func advancingAccumulatesTimeAndScore() {
        var session = RunSession(loadout: .starter)
        _ = session.advance(by: 1)
        #expect(session.elapsed == 1)
        #expect(session.score > 0)
        #expect(session.displayScore >= 10)
    }

    @Test func zeroOrNegativeStepsAreIgnored() {
        var session = RunSession(loadout: .starter)
        #expect(session.advance(by: 0) == .none)
        #expect(session.advance(by: -1) == .none)
        #expect(session.elapsed == 0)
    }

    @Test func bouldersSpawnOnSchedule() {
        var session = RunSession(loadout: .starter)
        var spawned = 0
        for _ in 0..<60 {
            spawned += session.advance(by: 1.0 / 60.0).bouldersToSpawn
        }
        // Within the first second the pre-shortened initial delay must have fired once.
        #expect(spawned >= 1)
        #expect(spawned <= 2)
    }

    @Test func embersSpawnOnSchedule() {
        var session = RunSession(loadout: .starter)
        var emberTicks = 0
        for _ in 0..<(60 * 5) {
            if session.advance(by: 1.0 / 60.0).spawnEmber { emberTicks += 1 }
        }
        // First ember at 1.5s, then every ~2.2s: 1.5, 3.7 -> 2 within 5 seconds.
        #expect(emberTicks == 2)
    }

    @Test func hitRemovesHeartAndGrantsInvulnerability() {
        var session = RunSession(loadout: .starter)
        let first = session.registerBoulderHit()
        #expect(first == .damaged(remainingHearts: 2))
        #expect(session.isInvulnerable)

        let second = session.registerBoulderHit()
        #expect(second == .ignored)
        #expect(session.hearts == 2)

        _ = session.advance(by: GameBalance.invulnerabilityDuration + 0.01)
        #expect(session.isInvulnerable == false)
    }

    @Test func lastHeartEndsTheRun() {
        var session = RunSession(loadout: .starter)
        for _ in 0..<2 {
            _ = session.registerBoulderHit()
            _ = session.advance(by: GameBalance.invulnerabilityDuration + 0.01)
        }
        #expect(session.hearts == 1)
        #expect(session.registerBoulderHit() == .fatal)
        #expect(session.isOver)
        #expect(session.hearts == 0)
        #expect(session.advance(by: 1) == .none)
        #expect(session.registerBoulderHit() == .ignored)
    }

    @Test func shieldAbsorbsOneHitAndRecharges() {
        var session = RunSession(loadout: shieldedLoadout())
        #expect(session.isShieldReady)

        #expect(session.registerBoulderHit() == .shieldAbsorbed)
        #expect(session.hearts == 3)
        #expect(session.isShieldReady == false)

        _ = session.advance(by: GameBalance.shieldGraceDuration + 0.01)
        #expect(session.registerBoulderHit() == .damaged(remainingHearts: 2))

        let recharge = try! #require(session.loadout.shieldRecharge)
        _ = session.advance(by: recharge + 0.1)
        #expect(session.isShieldReady)
    }

    @Test func emberPickupUsesEmberValue() {
        var loadout = HeroLoadout.starter
        loadout.setLevel(3, for: .fortune)
        var session = RunSession(loadout: loadout)
        session.registerEmberPickup()
        session.registerEmberPickup()
        #expect(session.emberPickups == 2)
        #expect(session.embersCollected == 8)
        #expect(session.displayScore == GameBalance.scorePerEmber * 2)
    }

    @Test func dodgesAddScore() {
        var session = RunSession(loadout: .starter)
        session.registerDodge()
        session.registerDodge()
        #expect(session.bouldersDodged == 2)
        #expect(session.displayScore == GameBalance.scorePerDodge * 2)
    }

    @Test func summaryReflectsState() {
        var session = RunSession(loadout: .starter)
        _ = session.advance(by: 12)
        session.registerEmberPickup()
        session.registerDodge()
        let summary = session.summary
        #expect(summary.duration == 12)
        #expect(summary.embersCollected == 1)
        #expect(summary.bouldersDodged == 1)
        #expect(summary.score == session.displayScore)
        #expect(summary.heroID == HeroSkin.starter.rawValue)
    }
}
