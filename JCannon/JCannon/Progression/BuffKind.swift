//
//  BuffKind.swift
//  JCannon
//
//  Per-run buffs granted randomly at stage start. They live for a single stage
//  and modify launch / scoring behaviour through a resolved BuffState.
//

import Foundation

/// One-run modifiers. Names mirror the design doc.
enum BuffKind: String, CaseIterable, Codable {
    case doubleDamage
    case tripleBounce
    case megaExplosion
    case slowMotion
    case windIgnore
    case laserSight
    case goldenTile

    var displayName: String {
        switch self {
        case .doubleDamage:  return "DOUBLE DAMAGE"
        case .tripleBounce:  return "TRIPLE BOUNCE"
        case .megaExplosion: return "MEGA EXPLOSION"
        case .slowMotion:    return "SLOW MOTION"
        case .windIgnore:    return "WIND IGNORE"
        case .laserSight:    return "LASER SIGHT"
        case .goldenTile:    return "GOLDEN TILE"
        }
    }
}

/// Resolved buff flags for the active run.
struct BuffState {
    var doubleDamage = false
    var tripleBounce = false
    var megaExplosion = false
    var slowMotion = false
    var windIgnore = false
    var laserSight = false
    var goldenTile = false

    mutating func apply(_ buff: BuffKind) {
        switch buff {
        case .doubleDamage:  doubleDamage = true
        case .tripleBounce:  tripleBounce = true
        case .megaExplosion: megaExplosion = true
        case .slowMotion:    slowMotion = true
        case .windIgnore:    windIgnore = true
        case .laserSight:    laserSight = true
        case .goldenTile:    goldenTile = true
        }
    }

    var damageScale: Float { doubleDamage ? 2 : 1 }
    var explosionScale: Float { megaExplosion ? 1.8 : 1 }
    var bonusBounces: Int { tripleBounce ? 3 : 0 }
    var coinScale: Int { goldenTile ? 2 : 1 }
    var timeScale: Float { slowMotion ? 0.55 : 1 }
}
