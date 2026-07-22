//
//  BossController.swift
//  JCannon
//
//  Drives the boss encounter: phase transitions as HP drops, a rotating shield
//  that blocks damage while active, and periodic skills (falling rocks, ground
//  slam). Emits CannonSignals so the HUD boss bar and physics stay in sync.
//

import SceneKit
import UIKit

/// A single boss phase description.
struct BossPhase {
    let thresholdNormalized: Float   // enter when HP fraction drops below this
    let shieldActive: Bool
    let skillInterval: TimeInterval
}

/// Coordinates the boss rig with gameplay. Owned by the gameplay layer for the
/// duration of a boss stage.
final class BossController {

    let rig: BossRig
    private let scene: SCNScene
    private let phases: [BossPhase]
    private var currentPhase = 0
    private var lastSkillTime: TimeInterval = 0
    private var defeated = false

    init(rig: BossRig, scene: SCNScene) {
        self.rig = rig
        self.scene = scene
        // Three phases: shielded intro → aggressive → desperate (no shield, fast skills).
        self.phases = [
            BossPhase(thresholdNormalized: 1.0, shieldActive: false, skillInterval: 4.0),
            BossPhase(thresholdNormalized: 0.6, shieldActive: true,  skillInterval: 3.0),
            BossPhase(thresholdNormalized: 0.3, shieldActive: false, skillInterval: 2.0)
        ]
        CannonSignals.shared.emit(.bossPhaseChanged(phase: 1, total: phases.count))
        emitHealth()
    }

    var isDefeated: Bool { defeated }

    /// Whether incoming projectile damage should be blocked right now.
    var shieldIsUp: Bool { !rig.shield.isHidden }

    // MARK: - Damage

    /// Applies damage to the boss core if the shield is down. Returns true if
    /// this hit defeated the boss.
    @discardableResult
    func applyDamage(_ amount: Float) -> Bool {
        guard !defeated, let health = rig.core.health else { return false }
        if shieldIsUp { return false }        // shield absorbs everything

        let killed = health.apply(amount)
        AudioPulse.shared.play(.bossHit)
        emitHealth()
        flashCore()
        updatePhase(for: health.normalized)

        if killed {
            defeated = true
            collapse()
            return true
        }
        return false
    }

    private func emitHealth() {
        guard let h = rig.core.health else { return }
        CannonSignals.shared.emit(.bossDamaged(current: Int(h.current), max: Int(h.max)))
    }

    // MARK: - Phase logic

    private func updatePhase(for normalized: Float) {
        // Advance to the deepest phase whose threshold we've dropped below.
        var target = 0
        for (i, phase) in phases.enumerated() where normalized <= phase.thresholdNormalized {
            target = i
        }
        if target != currentPhase {
            currentPhase = target
            rig.shield.isHidden = !phases[target].shieldActive
            CannonSignals.shared.emit(.bossPhaseChanged(phase: target + 1, total: phases.count))
        }
    }

    // MARK: - Skills (called from frame loop)

    func update(now: TimeInterval) {
        guard !defeated else { return }
        let interval = phases[currentPhase].skillInterval
        if now - lastSkillTime >= interval {
            lastSkillTime = now
            performRandomSkill(now: now)
        }
    }

    private func performRandomSkill(now: TimeInterval) {
        var rng = SeededRandom(seed: UInt64(now * 1000) &+ 13, tag: "boss-skill")
        let roll = rng.int(in: 0...2)
        switch roll {
        case 0: dropRock(rng: &rng)
        case 1: groundSlam()
        default: breatheFire()
        }
    }

    /// Drops a heavy dynamic boulder in front of the boss.
    private func dropRock(rng: inout SeededRandom) {
        let rock = SCNSphere(radius: 0.6)
        let m = SCNMaterial()
        m.diffuse.contents = ProceduralTextureCache.shared.image(.stone)
        rock.materials = [m]
        let node = SCNNode(geometry: rock)
        let bossPos = rig.root.position
        node.position = SCNVector3(bossPos.x - rng.float(in: 1...4), bossPos.y + 8, bossPos.z + rng.float(in: -1...1))
        node.role = .structure
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: rock, options: nil))
        body.mass = 6
        body.categoryBitMask = PhysicsCategory.structure.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        node.physicsBody = body
        node.health = HealthComponent(max: 20, coinWorth: 5)
        scene.rootNode.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 6), .removeFromParentNode()]))
    }

    /// A ground slam that pushes nearby dynamic bodies with a radial impulse.
    private func groundSlam() {
        let origin = rig.root.presentation.worldPosition
        ParticleForge.burst(ParticleForge.shockRing(color: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)),
                            at: SCNVector3(origin.x, 0.1, origin.z), in: scene.rootNode)
        AudioPulse.shared.play(.bossHit)
        applyRadialImpulse(from: SIMD3(origin.x, 0, origin.z), radius: 8, strength: 6)
    }

    /// A short forward fire cone (visual + small camera-side push).
    private func breatheFire() {
        let mouthPos = rig.mouth.presentation.worldPosition
        ParticleForge.burst(ParticleForge.explosion(radius: 1.4), at: mouthPos, in: scene.rootNode)
        AudioPulse.shared.play(.explosion)
    }

    private func applyRadialImpulse(from center: SIMD3<Float>, radius: Float, strength: Float) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let body = node.physicsBody, body.type == .dynamic else { return }
            let p = node.presentation.worldPosition
            let delta = SIMD3(p.x, p.y, p.z) - center
            let dist = simd_length(delta)
            guard dist < radius, dist > 0.01 else { return }
            let falloff = (1 - dist / radius)
            let dir = simd_normalize(delta)
            let impulse = dir * strength * falloff
            body.applyForce(SCNVector3(impulse.x, abs(impulse.y) + 2, impulse.z), asImpulse: true)
        }
    }

    // MARK: - FX

    private func flashCore() {
        rig.core.enumerateChildNodes { n, _ in
            guard let mat = n.geometry?.firstMaterial else { return }
            let flash = SCNAction.sequence([
                .run { _ in mat.emission.contents = UIColor.red },
                .wait(duration: 0.1),
                .run { _ in mat.emission.contents = UIColor.black }
            ])
            n.runAction(flash)
        }
    }

    private func collapse() {
        AudioPulse.shared.play(.explosion)
        let pos = rig.root.presentation.worldPosition
        ParticleForge.burst(ParticleForge.explosion(radius: 3), at: pos, in: scene.rootNode)
        ParticleForge.burst(ParticleForge.smoke(), at: pos, in: scene.rootNode)
        rig.shield.removeFromParentNode()
        rig.root.runAction(.sequence([
            .group([.scale(to: 0.01, duration: 0.6), .fadeOut(duration: 0.6)]),
            .removeFromParentNode()
        ]))
    }
}
