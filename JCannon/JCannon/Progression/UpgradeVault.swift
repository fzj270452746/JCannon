//
//  UpgradeVault.swift
//  JCannon
//
//  Persistent upgrade tree + coin balance. Upgrade effects are exposed as a
//  resolved `UpgradeState` snapshot that the forge / relay read from, so tuning
//  never touches gameplay code directly.
//

import Foundation

/// Coin-purchasable upgrade tracks.
enum UpgradeTrack: String, CaseIterable, Codable {
    case damage          // + mass / impact
    case explosionRadius // + red dragon blast
    case launchSpeed     // + initial velocity
    case bounceCount     // + dot bounces
    case criticalChance  // chance of ×2 damage

    var displayName: String {
        switch self {
        case .damage:          return "DAMAGE"
        case .explosionRadius: return "BLAST"
        case .launchSpeed:     return "SPEED"
        case .bounceCount:     return "BOUNCE"
        case .criticalChance:  return "CRIT"
        }
    }

    var maxLevel: Int { 5 }

    /// Coin cost to go from `level` to `level + 1`.
    func cost(atLevel level: Int) -> Int {
        return 50 + level * 75
    }
}

/// A resolved, read-only view of all upgrade effects. Rebuilt whenever a level
/// changes so hot paths just read plain numbers.
struct UpgradeState {
    let damageMultiplier: Float
    let explosionRadiusMultiplier: Float
    let launchSpeedMultiplier: Float
    let bonusBounces: Int
    let criticalChance: Float

    static let baseline = UpgradeState(damageMultiplier: 1,
                                       explosionRadiusMultiplier: 1,
                                       launchSpeedMultiplier: 1,
                                       bonusBounces: 0,
                                       criticalChance: 0.05)
}

/// Owns coin balance + upgrade levels, persisted to UserDefaults. Named "Vault"
/// per the project naming convention (no *Manager*).
final class UpgradeVault {

    static let shared = UpgradeVault()

    private let defaults = UserDefaults.standard
    private let coinsKey = "jc.coins"
    private let levelsKey = "jc.upgradeLevels"

    private(set) var coins: Int {
        didSet { defaults.set(coins, forKey: coinsKey) }
    }
    private var levels: [String: Int] {
        didSet { defaults.set(levels, forKey: levelsKey) }
    }

    private init() {
        coins = defaults.integer(forKey: coinsKey)
        levels = (defaults.dictionary(forKey: levelsKey) as? [String: Int]) ?? [:]
    }

    // MARK: - Coins

    func awardCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
        CannonSignals.shared.emit(.coinsChanged(total: coins))
    }

    // MARK: - Upgrades

    func level(of track: UpgradeTrack) -> Int {
        levels[track.rawValue] ?? 0
    }

    /// Attempts to buy the next level. Returns true on success.
    @discardableResult
    func purchase(_ track: UpgradeTrack) -> Bool {
        let current = level(of: track)
        guard current < track.maxLevel else { return false }
        let price = track.cost(atLevel: current)
        guard coins >= price else { return false }
        coins -= price
        levels[track.rawValue] = current + 1
        CannonSignals.shared.emit(.coinsChanged(total: coins))
        return true
    }

    /// Builds the resolved state consumed by the forge and relay.
    func resolvedState() -> UpgradeState {
        let d = Float(level(of: .damage))
        let e = Float(level(of: .explosionRadius))
        let s = Float(level(of: .launchSpeed))
        let b = level(of: .bounceCount)
        let c = Float(level(of: .criticalChance))
        return UpgradeState(damageMultiplier: 1 + d * 0.18,
                            explosionRadiusMultiplier: 1 + e * 0.25,
                            launchSpeedMultiplier: 1 + s * 0.12,
                            bonusBounces: b,
                            criticalChance: 0.05 + c * 0.08)
    }
}
