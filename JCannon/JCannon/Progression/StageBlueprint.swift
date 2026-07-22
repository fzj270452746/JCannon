//
//  StageBlueprint.swift
//  JCannon
//
//  Data-driven stage description. Levels come from JSON or are generated
//  procedurally from a seed — either way they resolve to this value type before
//  the world is populated.
//

import SceneKit

/// The objective a stage requires to clear.
enum StageGoal: Codable, Equatable {
    case destroyAll
    case destroyBoss
    case breakPillars(count: Int)
    case hitSwitch
    case destroyTemple
    case savePanda
    case destroyWithinShots(shots: Int)
    case oneShotWin

    private enum CodingKeys: String, CodingKey { case type, count, shots }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "destroyAll":         self = .destroyAll
        case "destroyBoss":        self = .destroyBoss
        case "breakPillars":       self = .breakPillars(count: try c.decode(Int.self, forKey: .count))
        case "hitSwitch":          self = .hitSwitch
        case "destroyTemple":      self = .destroyTemple
        case "savePanda":          self = .savePanda
        case "destroyWithinShots": self = .destroyWithinShots(shots: try c.decode(Int.self, forKey: .shots))
        case "oneShotWin":         self = .oneShotWin
        default:                   self = .destroyAll
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .destroyAll:         try c.encode("destroyAll", forKey: .type)
        case .destroyBoss:        try c.encode("destroyBoss", forKey: .type)
        case .breakPillars(let n):
            try c.encode("breakPillars", forKey: .type); try c.encode(n, forKey: .count)
        case .hitSwitch:          try c.encode("hitSwitch", forKey: .type)
        case .destroyTemple:      try c.encode("destroyTemple", forKey: .type)
        case .savePanda:          try c.encode("savePanda", forKey: .type)
        case .destroyWithinShots(let s):
            try c.encode("destroyWithinShots", forKey: .type); try c.encode(s, forKey: .shots)
        case .oneShotWin:         try c.encode("oneShotWin", forKey: .type)
        }
    }

    var label: String {
        switch self {
        case .destroyAll:            return "DESTROY ALL"
        case .destroyBoss:           return "DESTROY BOSS"
        case .breakPillars(let n):   return "BREAK \(n) PILLARS"
        case .hitSwitch:             return "HIT SWITCH"
        case .destroyTemple:         return "DESTROY TEMPLE"
        case .savePanda:             return "SAVE PANDA"
        case .destroyWithinShots(let s): return "CLEAR IN \(s)"
        case .oneShotWin:            return "ONE SHOT"
        }
    }
}

/// Placement of a single structure within a stage.
struct StructurePlacement: Codable {
    let kind: StructureKind
    let x: Float
    let y: Float
    let z: Float

    var position: SCNVector3 { SCNVector3(x, y, z) }
}

/// The interactive gadgets a stage can host.
enum MechanismKind: String, Codable {
    case spring
    case swingHammer
    case portal
    case rope
    case ice
    case tnt
}

/// Placement of a mechanism. `x2/y2/z2` are the portal exit (unused otherwise).
struct MechanismPlacement: Codable {
    let kind: MechanismKind
    let x: Float
    let y: Float
    let z: Float
    let x2: Float?
    let y2: Float?
    let z2: Float?

    var position: SCNVector3 { SCNVector3(x, y, z) }
    var exitPosition: SCNVector3 { SCNVector3(x2 ?? x, y2 ?? (y + 3), z2 ?? z) }
}

/// A fully-specified stage. The world is built from this.
struct StageBlueprint: Codable {
    let index: Int
    let theme: BiomeTheme
    let goal: StageGoal
    let shots: Int
    let structures: [StructurePlacement]
    let hasBoss: Bool
    let bossHP: Int?
    /// Explicit wind speed; nil means seed-derived.
    let windSpeed: Float?

    /// Which tile kinds are offered in the ammo selector.
    let ammo: [TileKind]

    /// Interactive gadgets in the stage. Optional so older JSON stays valid.
    let mechanisms: [MechanismPlacement]?

    /// Convenience non-optional accessor.
    var gadgets: [MechanismPlacement] { mechanisms ?? [] }
}
