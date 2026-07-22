//
//  BossBuilder.swift
//  JCannon
//
//  Builds the Dragon Statue boss from primitives: a stacked body, a head with a
//  mouth emitter anchor, and a rotating torus shield. No models — pure SceneKit
//  composition, consistent with the rest of the art pipeline.
//

import SceneKit
import UIKit

/// Assembled boss node hierarchy with the handles the controller needs.
struct BossRig {
    let root: SCNNode
    /// Node carrying the HealthComponent — damage is applied here.
    let core: SCNNode
    /// Fire-breath emission anchor.
    let mouth: SCNNode
    /// Rotating shield torus; hidden when the shield is down.
    let shield: SCNNode
}

enum BossBuilder {

    static func build(at position: SCNVector3, hp: Int) -> BossRig {
        let root = SCNNode()
        root.position = position
        root.name = "boss"

        let core = SCNNode()
        core.name = "boss.core"
        core.role = .boss
        core.health = HealthComponent(max: Float(hp), coinWorth: 300)
        root.addChildNode(core)

        // Body — stacked scaled boxes forming a serpentine tower.
        let bodyMat = scaleMaterial()
        var y: Float = 1.0
        for i in 0..<5 {
            let width = 2.2 - Float(i) * 0.25
            let seg = SCNBox(width: CGFloat(width), height: 1.0, length: CGFloat(width),
                             chamferRadius: 0.2)
            seg.materials = [bodyMat]
            let segNode = SCNNode(geometry: seg)
            segNode.position = SCNVector3(sinf(Float(i)) * 0.3, y, 0)
            attachStatic(to: segNode, geometry: seg, category: .boss)
            core.addChildNode(segNode)
            y += 1.0
        }

        // Head — a larger box + two horn cones.
        let head = SCNBox(width: 2.0, height: 1.6, length: 1.8, chamferRadius: 0.3)
        head.materials = [bodyMat]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, y + 0.4, 0)
        attachStatic(to: headNode, geometry: head, category: .boss)
        core.addChildNode(headNode)

        for side in [Float(-0.6), 0.6] {
            let horn = SCNCone(topRadius: 0, bottomRadius: 0.25, height: 1.0)
            let hm = SCNMaterial()
            hm.diffuse.contents = ProceduralTextureCache.shared.image(.gold)
            hm.lightingModel = .physicallyBased
            horn.materials = [hm]
            let hornNode = SCNNode(geometry: horn)
            hornNode.position = SCNVector3(side, 1.0, 0)
            hornNode.eulerAngles = SCNVector3(0, 0, -side * 0.4)
            headNode.addChildNode(hornNode)
        }

        // Glowing eyes.
        for side in [Float(-0.45), 0.45] {
            let eye = SCNSphere(radius: 0.16)
            let em = SCNMaterial()
            em.diffuse.contents = UIColor.red
            em.emission.contents = UIColor(red: 1, green: 0.3, blue: 0.1, alpha: 1)
            eye.materials = [em]
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(side, 0.2, 0.9)
            headNode.addChildNode(eyeNode)
        }

        // Mouth anchor for fire breath.
        let mouth = SCNNode()
        mouth.position = SCNVector3(0, -0.4, 1.0)
        headNode.addChildNode(mouth)

        // Rotating shield ring around the whole boss.
        let shield = buildShield(height: y + 1.0)
        root.addChildNode(shield)
        shield.isHidden = true

        return BossRig(root: root, core: core, mouth: mouth, shield: shield)
    }

    // MARK: - Shield

    private static func buildShield(height: Float) -> SCNNode {
        let container = SCNNode()
        container.name = "boss.shield"
        // Three stacked rotating tori give a "spinning shield" read.
        for i in 0..<3 {
            let torus = SCNTorus(ringRadius: 2.6, pipeRadius: 0.12)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.6)
            m.emission.contents = UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1)
            m.transparency = 0.7
            m.blendMode = .add
            torus.materials = [m]
            let node = SCNNode(geometry: torus)
            node.position = SCNVector3(0, Float(i) * (height / 3) + 1.5, 0)
            node.eulerAngles = SCNVector3(Float(i) * 0.4, 0, 0)

            // Physics: shield blocks projectiles.
            let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: torus, options: nil))
            body.categoryBitMask = PhysicsCategory.bossShield.rawValue
            body.contactTestBitMask = PhysicsCategory.projectile.rawValue
            node.physicsBody = body
            node.role = .bossShield

            let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0,
                                                         duration: 3 + Double(i)))
            node.runAction(spin)
            container.addChildNode(node)
        }
        return container
    }

    // MARK: - Helpers

    private static func scaleMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = ProceduralTextureCache.shared.image(.dragonScale)
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.5
        return m
    }

    private static func attachStatic(to node: SCNNode, geometry: SCNGeometry, category: PhysicsCategory) {
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        body.categoryBitMask = category.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body
    }
}
