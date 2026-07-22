//
//  ScoreLedger.swift
//  JCannon
//
//  Tracks per-stage performance metrics and resolves a final star rating.
//  Combo uses a time-windowed chain: consecutive collapses within a short
//  window keep the multiplier climbing.
//

import Foundation

/// Immutable result computed when a stage ends.
struct StageScore {
    let stars: Int          // 1…3
    let coins: Int
    let accuracy: Float     // hits / shots fired
    let shotsRemaining: Int
    let damageDealt: Float
    let maxCombo: Int
    let elapsed: TimeInterval
}

/// Accumulates events during a run and produces a StageScore. One instance per
/// stage attempt.
final class ScoreLedger {

    // Tunable combo window in seconds.
    private let comboWindow: TimeInterval = 2.5

    private(set) var shotsFired = 0
    private(set) var hits = 0
    private(set) var damageDealt: Float = 0
    private(set) var coinsEarned = 0
    private(set) var maxCombo = 0

    private var comboChain = 0
    private var lastCollapseTime: TimeInterval = -100
    private var startTime: TimeInterval = 0

    private let totalShots: Int
    private let buffCoinScale: Int

    init(totalShots: Int, buffCoinScale: Int, startTime: TimeInterval) {
        self.totalShots = totalShots
        self.buffCoinScale = buffCoinScale
        self.startTime = startTime
    }

    // MARK: - Recording

    func recordLaunch() {
        shotsFired += 1
    }

    /// Call the first time a shot connects with anything meaningful.
    func recordHit() {
        hits += 1
    }

    func recordDamage(_ amount: Float) {
        damageDealt += amount
    }

    /// A structure collapsed at `time`. Extends or resets the combo chain and
    /// returns the coins awarded (already combo-scaled).
    @discardableResult
    func recordCollapse(worth: Int, at time: TimeInterval) -> Int {
        if time - lastCollapseTime <= comboWindow {
            comboChain += 1
        } else {
            comboChain = 1
        }
        lastCollapseTime = time
        maxCombo = max(maxCombo, comboChain)

        let multiplier = comboMultiplier(for: comboChain)
        CannonSignals.shared.emit(.comboChanged(chain: comboChain, multiplier: multiplier))

        let award = worth * multiplier * buffCoinScale
        coinsEarned += award
        return award
    }

    /// Combo decays if the window lapses; call from the frame loop.
    func tick(now: TimeInterval) {
        if comboChain > 0 && now - lastCollapseTime > comboWindow {
            comboChain = 0
            CannonSignals.shared.emit(.comboChanged(chain: 0, multiplier: 1))
        }
    }

    private func comboMultiplier(for chain: Int) -> Int {
        switch chain {
        case 0...1: return 1
        case 2...3: return 2
        case 4...6: return 3
        case 7...9: return 5
        default:    return 10
        }
    }

    // MARK: - Finalise

    func finalize(now: TimeInterval, clearedTargets: Bool) -> StageScore {
        let shotsRemaining = max(0, totalShots - shotsFired)
        let accuracy = shotsFired > 0 ? Float(hits) / Float(shotsFired) : 0
        let elapsed = now - startTime

        // Star thresholds blend accuracy, leftover ammo and combo.
        var score: Float = 0
        score += accuracy * 40
        score += Float(shotsRemaining) / Float(max(1, totalShots)) * 30
        score += Float(min(maxCombo, 10)) * 3

        let stars: Int
        if !clearedTargets { stars = 0 }
        else if score >= 70 { stars = 3 }
        else if score >= 45 { stars = 2 }
        else { stars = 1 }

        // Completion + star bonus coins.
        let starBonus = stars * 40
        let totalCoins = coinsEarned + (clearedTargets ? 50 + starBonus : 0)

        return StageScore(stars: stars,
                          coins: totalCoins,
                          accuracy: accuracy,
                          shotsRemaining: shotsRemaining,
                          damageDealt: damageDealt,
                          maxCombo: maxCombo,
                          elapsed: elapsed)
    }
}
