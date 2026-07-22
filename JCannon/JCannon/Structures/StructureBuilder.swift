//
//  StructureBuilder.swift
//  JCannon
//
//  Assembles breakable buildings from SCNBox / SCNCylinder / SCNCapsule with
//  procedural materials. No 3D models — every tower, temple and pillar is a
//  composition of primitives, each carrying its own HealthComponent.
//

import SceneKit
import UIKit

/// Building archetypes the level data can request.
enum StructureKind: String, Codable {
    case stoneTower
    case woodTower
    case dragonPillar
    case temple
    case castle
    case bridge
    case floatingIsland
}

/// Result of building a structure: the root node plus the individual breakable
/// blocks (so the relay can total up objective worth).
struct BuiltStructure {
    let root: SCNNode
    let breakables: [SCNNode]
}

/// Builds structures. Each returns dynamic physics blocks that topple realistically.
enum StructureBuilder {

    static func build(_ kind: StructureKind, at position: SCNVector3, seed: UInt64) -> BuiltStructure {
        var rng = SeededRandom(seed: seed, tag: kind.rawValue)
        let root = SCNNode()
        root.position = position
        root.name = "structure.\(kind.rawValue)"

        let blocks: [SCNNode]
        switch kind {
        case .stoneTower:     blocks = stackedTower(material: .stone, rng: &rng, height: 6, hp: 30)
        case .woodTower:      blocks = stackedTower(material: .wood, rng: &rng, height: 5, hp: 18)
        case .dragonPillar:   blocks = dragonPillar(rng: &rng)
        case .temple:         blocks = temple(rng: &rng)
        case .castle:         blocks = castle(rng: &rng)
        case .bridge:         blocks = bridge(rng: &rng)
        case .floatingIsland: blocks = floatingIsland(rng: &rng)
        }

        for b in blocks { root.addChildNode(b) }
        return BuiltStructure(root: root, breakables: blocks)
    }

    // MARK: - Block factory

    private static func makeBlock(size: SCNVector3,
                                  position: SCNVector3,
                                  face: SurfaceFace,
                                  hp: Float,
                                  worth: Int) -> SCNNode {
        let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y),
                         length: CGFloat(size.z), chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = ProceduralTextureCache.shared.image(face)
        mat.lightingModel = .physicallyBased
        box.materials = [mat]

        let node = SCNNode(geometry: box)
        node.position = position
        node.role = .structure

        let body = SCNPhysicsBody(type: .dynamic, shape:
            SCNPhysicsShape(geometry: box, options: nil))
        body.mass = CGFloat(size.x * size.y * size.z) * 2.0
        body.friction = 0.8
        body.restitution = 0.05
        body.categoryBitMask = PhysicsCategory.structure.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        body.collisionBitMask = (PhysicsCategory.ground.rawValue
                                 | PhysicsCategory.structure.rawValue
                                 | PhysicsCategory.projectile.rawValue
                                 | PhysicsCategory.debris.rawValue)
        node.physicsBody = body
        node.health = HealthComponent(max: hp, coinWorth: worth)
        return node
    }

    private static func makeCylinder(radius: CGFloat, height: CGFloat,
                                     position: SCNVector3, face: SurfaceFace,
                                     hp: Float, worth: Int) -> SCNNode {
        let cyl = SCNCylinder(radius: radius, height: height)
        let mat = SCNMaterial()
        mat.diffuse.contents = ProceduralTextureCache.shared.image(face)
        mat.lightingModel = .physicallyBased
        cyl.materials = [mat]

        let node = SCNNode(geometry: cyl)
        node.position = position
        node.role = .structure

        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: cyl, options: nil))
        body.mass = radius * radius * height * 3
        body.friction = 0.8
        body.categoryBitMask = PhysicsCategory.structure.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        body.collisionBitMask = (PhysicsCategory.ground.rawValue
                                 | PhysicsCategory.structure.rawValue
                                 | PhysicsCategory.projectile.rawValue)
        node.physicsBody = body
        node.health = HealthComponent(max: hp, coinWorth: worth)
        return node
    }

    // MARK: - Archetypes

    private static func stackedTower(material: SurfaceFace, rng: inout SeededRandom,
                                     height: Int, hp: Float) -> [SCNNode] {
        var blocks: [SCNNode] = []
        let blockH: Float = 0.7
        let w: Float = 1.2
        for i in 0..<height {
            let jitter = rng.float(in: -0.04...0.04)
            let node = makeBlock(size: SCNVector3(w, blockH, w),
                                 position: SCNVector3(jitter, blockH / 2 + Float(i) * blockH, 0),
                                 face: material, hp: hp, worth: 10)
            blocks.append(node)
        }
        return blocks
    }

    private static func dragonPillar(rng: inout SeededRandom) -> [SCNNode] {
        var blocks: [SCNNode] = []
        let segments = 5
        let segH: Float = 0.9
        for i in 0..<segments {
            let node = makeCylinder(radius: 0.5, height: CGFloat(segH),
                                    position: SCNVector3(0, segH / 2 + Float(i) * segH, 0),
                                    face: .dragonScale, hp: 40, worth: 15)
            blocks.append(node)
        }
        // Crown capsule.
        let crown = SCNCapsule(capRadius: 0.55, height: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = ProceduralTextureCache.shared.image(.gold)
        mat.lightingModel = .physicallyBased
        crown.materials = [mat]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, Float(segments) * segH + 0.6, 0)
        crownNode.role = .structure
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: crown, options: nil))
        body.mass = 2
        body.categoryBitMask = PhysicsCategory.structure.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        crownNode.physicsBody = body
        crownNode.health = HealthComponent(max: 30, coinWorth: 25)
        blocks.append(crownNode)
        return blocks
    }

    private static func temple(rng: inout SeededRandom) -> [SCNNode] {
        var blocks: [SCNNode] = []
        // Four pillars + roof slab. Side-on play means only tiles on the z=0
        // plane can strike, so keep the pillars' z within tile reach (±0.4)
        // while spreading them wider on x for a temple silhouette.
        let pillarX: [Float] = [-1.4, 1.4]
        let pillarZ: [Float] = [-0.4, 0.4]
        for x in pillarX {
            for z in pillarZ {
                blocks.append(makeCylinder(radius: 0.35, height: 2.4,
                                           position: SCNVector3(x, 1.2, z),
                                           face: .stone, hp: 35, worth: 15))
            }
        }
        blocks.append(makeBlock(size: SCNVector3(3.6, 0.5, 3.6),
                                position: SCNVector3(0, 2.65, 0),
                                face: .brick, hp: 50, worth: 30))
        // Base platform.
        blocks.append(makeBlock(size: SCNVector3(4.0, 0.4, 4.0),
                                position: SCNVector3(0, 0.2, 0),
                                face: .stone, hp: 60, worth: 20))
        return blocks
    }

    private static func castle(rng: inout SeededRandom) -> [SCNNode] {
        var blocks: [SCNNode] = []
        // Main keep.
        for i in 0..<4 {
            blocks.append(makeBlock(size: SCNVector3(2.4, 0.8, 2.4),
                                    position: SCNVector3(0, 0.4 + Float(i) * 0.8, 0),
                                    face: .brick, hp: 45, worth: 15))
        }
        // Corner turrets.
        for x in [Float(-1.6), 1.6] {
            for z in [Float(-1.6), 1.6] {
                blocks.append(makeCylinder(radius: 0.5, height: 3.2,
                                           position: SCNVector3(x, 1.6, z),
                                           face: .stone, hp: 40, worth: 15))
            }
        }
        return blocks
    }

    private static func bridge(rng: inout SeededRandom) -> [SCNNode] {
        var blocks: [SCNNode] = []
        // Two supports and a deck spanning between them.
        for x in [Float(-2.5), 2.5] {
            blocks.append(makeBlock(size: SCNVector3(0.8, 2.0, 1.4),
                                    position: SCNVector3(x, 1.0, 0),
                                    face: .stone, hp: 40, worth: 15))
        }
        blocks.append(makeBlock(size: SCNVector3(6.0, 0.4, 1.6),
                                position: SCNVector3(0, 2.2, 0),
                                face: .wood, hp: 25, worth: 20))
        return blocks
    }

    private static func floatingIsland(rng: inout SeededRandom) -> [SCNNode] {
        var blocks: [SCNNode] = []
        // Suspended platform with a small structure on top.
        blocks.append(makeBlock(size: SCNVector3(3.0, 0.6, 3.0),
                                position: SCNVector3(0, 3.0, 0),
                                face: .stone, hp: 50, worth: 25))
        for i in 0..<3 {
            blocks.append(makeBlock(size: SCNVector3(0.9, 0.7, 0.9),
                                    position: SCNVector3(0, 3.65 + Float(i) * 0.7, 0),
                                    face: .wood, hp: 18, worth: 10))
        }
        return blocks
    }
}
