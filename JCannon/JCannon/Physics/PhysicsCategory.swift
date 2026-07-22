//
//  PhysicsCategory.swift
//  JCannon
//
//  Collision bitmasks for the single physics world. Kept in one place so
//  category/contact math stays consistent across builders.
//

import Foundation

/// Bit flags assigned to `SCNPhysicsBody.categoryBitMask`.
struct PhysicsCategory: OptionSet {
    let rawValue: Int

    static let ground     = PhysicsCategory(rawValue: 1 << 0)
    static let projectile = PhysicsCategory(rawValue: 1 << 1)
    static let structure  = PhysicsCategory(rawValue: 1 << 2)
    static let debris     = PhysicsCategory(rawValue: 1 << 3)
    static let boss       = PhysicsCategory(rawValue: 1 << 4)
    static let mechanism  = PhysicsCategory(rawValue: 1 << 5)   // TNT, springs, hammers
    static let target     = PhysicsCategory(rawValue: 1 << 6)   // objective flag (switch, panda)
    static let bossShield = PhysicsCategory(rawValue: 1 << 7)

    /// Everything a projectile should generate contact callbacks against.
    static var projectileContacts: PhysicsCategory {
        [.structure, .boss, .mechanism, .target, .bossShield, .ground]
    }
}
