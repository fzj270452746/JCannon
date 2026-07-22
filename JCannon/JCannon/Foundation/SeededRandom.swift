//
//  SeededRandom.swift
//  JCannon
//
//  Reproducible RNG. Every random-driven system (stage layout, loot, wind) draws
//  from a named seed so a level can be replayed and debugged deterministically.
//

import Foundation

/// SplitMix64 — small, fast, well-distributed. Chosen over `arc4random` so the
/// same StageSeed always produces the same map regardless of device.
struct SeededRandom: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state which would degenerate the mixer.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// Derives a sub-generator from a string label, so `SeededRandom(seed: base, tag: "wind")`
    /// and `tag: "loot"` diverge from the same base seed.
    init(seed: UInt64, tag: String) {
        var mixed = seed &+ 0x9E3779B97F4A7C15
        for byte in tag.utf8 {
            mixed = (mixed ^ UInt64(byte)) &* 0x100000001B3
        }
        self.init(seed: mixed)
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    // MARK: - Convenience draws

    mutating func float(in range: ClosedRange<Float>) -> Float {
        let unit = Float(next() >> 11) * (1.0 / Float(1 << 53))
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func chance(_ probability: Float) -> Bool {
        return float(in: 0...1) < probability
    }

    mutating func pick<T>(_ elements: [T]) -> T {
        precondition(!elements.isEmpty, "pick from empty collection")
        return elements[int(in: 0...(elements.count - 1))]
    }
}

/// Namespaced seed source. The daily challenge and normal stages both funnel
/// through here so seeding logic stays in one place.
enum SeedVault {

    /// Deterministic seed for a given stage index.
    ///
    /// Non-campaign modes pass sentinel indices (e.g. the daily challenge uses
    /// `-1`), so convert via `bitPattern` — a plain `UInt64(index)` traps on any
    /// negative value. For non-negative indices the result is unchanged.
    static func stage(_ index: Int) -> UInt64 {
        return 0xC0FFEE &+ UInt64(bitPattern: Int64(index)) &* 0x9E3779B1
    }

    /// One seed per calendar day, no networking required.
    static func daily(for date: Date = Date()) -> UInt64 {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let key = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
        return UInt64(bitPattern: Int64(key)) &* 0x2545F4914F6CDD1D
    }
}
