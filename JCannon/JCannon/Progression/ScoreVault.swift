//
//  ScoreVault.swift
//  JCannon
//
//  Local, offline records: per-stage best stars, total stars, endless best round
//  and daily-challenge history. Backs the leaderboard UI. No networking — all
//  boards are local per the design.
//

import Foundation

/// One daily-challenge result kept for the local board.
struct DailyRecord: Codable {
    let dayKey: Int      // yyyymmdd
    let coins: Int
    let stars: Int
}

/// Owns all persistent score records.
final class ScoreVault {

    static let shared = ScoreVault()

    private let defaults = UserDefaults.standard
    private let starsKey = "jc.score.stars"        // [stageIndex: bestStars]
    private let endlessKey = "jc.score.endlessBest"
    private let dailyKey = "jc.score.daily"        // [DailyRecord]

    private var stageStars: [Int: Int]
    private(set) var endlessBest: Int
    private(set) var dailyRecords: [DailyRecord]

    private init() {
        if let raw = defaults.dictionary(forKey: starsKey) as? [String: Int] {
            var mapped: [Int: Int] = [:]
            for (k, v) in raw { if let i = Int(k) { mapped[i] = v } }
            stageStars = mapped
        } else {
            stageStars = [:]
        }
        endlessBest = defaults.integer(forKey: endlessKey)
        if let data = defaults.data(forKey: dailyKey),
           let decoded = try? JSONDecoder().decode([DailyRecord].self, from: data) {
            dailyRecords = decoded
        } else {
            dailyRecords = []
        }
    }

    // MARK: - Campaign

    /// Stores the best star rating for a stage; keeps the higher of old/new.
    func recordStage(index: Int, stars: Int, coins: Int) {
        let best = max(stageStars[index] ?? 0, stars)
        stageStars[index] = best
        persistStars()
    }

    func stars(forStage index: Int) -> Int { stageStars[index] ?? 0 }

    var totalStars: Int { stageStars.values.reduce(0, +) }

    var highestStageCleared: Int { stageStars.keys.filter { $0 > 0 && $0 < 1000 }.max() ?? 0 }

    // MARK: - Endless

    func recordEndless(round: Int) {
        guard round > endlessBest else { return }
        endlessBest = round
        defaults.set(round, forKey: endlessKey)
    }

    // MARK: - Daily

    func recordDaily(dayKey: Int, coins: Int, stars: Int) {
        // One record per day; overwrite if the player retries with a better run.
        if let idx = dailyRecords.firstIndex(where: { $0.dayKey == dayKey }) {
            if coins > dailyRecords[idx].coins {
                dailyRecords[idx] = DailyRecord(dayKey: dayKey, coins: coins, stars: stars)
            }
        } else {
            dailyRecords.append(DailyRecord(dayKey: dayKey, coins: coins, stars: stars))
        }
        // Keep the most recent 30 days, sorted newest first.
        dailyRecords.sort { $0.dayKey > $1.dayKey }
        if dailyRecords.count > 30 { dailyRecords = Array(dailyRecords.prefix(30)) }
        persistDaily()
    }

    // MARK: - Persistence

    private func persistStars() {
        let mapped = Dictionary(uniqueKeysWithValues: stageStars.map { (String($0.key), $0.value) })
        defaults.set(mapped, forKey: starsKey)
    }

    private func persistDaily() {
        if let data = try? JSONEncoder().encode(dailyRecords) {
            defaults.set(data, forKey: dailyKey)
        }
    }
}
