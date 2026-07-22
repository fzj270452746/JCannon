//
//  StageVault.swift
//  JCannon
//
//  Source of stage blueprints. Hand-authored stages load from StageCatalog.json;
//  any index beyond the catalog is generated procedurally from a reproducible
//  seed so the 300+ level curve exists without hand-listing every stage.
//

import Foundation

/// Resolves a stage index to a StageBlueprint. Named "Vault" per convention.
enum StageVault {

    /// Cached hand-authored catalog keyed by stage index.
    private static let catalog: [Int: StageBlueprint] = loadCatalog()

    /// Returns the blueprint for a 1-based stage index.
    static func blueprint(for index: Int) -> StageBlueprint {
        if let authored = catalog[index] {
            return authored
        }
        return proceduralBlueprint(index: index)
    }

    /// The highest stage index we expose in the campaign.
    static let campaignLength = 300

    // MARK: - Catalog loading

    private static func loadCatalog() -> [Int: StageBlueprint] {
        guard let url = Bundle.main.url(forResource: "StageCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        do {
            let blueprints = try JSONDecoder().decode([StageBlueprint].self, from: data)
            return Dictionary(uniqueKeysWithValues: blueprints.map { ($0.index, $0) })
        } catch {
            return [:]
        }
    }

    // MARK: - Procedural generation

    /// Deterministically builds a stage from its index. Every 10th stage is a boss.
    static func proceduralBlueprint(index: Int) -> StageBlueprint {
        var rng = SeededRandom(seed: SeedVault.stage(index), tag: "layout")
        let theme = themeForStage(index)
        let isBoss = index % 10 == 0

        if isBoss {
            return bossBlueprint(index: index, theme: theme, rng: &rng)
        }

        let goal = goalForStage(index, rng: &rng)
        let structures = layoutStructures(index: index, goal: goal, rng: &rng)
        let shots = shotBudget(for: goal, structureCount: structures.count)
        let mechanisms = mechanismsForStage(index, rng: &rng)

        return StageBlueprint(index: index,
                              theme: theme,
                              goal: goal,
                              shots: shots,
                              structures: structures,
                              hasBoss: false,
                              bossHP: nil,
                              windSpeed: nil,
                              ammo: ammoForStage(index),
                              mechanisms: mechanisms)
    }

    /// Progressively seeds interactive gadgets as the campaign advances. Each
    /// gadget type unlocks at a milestone so players meet them one at a time.
    private static func mechanismsForStage(_ index: Int, rng: inout SeededRandom) -> [MechanismPlacement] {
        var out: [MechanismPlacement] = []
        func place(_ kind: MechanismKind, _ x: Float, _ y: Float, _ z: Float,
                   exit: (Float, Float, Float)? = nil) {
            out.append(MechanismPlacement(kind: kind, x: x, y: y, z: z,
                                          x2: exit?.0, y2: exit?.1, z2: exit?.2))
        }
        // Milestones: ice(8), spring(11), hammer(14), portal(16), tnt(6), rope(20).
        if index >= 6 && rng.chance(0.4) { place(.tnt, rng.float(in: 5...9), 0.6, rng.float(in: -1.5...1.5)) }
        if index >= 8 && rng.chance(0.5) { place(.ice, rng.float(in: 5...8), 0.08, 0) }
        if index >= 11 && rng.chance(0.4) { place(.spring, rng.float(in: 2...4), 0, rng.float(in: -1...1)) }
        if index >= 14 && rng.chance(0.35) { place(.swingHammer, rng.float(in: 5...8), 5.5, 0) }
        if index >= 16 && rng.chance(0.3) {
            place(.portal, 3.5, 3.0, 0, exit: (8.5, 4.0, 0))
        }
        return out
    }

    // MARK: - Generation helpers

    private static func themeForStage(_ index: Int) -> BiomeTheme {
        let themes = BiomeTheme.allCases
        // Rotate themes every 5 stages.
        return themes[((index - 1) / 5) % themes.count]
    }

    private static func goalForStage(_ index: Int, rng: inout SeededRandom) -> StageGoal {
        // Introduce goal variety progressively.
        var pool: [StageGoal] = [.destroyAll]
        if index >= 4 { pool.append(.destroyWithinShots(shots: rng.int(in: 2...3))) }
        if index >= 7 { pool.append(.breakPillars(count: rng.int(in: 2...3))) }
        if index >= 12 { pool.append(.destroyTemple) }
        if index >= 15 { pool.append(.hitSwitch) }
        if index >= 18 { pool.append(.savePanda) }
        if index >= 22 && rng.chance(0.2) { pool.append(.oneShotWin) }
        return rng.pick(pool)
    }

    private static func layoutStructures(index: Int, goal: StageGoal, rng: inout SeededRandom) -> [StructurePlacement] {
        var placements: [StructurePlacement] = []
        let difficulty = min(index / 10, 5)

        switch goal {
        case .destroyTemple:
            placements.append(StructurePlacement(kind: .temple, x: 6, y: 0, z: 0))
        case .breakPillars(let n):
            for i in 0..<n {
                // Side-on play: all targets must sit on the z=0 firing plane, else
                // tiles pass in front of / behind them. Spread along X only.
                placements.append(StructurePlacement(kind: .dragonPillar, x: 4 + Float(i) * 2.2, y: 0, z: 0))
            }
        case .savePanda:
            // Fragile scaffolding around a panda target — cleared by removing
            // supports. Kept on the z=0 firing plane; spread along X.
            placements.append(StructurePlacement(kind: .woodTower, x: 5, y: 0, z: 0))
            placements.append(StructurePlacement(kind: .woodTower, x: 8, y: 0, z: 0))
        case .hitSwitch:
            placements.append(StructurePlacement(kind: .castle, x: 7, y: 0, z: 0))
        default:
            let count = 2 + difficulty
            let kinds: [StructureKind] = [.stoneTower, .woodTower, .castle, .bridge, .floatingIsland]
            for i in 0..<count {
                let kind = rng.pick(kinds)
                _ = rng.float(in: -2...2)   // keep RNG stream stable; targets stay on z=0
                placements.append(StructurePlacement(kind: kind,
                                                     x: 4 + Float(i) * 2.5,
                                                     y: 0,
                                                     z: 0))
            }
        }
        return placements
    }

    private static func shotBudget(for goal: StageGoal, structureCount: Int) -> Int {
        switch goal {
        case .oneShotWin: return 1
        case .destroyWithinShots(let s): return s
        default: return max(3, structureCount + 2)
        }
    }

    private static func ammoForStage(_ index: Int) -> [TileKind] {
        // Unlock tile variety as the player progresses.
        var kinds: [TileKind] = [.wan, .bamboo]
        if index >= 3 { kinds.append(.redDragon) }
        if index >= 6 { kinds.append(.dot) }
        if index >= 9 { kinds.append(.whiteDragon) }
        if index >= 13 { kinds.append(.greenDragon) }
        return kinds
    }

    private static func bossBlueprint(index: Int, theme: BiomeTheme, rng: inout SeededRandom) -> StageBlueprint {
        let hp = 150 + (index / 10) * 80
        // A couple of guard towers flank the boss.
        // Guard towers on the z=0 firing plane, separated along X so tiles can hit both.
        let structures = [
            StructurePlacement(kind: .stoneTower, x: 3.5, y: 0, z: 0),
            StructurePlacement(kind: .stoneTower, x: 6.0, y: 0, z: 0)
        ]
        return StageBlueprint(index: index,
                              theme: theme,
                              goal: .destroyBoss,
                              shots: 12 + index / 10,
                              structures: structures,
                              hasBoss: true,
                              bossHP: hp,
                              windSpeed: nil,
                              ammo: TileKind.allCases,
                              mechanisms: nil)
    }

    // MARK: - Daily challenge

    /// A once-per-day stage seeded from the calendar, no networking.
    static func dailyChallenge(for date: Date = Date()) -> StageBlueprint {
        var rng = SeededRandom(seed: SeedVault.daily(for: date), tag: "daily")
        let theme = rng.pick(BiomeTheme.allCases)
        let goal: StageGoal = .destroyAll
        let count = rng.int(in: 4...7)
        let kinds: [StructureKind] = [.stoneTower, .woodTower, .castle, .temple, .dragonPillar]
        var structures: [StructurePlacement] = []
        for i in 0..<count {
            let kind = rng.pick(kinds)
            _ = rng.float(in: -2.5...2.5)   // keep RNG stream stable; targets stay on z=0
            structures.append(StructurePlacement(kind: kind,
                                                 x: 4 + Float(i) * 2.3,
                                                 y: 0,
                                                 z: 0))
        }
        return StageBlueprint(index: -1,
                              theme: theme,
                              goal: goal,
                              shots: count + 1,
                              structures: structures,
                              hasBoss: false,
                              bossHP: nil,
                              windSpeed: rng.float(in: -3...3),
                              ammo: TileKind.allCases,
                              mechanisms: nil)
    }
}
