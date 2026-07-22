//
//  AchievementVault.swift
//  JCannon
//
//  Tracks achievement progress by listening on CannonSignals. Definitions are
//  data; progress persists to UserDefaults. Unlocks fire a signal so the HUD can
//  toast them.
//

import Foundation

/// A single achievement definition. `goal` is the target count for the metric
/// the achievement tracks.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let goal: Int
}

/// Metrics achievements can watch. Kept separate from the definitions so several
/// achievements can key off the same running counter.
enum AchievementMetric: String {
    case structuresDestroyed
    case bossesDefeated
    case combosReached      // highest combo chain seen
    case stagesCleared
    case coinsEarned
    case tilesLaunched
}

/// Owns achievement progress + unlock state.
final class AchievementVault {

    static let shared = AchievementVault()

    /// The catalog. Adding an entry here is all it takes to ship a new one.
    let catalog: [Achievement] = [
        Achievement(id: "first_blood", title: "FIRST BLOOD", detail: "Destroy your first structure", goal: 1),
        Achievement(id: "demolisher", title: "DEMOLISHER", detail: "Destroy 100 structures", goal: 100),
        Achievement(id: "wrecking_crew", title: "WRECKING CREW", detail: "Destroy 500 structures", goal: 500),
        Achievement(id: "boss_slayer", title: "BOSS SLAYER", detail: "Defeat 1 boss", goal: 1),
        Achievement(id: "dragon_hunter", title: "DRAGON HUNTER", detail: "Defeat 10 bosses", goal: 10),
        Achievement(id: "combo_x5", title: "CHAIN REACTION", detail: "Reach a x5 combo", goal: 5),
        Achievement(id: "combo_x10", title: "UNSTOPPABLE", detail: "Reach a x10 combo", goal: 10),
        Achievement(id: "veteran", title: "VETERAN", detail: "Clear 25 stages", goal: 25),
        Achievement(id: "rich", title: "TILE TYCOON", detail: "Earn 5000 coins total", goal: 5000),
        Achievement(id: "sharpshooter", title: "SHARPSHOOTER", detail: "Launch 200 tiles", goal: 200)
    ]

    private let defaults = UserDefaults.standard
    private let metricsKey = "jc.ach.metrics"
    private let unlockedKey = "jc.ach.unlocked"

    private var metrics: [String: Int]
    private(set) var unlocked: Set<String>
    private var token: UUID?

    private init() {
        metrics = (defaults.dictionary(forKey: metricsKey) as? [String: Int]) ?? [:]
        unlocked = Set(defaults.stringArray(forKey: unlockedKey) ?? [])
    }

    /// Begins listening for gameplay events. Call once at app launch.
    func startListening() {
        guard token == nil else { return }
        token = CannonSignals.shared.subscribe { [weak self] event in
            self?.ingest(event)
        }
    }

    // MARK: - Event ingestion

    private func ingest(_ event: CannonEvent) {
        switch event {
        case .structureCollapsed:
            bump(.structuresDestroyed, by: 1)
        case .comboChanged(let chain, _):
            raise(.combosReached, to: chain)
        case .tileLaunched:
            bump(.tilesLaunched, by: 1)
        case .stageCleared:
            bump(.stagesCleared, by: 1)
        case .bossPhaseChanged(let phase, let total):
            // Final phase completion is inferred from stageCleared on a boss;
            // simplest reliable hook is the defeat, handled by recordBossDefeat.
            _ = (phase, total)
        default:
            break
        }
    }

    /// Called explicitly by gameplay when unambiguous (boss kills, coin totals).
    func recordBossDefeat() { bump(.bossesDefeated, by: 1) }
    func recordCoinsEarned(_ amount: Int) { bump(.coinsEarned, by: amount) }

    // MARK: - Metric mutation

    private func bump(_ metric: AchievementMetric, by amount: Int) {
        let value = (metrics[metric.rawValue] ?? 0) + amount
        metrics[metric.rawValue] = value
        persistMetrics()
        checkUnlocks(for: metric, value: value)
    }

    private func raise(_ metric: AchievementMetric, to value: Int) {
        let current = metrics[metric.rawValue] ?? 0
        guard value > current else { return }
        metrics[metric.rawValue] = value
        persistMetrics()
        checkUnlocks(for: metric, value: value)
    }

    private func metricValue(for metric: AchievementMetric) -> Int {
        metrics[metric.rawValue] ?? 0
    }

    // MARK: - Unlock evaluation

    private func checkUnlocks(for metric: AchievementMetric, value: Int) {
        for achievement in catalog where !unlocked.contains(achievement.id) {
            guard achievementMetric(achievement.id) == metric else { continue }
            if value >= achievement.goal {
                unlocked.insert(achievement.id)
                defaults.set(Array(unlocked), forKey: unlockedKey)
                CannonSignals.shared.emit(.achievementUnlocked(title: achievement.title))
            }
        }
    }

    /// Maps an achievement to the metric it watches.
    private func achievementMetric(_ id: String) -> AchievementMetric {
        switch id {
        case "first_blood", "demolisher", "wrecking_crew": return .structuresDestroyed
        case "boss_slayer", "dragon_hunter":               return .bossesDefeated
        case "combo_x5", "combo_x10":                      return .combosReached
        case "veteran":                                    return .stagesCleared
        case "rich":                                       return .coinsEarned
        case "sharpshooter":                               return .tilesLaunched
        default:                                           return .structuresDestroyed
        }
    }

    /// Progress (0…1) for display.
    func progress(for achievement: Achievement) -> Float {
        let value = metricValue(for: achievementMetric(achievement.id))
        return min(1, Float(value) / Float(achievement.goal))
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlocked.contains(achievement.id)
    }

    private func persistMetrics() {
        defaults.set(metrics, forKey: metricsKey)
    }
}
