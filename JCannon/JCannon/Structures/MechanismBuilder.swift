//
//  MechanismBuilder.swift
//  JCannon
//
//  Builds objective / trap mechanisms: the hit-switch target, the rescue panda,
//  a TNT barrel, plus the interactive gadgets — spring, swinging hammer, portal
//  pair, rope support and ice patch. Each returns a node carrying the role /
//  MechanismComponent the relay needs to react at contact time.
//

import SceneKit
import UIKit

enum MechanismBuilder {

    /// A glowing switch the player must strike (hitSwitch goal).
    static func switchTarget(at position: SCNVector3) -> SCNNode {
        let base = SCNCylinder(radius: 0.6, height: 0.4)
        let bm = SCNMaterial()
        bm.diffuse.contents = ProceduralTextureCache.shared.image(.metal)
        base.materials = [bm]
        let node = SCNNode(geometry: base)
        node.position = position
        node.role = .objectiveSwitch

        let button = SCNSphere(radius: 0.4)
        let btnMat = SCNMaterial()
        btnMat.diffuse.contents = UIColor.red
        btnMat.emission.contents = UIColor(red: 1, green: 0.2, blue: 0.1, alpha: 1)
        button.materials = [btnMat]
        let buttonNode = SCNNode(geometry: button)
        buttonNode.position = SCNVector3(0, 0.4, 0)
        node.addChildNode(buttonNode)
        buttonNode.runAction(.repeatForever(.sequence([
            .scale(to: 1.1, duration: 0.6), .scale(to: 1.0, duration: 0.6)
        ])))

        let body = SCNPhysicsBody(type: .static, shape: nil)
        body.categoryBitMask = PhysicsCategory.target.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body
        return node
    }

    /// The panda to protect (savePanda goal). Simple capsule body + head.
    static func panda(at position: SCNVector3) -> SCNNode {
        let body = SCNCapsule(capRadius: 0.5, height: 1.4)
        let white = SCNMaterial()
        white.diffuse.contents = UIColor.white
        white.lightingModel = .physicallyBased
        body.materials = [white]
        let node = SCNNode(geometry: body)
        node.position = position
        node.role = .panda

        let head = SCNSphere(radius: 0.55)
        head.materials = [white]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0.9, 0)
        node.addChildNode(headNode)

        // Ears.
        for side in [Float(-0.35), 0.35] {
            let ear = SCNSphere(radius: 0.2)
            let black = SCNMaterial()
            black.diffuse.contents = UIColor.black
            ear.materials = [black]
            let earNode = SCNNode(geometry: ear)
            earNode.position = SCNVector3(side, 0.45, 0)
            headNode.addChildNode(earNode)
        }

        let phys = SCNPhysicsBody(type: .static, shape: nil)
        phys.categoryBitMask = PhysicsCategory.target.rawValue
        phys.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = phys
        return node
    }

    /// An explosive barrel that detonates when struck (mechanism category).
    static func tntBarrel(at position: SCNVector3) -> SCNNode {
        let barrel = SCNCylinder(radius: 0.5, height: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1)
        barrel.materials = [mat]
        let node = SCNNode(geometry: barrel)
        node.position = position
        node.role = .tnt
        node.health = HealthComponent(max: 1, coinWorth: 10)

        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: barrel, options: nil))
        body.mass = 1
        body.categoryBitMask = PhysicsCategory.mechanism.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body
        return node
    }

    // MARK: - Spring

    /// A spring pad that violently re-launches any tile that lands on it. The
    /// relay reads `launchStrength` and applies an upward impulse on contact.
    static func spring(at position: SCNVector3, strength: Float = 16) -> SCNNode {
        let root = SCNNode()
        root.position = position
        root.role = .spring

        // Coil = a stack of thin tori; base plate = a squat box.
        let base = SCNBox(width: 1.0, height: 0.2, length: 1.0, chamferRadius: 0.05)
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = ProceduralTextureCache.shared.image(.metal)
        base.materials = [baseMat]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(baseNode)

        let coilMat = SCNMaterial()
        coilMat.diffuse.contents = UIColor(red: 1.0, green: 0.75, blue: 0.1, alpha: 1)
        coilMat.metalness.contents = 0.7
        for i in 0..<4 {
            let coil = SCNTorus(ringRadius: 0.35, pipeRadius: 0.07)
            coil.materials = [coilMat]
            let coilNode = SCNNode(geometry: coil)
            coilNode.position = SCNVector3(0, 0.3 + Float(i) * 0.18, 0)
            root.addChildNode(coilNode)
        }
        // Top pad — the contact surface.
        let pad = SCNCylinder(radius: 0.45, height: 0.12)
        pad.materials = [baseMat]
        let padNode = SCNNode(geometry: pad)
        padNode.position = SCNVector3(0, 1.05, 0)
        root.addChildNode(padNode)

        // Static contact body spanning the coil so tiles reliably land on it.
        let shapeBox = SCNBox(width: 0.9, height: 1.1, length: 0.9, chamferRadius: 0)
        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: shapeBox, options: nil))
        body.categoryBitMask = PhysicsCategory.mechanism.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        root.physicsBody = body

        let comp = MechanismComponent()
        comp.launchStrength = strength
        root.mechanism = comp

        // Idle bob so it reads as "springy".
        padNode.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.08, z: 0, duration: 0.5),
            .moveBy(x: 0, y: -0.08, z: 0, duration: 0.5)
        ])))
        return root
    }

    // MARK: - Swing Hammer

    /// A hammer on a pivot arm that swings back and forth, batting tiles away.
    /// The head is kinematic and driven by an oscillating rotation on the pivot.
    static func swingHammer(at position: SCNVector3) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = position
        pivot.role = .scenery

        // Anchor post.
        let post = SCNCylinder(radius: 0.12, height: 0.4)
        let postMat = SCNMaterial()
        postMat.diffuse.contents = ProceduralTextureCache.shared.image(.metal)
        post.materials = [postMat]
        let postNode = SCNNode(geometry: post)
        pivot.addChildNode(postNode)

        // Swinging arm hangs down from the pivot.
        let arm = SCNNode()
        pivot.addChildNode(arm)

        let shaft = SCNCylinder(radius: 0.08, height: 2.4)
        shaft.materials = [postMat]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(0, -1.2, 0)
        arm.addChildNode(shaftNode)

        // Heavy head with a kinematic contact body.
        let head = SCNBox(width: 0.7, height: 0.7, length: 0.7, chamferRadius: 0.08)
        let headMat = SCNMaterial()
        headMat.diffuse.contents = ProceduralTextureCache.shared.image(.stone)
        head.materials = [headMat]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, -2.4, 0)
        headNode.role = .hammer
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: head, options: nil))
        body.categoryBitMask = PhysicsCategory.mechanism.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        headNode.physicsBody = body
        arm.addChildNode(headNode)

        // Pendulum swing.
        let swing = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: CGFloat.pi / 2.2, duration: 1.1),
            .rotateBy(x: 0, y: 0, z: -CGFloat.pi / 2.2, duration: 1.1)
        ])
        swing.timingMode = .easeInEaseOut
        arm.eulerAngles.z = -.pi / 4.4
        arm.runAction(.repeatForever(swing))
        return pivot
    }

    // MARK: - Portal pair

    /// Builds a linked portal pair. A tile entering `entry` is teleported to
    /// `exit`, keeping its momentum. Returns both nodes; caller adds each.
    static func portalPair(entry entryPos: SCNVector3, exit exitPos: SCNVector3) -> (entry: SCNNode, exit: SCNNode) {
        let entry = portalRing(color: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1), role: .portalIn)
        entry.position = entryPos
        let exit = portalRing(color: UIColor(red: 1.0, green: 0.5, blue: 0.9, alpha: 1), role: .portalOut)
        exit.position = exitPos

        let comp = MechanismComponent()
        comp.portalExit = exit
        entry.mechanism = comp
        return (entry, exit)
    }

    private static func portalRing(color: UIColor, role: NodeRole) -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.9, pipeRadius: 0.14)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.blendMode = .add
        ring.materials = [mat]
        let node = SCNNode(geometry: ring)
        node.role = role
        // Face the flight plane (rings stand upright in the XZ path).
        node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        // Inner disc trigger — a thin static cylinder the tile passes through.
        let disc = SCNCylinder(radius: 0.85, height: 0.1)
        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: disc, options: nil))
        body.categoryBitMask = PhysicsCategory.mechanism.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body

        node.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 4)))
        return node
    }

    // MARK: - Rope support

    /// A rope that holds a set of blocks aloft. Striking the rope severs it and
    /// the relay flips the suspended blocks to dynamic so they crash down.
    /// `builder` supplies the blocks (already positioned) that the rope holds.
    static func rope(at position: SCNVector3, holding blocks: [SCNNode]) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.role = .rope

        // A taut vertical cord drawn as a thin capsule.
        let cord = SCNCapsule(capRadius: 0.06, height: 2.0)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.75, green: 0.6, blue: 0.35, alpha: 1)
        cord.materials = [mat]
        let cordNode = SCNNode(geometry: cord)
        node.addChildNode(cordNode)

        let body = SCNPhysicsBody(type: .static, shape:
            SCNPhysicsShape(geometry: SCNBox(width: 0.3, height: 2.0, length: 0.3, chamferRadius: 0), options: nil))
        body.categoryBitMask = PhysicsCategory.mechanism.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body
        node.health = HealthComponent(max: 1, coinWorth: 5)

        let comp = MechanismComponent()
        comp.suspendedBlocks = blocks
        node.mechanism = comp
        return node
    }

    // MARK: - Ice patch

    /// A low-friction floor patch. Bodies resting on it slide, making structures
    /// easier to topple. Purely physical — no relay logic needed.
    static func icePatch(at position: SCNVector3, size: Float = 4) -> SCNNode {
        let slab = SCNBox(width: CGFloat(size), height: 0.15, length: CGFloat(size), chamferRadius: 0.05)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.8)
        mat.transparency = 0.85
        mat.metalness.contents = 0.3
        mat.roughness.contents = 0.05
        slab.materials = [mat]
        let node = SCNNode(geometry: slab)
        node.position = position
        node.role = .ice

        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: slab, options: nil))
        body.friction = 0.02
        body.restitution = 0.1
        body.categoryBitMask = PhysicsCategory.ground.rawValue
        node.physicsBody = body
        return node
    }
}
