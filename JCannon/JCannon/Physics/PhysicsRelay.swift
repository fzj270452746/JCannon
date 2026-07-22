//
//  PhysicsRelay.swift
//  JCannon
//
//  The gameplay brain. Sits between the physics world and the rest of the game:
//  routes collisions to damage, triggers tile abilities, tracks live targets and
//  resolves win / loss each turn. Contains no rendering code.
//

import SceneKit
import UIKit

/// Owns per-stage combat state and answers "did this turn win or lose?".
final class PhysicsRelay: NSObject, SCNPhysicsContactDelegate {

    private let scene: SCNScene
    private let world: GameWorld
    private let ledger: ScoreLedger
    private let buffs: BuffState
    private let upgrades: UpgradeState
    private let goal: StageGoal

    /// Live breakable nodes that count toward the objective.
    private var liveTargets: Set<SCNNode> = []
    /// Pillars specifically (for breakPillars goal).
    private var pillarRoots: [SCNNode] = []
    private var brokenPillars = 0
    /// Boss controller, if this is a boss stage.
    weak var boss: BossController?

    /// Objective bookkeeping.
    private var switchHit = false
    private var pandaAlive = true
    private var templeDestroyed = false

    /// Shots consumed this stage and the ceiling.
    private var shotsFired = 0
    private let shotLimit: Int
    /// In-flight projectile nodes (a turn resolves when these settle).
    private var activeProjectiles: Set<SCNNode> = []

    private(set) var outcome: TurnOutcome = .ongoing

    enum TurnOutcome { case ongoing, won, lost }

    init(scene: SCNScene, world: GameWorld, ledger: ScoreLedger,
         buffs: BuffState, upgrades: UpgradeState, goal: StageGoal, shotLimit: Int) {
        self.scene = scene
        self.world = world
        self.ledger = ledger
        self.buffs = buffs
        self.upgrades = upgrades
        self.goal = goal
        self.shotLimit = shotLimit
        super.init()
        scene.physicsWorld.contactDelegate = self
    }

    // MARK: - Target registration

    func registerTargets(_ nodes: [SCNNode]) {
        for n in nodes { liveTargets.insert(n) }
    }

    func registerPillar(root: SCNNode) {
        pillarRoots.append(root)
    }

    func registerProjectile(_ node: SCNNode) {
        activeProjectiles.insert(node)
        shotsFired += 1
    }

    // MARK: - Contact delegate

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        // Identify which body is the projectile.
        let (proj, other) = resolvePair(contact)
        guard let projectile = proj, let comp = projectile.projectile else {
            return
        }

        let point = contact.contactPoint
        let worldPoint = SIMD3<Float>(point.x, point.y, point.z)

        // Interactive gadgets fire on contact regardless of impulse (their
        // trigger surfaces barely register a collision force).
        if let other = other, handleMechanism(other, projectile: projectile, comp: comp, at: worldPoint) {
            return
        }

        let impulse = Float(contact.collisionImpulse)
        // Ignore trivial grazes.
        guard impulse > 0.5 || other?.role == .boss || other?.role == .bossShield else { return }

        // Only a real structure hit should detonate. Ground / scenery grazes
        // still deal their bounce accounting but never trigger the blast.
        let hitStructure = other?.role == .structure || (other?.health != nil)

        // First meaningful contact counts as a hit + triggers the ability + blast.
        detonate(comp, projectileNode: projectile, at: worldPoint,
                 blastStructure: hitStructure, force: impulse)

        // Apply direct damage to whatever we hit.
        if let target = other {
            applyDirectDamage(from: comp, impulse: impulse, to: target, at: worldPoint)
        }

        // Bounce accounting for dot tiles hitting the ground/structures.
        if other?.role == .scenery || other?.physicsBody?.categoryBitMask == PhysicsCategory.ground.rawValue {
            handleBounce(projectile, comp)
        }
    }

    /// Fires a tile's on-impact effects exactly once. Invoked both from the real
    /// physics contact callback and from the proximity fuse in `update` — the
    /// latter catches fast tiles that tunnel through a block in a single frame
    /// without the physics engine ever registering the contact.
    private func detonate(_ comp: ProjectileComponent, projectileNode: SCNNode,
                          at point: SIMD3<Float>, blastStructure: Bool, force: Float) {
        guard !comp.hasTriggeredAbility else { return }
        comp.hasTriggeredAbility = true
        ledger.recordHit()
        AudioPulse.shared.play(comp.kind == .redDragon ? .explosion : .hitStone)
        triggerAbility(comp, at: point, projectileNode: projectileNode)
        CannonSignals.shared.emit(.impact(point: point, force: force, kind: comp.kind))

        // Every tile makes a contact blast when it reaches a structure, so one
        // hit clears the blocks stacked below the point of impact — not just the
        // single block it physically touched.
        if blastStructure {
            detonateContactBlast(comp, at: point)
        }
    }

    private func resolvePair(_ contact: SCNPhysicsContact) -> (SCNNode?, SCNNode?) {
        let a = contact.nodeA, b = contact.nodeB
        if a.projectile != nil { return (a, b) }
        if b.projectile != nil { return (b, a) }
        return (nil, nil)
    }

    // MARK: - Mechanisms

    /// Reacts to interactive gadgets. Returns true if the contact was fully
    /// consumed by a mechanism (spring launch, portal teleport) so the normal
    /// damage path is skipped.
    private func handleMechanism(_ node: SCNNode, projectile: SCNNode,
                                 comp: ProjectileComponent, at point: SIMD3<Float>) -> Bool {
        let now = CACurrentMediaTime()
        switch node.role {
        case .spring:
            guard let mech = node.mechanism, now - mech.lastTriggerTime > 0.3 else { return true }
            mech.lastTriggerTime = now
            // Re-launch the tile straight up plus keep some forward carry.
            let body = projectile.physicsBody
            let current = body?.velocity ?? SCNVector3Zero
            let forward = max(Float(current.x), 4)
            body?.velocity = SCNVector3(forward, mech.launchStrength, current.z)
            ParticleForge.burst(ParticleForge.shockRing(color: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)),
                                at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
            AudioPulse.shared.play(.uiTap)
            return true

        case .portalIn:
            guard let mech = node.mechanism, let exit = mech.portalExit,
                  now - mech.lastTriggerTime > 0.5 else { return true }
            mech.lastTriggerTime = now
            // Teleport to the exit, preserving momentum.
            let exitPos = exit.presentation.worldPosition
            projectile.position = SCNVector3(exitPos.x, exitPos.y, exitPos.z)
            ParticleForge.burst(ParticleForge.magnetPulse(),
                                at: exitPos, in: scene.rootNode)
            AudioPulse.shared.play(.combo)
            return true

        case .hammer:
            // The swinging head bats the tile hard along its travel direction.
            let body = projectile.physicsBody
            let v = body?.velocity ?? SCNVector3Zero
            body?.velocity = SCNVector3(-abs(Float(v.x)) - 6, Float(v.y) + 3, Float(v.z))
            AudioPulse.shared.play(.hitStone)
            return true

        case .rope:
            // Severing the rope: drop everything it held.
            severRope(node, at: point)
            return true

        case .tnt:
            detonateTNT(node, at: point)
            return true

        default:
            return false
        }
    }

    private func severRope(_ rope: SCNNode, at point: SIMD3<Float>) {
        guard let mech = rope.mechanism else { return }
        for block in mech.suspendedBlocks {
            block.physicsBody?.type = .dynamic
            // A tiny nudge so they don't hang in perfect equilibrium.
            block.physicsBody?.applyForce(SCNVector3(0.2, -1, 0), asImpulse: true)
        }
        AudioPulse.shared.play(.hitWood)
        rope.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
        rope.mechanism = nil
        evaluateObjective()
    }

    private func detonateTNT(_ barrel: SCNNode, at point: SIMD3<Float>) {
        let pos = barrel.presentation.worldPosition
        let center = SIMD3<Float>(pos.x, pos.y, pos.z)
        ParticleForge.burst(ParticleForge.explosion(radius: 3.5),
                            at: pos, in: scene.rootNode)
        AudioPulse.shared.play(.explosion)
        applyRadialDamage(center: center, radius: 4, baseDamage: 40)
        applyRadialImpulse(center: center, radius: 5, strength: 12)
        barrel.removeFromParentNode()
    }

    // MARK: - Damage

    /// The blast every tile makes where it strikes a structure. Clears blocks
    /// within the tile's contact radius (including those stacked underneath the
    /// impact) with distance falloff, plus a light outward shove for feel.
    private func detonateContactBlast(_ comp: ProjectileComponent, at point: SIMD3<Float>) {
        // Red dragon already fired a bigger explosion via triggerAbility; don't
        // double up its blast.
        guard comp.kind.ability != .explosion else { return }

        let radius = comp.kind.contactBlastRadius
        let damage = comp.kind.contactBlastDamage * buffs.damageScale
            * (comp.critical ? 2 : 1)

        ParticleForge.burst(ParticleForge.explosion(radius: CGFloat(radius) * 0.8),
                            at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
        applyRadialDamage(center: point, radius: radius, baseDamage: damage)
        applyRadialImpulse(center: point, radius: radius, strength: 5)
    }

    private func applyDirectDamage(from comp: ProjectileComponent, impulse: Float,
                                   to target: SCNNode, at point: SIMD3<Float>) {
        var damage = impulse * comp.kind.damageFactor * buffs.damageScale
        if comp.critical { damage *= 2 }

        if target.role == .boss || target.role == .bossShield {
            if let boss = boss {
                let killed = boss.applyDamage(damage)
                ledger.recordDamage(damage)
                if killed { resolveTurn(forceWin: goal == .destroyBoss) }
            }
            return
        }
        if target.role == .objectiveSwitch {
            switchHit = true
            AudioPulse.shared.play(.combo)
            return
        }

        damageStructure(target, amount: damage, at: point)
    }

    private func damageStructure(_ node: SCNNode, amount: Float, at point: SIMD3<Float>) {
        guard let health = node.health else { return }
        ledger.recordDamage(amount)
        let killed = health.apply(amount)
        if killed {
            collapse(node, at: point)
        }
    }

    private func collapse(_ node: SCNNode, at point: SIMD3<Float>) {
        guard liveTargets.contains(node) || node.role == .structure else {
            removeWithDebris(node, at: point)
            return
        }
        let worth = node.health?.coinWorth ?? 10
        liveTargets.remove(node)

        // Track pillar / panda / temple objective specifics.
        if let root = node.parent, pillarRoots.contains(root),
           !root.childNodes.contains(where: { liveTargets.contains($0) }) {
            brokenPillars += 1
        }

        let now = CACurrentMediaTime()
        let award = ledger.recordCollapse(worth: worth, at: now)
        UpgradeVault.shared.awardCoins(award)
        CannonSignals.shared.emit(.structureCollapsed(worth: award, position: point))

        removeWithDebris(node, at: point)
        AudioPulse.shared.play(.hitWood)

        // A collapse may complete the objective mid-flight.
        evaluateObjective()
    }

    private func removeWithDebris(_ node: SCNNode, at point: SIMD3<Float>) {
        let color = (node.geometry?.firstMaterial?.diffuse.contents as? UIImage) != nil
            ? UIColor(white: 0.6, alpha: 1) : UIColor.brown
        ParticleForge.burst(ParticleForge.debris(color: color),
                            at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
        ParticleForge.burst(ParticleForge.smoke(),
                            at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
        node.runAction(.sequence([
            .group([.scale(to: 0.1, duration: 0.25), .fadeOut(duration: 0.25)]),
            .removeFromParentNode()
        ]))
    }

    // MARK: - Abilities

    private func triggerAbility(_ comp: ProjectileComponent, at point: SIMD3<Float>, projectileNode: SCNNode) {
        switch comp.kind.ability {
        case .none:
            break
        case .explosion:
            let radius = 3.0 * upgrades.explosionRadiusMultiplier * buffs.explosionScale
            ParticleForge.burst(ParticleForge.explosion(radius: CGFloat(radius)),
                                at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
            applyRadialDamage(center: point,
                              radius: radius,
                              baseDamage: comp.kind.contactBlastDamage * buffs.damageScale)
            applyRadialImpulse(center: point, radius: radius, strength: 8)
        case .magnetic:
            ParticleForge.burst(ParticleForge.magnetPulse(),
                                at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
            applyRadialImpulse(center: point, radius: 4, strength: -5)  // pull inward
        case .shockwave:
            ParticleForge.burst(ParticleForge.shockRing(color: .white),
                                at: SCNVector3(point.x, point.y, point.z), in: scene.rootNode)
            applyRadialImpulse(center: point, radius: 5, strength: 10)  // push away
        }
    }

    private func applyRadialDamage(center: SIMD3<Float>, radius: Float, baseDamage: Float) {
        for node in liveTargets {
            let p = node.presentation.worldPosition
            let dist = simd_length(SIMD3(p.x, p.y, p.z) - center)
            guard dist < radius else { continue }
            let falloff = 1 - dist / radius
            damageStructure(node, amount: baseDamage * falloff, at: SIMD3(p.x, p.y, p.z))
        }
        if let boss = boss {
            let bp = boss.rig.core.presentation.worldPosition
            let dist = simd_length(SIMD3(bp.x, bp.y, bp.z) - center)
            if dist < radius {
                let killed = boss.applyDamage(baseDamage * (1 - dist / radius))
                if killed { resolveTurn(forceWin: goal == .destroyBoss) }
            }
        }
    }

    private func applyRadialImpulse(center: SIMD3<Float>, radius: Float, strength: Float) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let body = node.physicsBody, body.type == .dynamic else { return }
            let p = node.presentation.worldPosition
            let delta = SIMD3(p.x, p.y, p.z) - center
            let dist = simd_length(delta)
            guard dist < radius, dist > 0.01 else { return }
            let falloff = 1 - dist / radius
            let dir = simd_normalize(delta)
            let force = dir * strength * falloff
            body.applyForce(SCNVector3(force.x, abs(force.y), force.z), asImpulse: true)
        }
    }

    // MARK: - Bounce

    private func handleBounce(_ node: SCNNode, _ comp: ProjectileComponent) {
        guard comp.kind == .dot else {
            if comp.kind != .dot { expireProjectile(node) }
            return
        }
        comp.bounceBudget -= 1
        if comp.bounceBudget < 0 {
            expireProjectile(node)
        }
    }

    // MARK: - Turn / projectile lifecycle

    /// Called from the frame loop; expires settled projectiles and resolves turns.
    func update(now: TimeInterval) {
        ledger.tick(now: now)
        boss?.update(now: now)

        var settled: [SCNNode] = []
        for node in activeProjectiles {
            guard let body = node.physicsBody else { settled.append(node); continue }

            // Proximity fuse: a fast tile can tunnel clean through a block in one
            // frame, so the physics contact never fires. Detonate the instant a
            // still-live tile gets within striking range of any target block.
            checkProximityFuse(node)

            let speed = simd_length(SIMD3(Float(body.velocity.x), Float(body.velocity.y), Float(body.velocity.z)))
            let resting = node.presentation.worldPosition.y < 0.6 && speed < 0.4
            let expiredByTime = now - (node.projectile?.launchTime ?? now) > 8
            if resting || expiredByTime {
                settled.append(node)
            }
        }
        for node in settled {
            expireProjectile(node)
        }

        if !settled.isEmpty {
            resolveTurn(forceWin: false)
        }
    }

    /// Center-to-center distance at which a tile is treated as a hit even if the
    /// physics engine missed the contact. A block is ~1.2 wide and a tile ~0.9,
    /// so surfaces touch around 1.0; a little slack absorbs one frame of travel.
    private let fuseDistance: Float = 1.35

    /// Detonates a still-live in-flight tile the moment it comes within
    /// `fuseDistance` of any live target block. This is what guarantees a visible
    /// hit + blast even when a fast tile passes through a block between frames.
    private func checkProximityFuse(_ node: SCNNode) {
        guard let comp = node.projectile, !comp.hasTriggeredAbility else { return }
        // Give the tile a moment to clear the muzzle before the fuse arms.
        guard CACurrentMediaTime() - comp.launchTime > 0.08 else { return }

        let tp = node.presentation.worldPosition
        let tile = SIMD3<Float>(tp.x, tp.y, tp.z)

        var nearest: SCNNode?
        var nearestDist = fuseDistance
        for target in liveTargets {
            let p = target.presentation.worldPosition
            let d = simd_length(SIMD3(p.x, p.y, p.z) - tile)
            if d < nearestDist {
                nearestDist = d
                nearest = target
            }
        }

        guard let hit = nearest else { return }
        let hp = hit.presentation.worldPosition
        let speed = simd_length(SIMD3(Float(node.physicsBody?.velocity.x ?? 0),
                                      Float(node.physicsBody?.velocity.y ?? 0),
                                      Float(node.physicsBody?.velocity.z ?? 0)))
        detonate(comp, projectileNode: node,
                 at: SIMD3(hp.x, hp.y, hp.z), blastStructure: true, force: max(speed, 4))
    }

    private func expireProjectile(_ node: SCNNode) {
        guard activeProjectiles.contains(node) else { return }
        activeProjectiles.remove(node)
        node.runAction(.sequence([.wait(duration: 1.5), .fadeOut(duration: 0.3), .removeFromParentNode()]))
        CannonSignals.shared.emit(.projectileExpired(remaining: max(0, shotLimit - shotsFired)))
    }

    // MARK: - Objective resolution

    private func evaluateObjective() {
        if outcome != .ongoing { return }
        if objectiveMet() {
            resolveTurn(forceWin: true)
        }
    }

    private func objectiveMet() -> Bool {
        switch goal {
        case .destroyAll, .destroyWithinShots, .oneShotWin:
            return liveTargets.isEmpty
        case .destroyBoss:
            return boss?.isDefeated ?? false
        case .breakPillars(let count):
            return brokenPillars >= count
        case .hitSwitch:
            return switchHit
        case .destroyTemple:
            return liveTargets.isEmpty
        case .savePanda:
            return liveTargets.isEmpty && pandaAlive
        }
    }

    /// Resolves the current turn. Win takes priority (may occur with projectiles
    /// still in flight); otherwise a loss is declared only once all shots are
    /// spent and projectiles have settled.
    func resolveTurn(forceWin: Bool) {
        guard outcome == .ongoing else { return }

        if forceWin || objectiveMet() {
            outcome = .won
            let score = ledger.finalize(now: CACurrentMediaTime(), clearedTargets: true)
            UpgradeVault.shared.awardCoins(score.coins - ledger.coinsEarned) // add completion bonus only
            AudioPulse.shared.play(.victory)
            CannonSignals.shared.emit(.stageCleared(score: score))
            return
        }

        // Loss condition: no shots left and nothing still flying.
        let outOfShots = shotsFired >= shotLimit
        if outOfShots && activeProjectiles.isEmpty {
            // Special-case: panda died => immediate fail is handled elsewhere.
            outcome = .lost
            AudioPulse.shared.play(.defeat)
            CannonSignals.shared.emit(.stageFailed(reason: .outOfShots))
        }
    }

    var shotsRemaining: Int { max(0, shotLimit - shotsFired) }
    var hasProjectilesInFlight: Bool { !activeProjectiles.isEmpty }
}
