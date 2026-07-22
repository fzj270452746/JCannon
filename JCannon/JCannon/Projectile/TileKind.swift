//
//  TileKind.swift
//  JCannon
//
//  The six mahjong projectile archetypes and their physical / gameplay traits.
//  All tuning lives here as data, not scattered through the launch code.
//

import UIKit
import SceneKit

/// A mahjong tile type used as ammunition. Each carries distinct mass, drag and
/// a special on-impact ability.
enum TileKind: String, CaseIterable, Codable {
    case redDragon    // Explosion
    case greenDragon  // Magnetic pulse
    case whiteDragon  // Shock wave
    case wan          // Heavy — smashing towers
    case bamboo       // Fast — low drag
    case dot          // Bounce — up to N times

    /// Human-facing short label for the HUD selector.
    var displayName: String {
        switch self {
        case .redDragon:   return "RED"
        case .greenDragon: return "GREEN"
        case .whiteDragon: return "WHITE"
        case .wan:         return "WAN"
        case .bamboo:      return "BAMBOO"
        case .dot:         return "DOT"
        }
    }

    /// Base mass before Damage upgrades. Wan is heaviest, bamboo lightest.
    var baseMass: CGFloat {
        switch self {
        case .wan:         return 3.2
        case .redDragon:   return 2.0
        case .greenDragon: return 1.8
        case .whiteDragon: return 1.8
        case .bamboo:      return 1.0
        case .dot:         return 1.3
        }
    }

    /// Linear damping — bamboo cuts through air, wan carries inertia.
    var drag: CGFloat {
        switch self {
        case .bamboo: return 0.02
        case .wan:    return 0.10
        case .dot:    return 0.05
        default:      return 0.08
        }
    }

    var restitution: CGFloat {
        switch self {
        case .dot: return 0.75   // bouncy
        case .wan: return 0.05
        default:   return 0.2
        }
    }

    /// How many bounces the tile survives before expiring (dot only, pre-upgrade).
    var baseBounceBudget: Int {
        switch self {
        case .dot: return 3
        default:   return 0
        }
    }

    /// Impact damage multiplier applied on top of kinetic force.
    var damageFactor: Float {
        switch self {
        case .wan:       return 1.6
        case .redDragon: return 1.2
        default:         return 1.0
        }
    }

    /// Radius of the always-on blast every tile makes at its contact point.
    /// This is what lets a single hit clear the blocks stacked *below* it, not
    /// just the one block it physically touched. Heavier tiles blast wider.
    var contactBlastRadius: Float {
        switch self {
        case .wan:       return 2.6
        case .redDragon: return 2.4
        case .dot, .bamboo: return 1.8
        default:         return 2.1
        }
    }

    /// Base splash damage of that contact blast, before distance falloff and
    /// the player's damage buffs. Calibrated so one clean hit topples a small
    /// tower's worth of blocks (wood hp 18, stone hp 30) near the impact.
    var contactBlastDamage: Float {
        switch self {
        case .wan:       return 70
        case .redDragon: return 60
        case .bamboo:    return 42
        default:         return 52
        }
    }

    /// The special ability triggered on first significant impact.
    var ability: TileAbility {
        switch self {
        case .redDragon:   return .explosion
        case .greenDragon: return .magnetic
        case .whiteDragon: return .shockwave
        default:           return .none
        }
    }

    /// Face accent colour for procedural texture drawing.
    var accentColor: UIColor {
        switch self {
        case .redDragon:   return UIColor(red: 0.80, green: 0.12, blue: 0.12, alpha: 1)
        case .greenDragon: return UIColor(red: 0.10, green: 0.55, blue: 0.25, alpha: 1)
        case .whiteDragon: return UIColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1)
        case .wan:         return UIColor(red: 0.70, green: 0.10, blue: 0.10, alpha: 1)
        case .bamboo:      return UIColor(red: 0.15, green: 0.50, blue: 0.20, alpha: 1)
        case .dot:         return UIColor(red: 0.20, green: 0.40, blue: 0.70, alpha: 1)
        }
    }
}

/// On-impact special effect resolved by PhysicsRelay.
enum TileAbility {
    case none
    case explosion   // radial damage + fireball
    case magnetic    // pull nearby structures toward impact
    case shockwave   // radial impulse pushing bodies away
}
