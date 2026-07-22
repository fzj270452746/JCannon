//
//  TileForge.swift
//  JCannon
//
//  Builds a physics-ready mahjong tile node. A tile is an SCNBox with a chamfer
//  and per-face procedural textures, plus a dynamic body tuned by TileKind and
//  the current upgrade tree.
//

import SceneKit
import UIKit

/// Constructs projectile nodes. The only place tile geometry / body is assembled.
enum TileForge {

    /// Physical dimensions of a mahjong tile (in scene units ≈ decimetres).
    static let size = SCNVector3(0.85, 1.2, 0.6)

    /// Builds a ready-to-launch tile carrying its ProjectileComponent.
    static func makeTile(kind: TileKind, upgrades: UpgradeState, critical: Bool, now: TimeInterval) -> SCNNode {
        let box = SCNBox(width: CGFloat(size.x),
                         height: CGFloat(size.y),
                         length: CGFloat(size.z),
                         chamferRadius: 0.12)
        box.materials = faceMaterials(for: kind)

        let node = SCNNode(geometry: box)
        node.name = "tile.\(kind.rawValue)"
        node.role = .projectile

        let mass = kind.baseMass * CGFloat(upgrades.damageMultiplier)
        let body = SCNPhysicsBody(type: .dynamic, shape:
            SCNPhysicsShape(geometry: box, options: [.type: SCNPhysicsShape.ShapeType.boundingBox.rawValue]))
        body.mass = mass
        body.restitution = kind.restitution
        body.damping = kind.drag
        body.angularDamping = 0.2
        body.friction = 0.5
        body.categoryBitMask = PhysicsCategory.projectile.rawValue
        body.contactTestBitMask = PhysicsCategory.projectileContacts.rawValue
        body.collisionBitMask = (PhysicsCategory.ground.rawValue
                                 | PhysicsCategory.structure.rawValue
                                 | PhysicsCategory.boss.rawValue
                                 | PhysicsCategory.mechanism.rawValue
                                 | PhysicsCategory.bossShield.rawValue)
        node.physicsBody = body

        let bounce = kind.baseBounceBudget + (kind == .dot ? upgrades.bonusBounces : 0)
        node.projectile = ProjectileComponent(kind: kind,
                                              bounceBudget: bounce,
                                              critical: critical,
                                              launchTime: now)
        return node
    }

    // MARK: - Materials

    private static func faceMaterials(for kind: TileKind) -> [SCNMaterial] {
        let cache = ProceduralTextureCache.shared
        let front = material(cache.image(.tileFace(kind)))
        let back = material(cache.image(.tileBack))
        let side = material(color: UIColor(red: 0.92, green: 0.90, blue: 0.82, alpha: 1))
        // SCNBox face order: front, right, back, left, top, bottom.
        return [front, side, back, side, side, side]
    }

    private static func material(_ image: UIImage) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.roughness.contents = 0.6
        m.lightingModel = .physicallyBased
        return m
    }

    private static func material(color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        return m
    }
}
