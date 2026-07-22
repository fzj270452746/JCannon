//
//  WindField.swift
//  JCannon
//
//  Wind is a real SCNPhysicsField, not a coordinate hack. Each stage seeds a
//  horizontal wind vector that continuously nudges in-flight projectiles.
//

import SceneKit

/// Owns the physics field node and the current wind vector.
final class WindField {

    let node: SCNNode
    private let field: SCNPhysicsField
    private(set) var vector: SIMD3<Float> = .zero

    init() {
        // A linear-gravity-style field applies a constant force in a direction.
        let f = SCNPhysicsField.linearGravity()
        f.strength = 0
        f.categoryBitMask = PhysicsCategory.projectile.rawValue
        self.field = f
        let n = SCNNode()
        n.physicsField = f
        // Cover the whole play area.
        f.halfExtent = SCNVector3(100, 100, 100)
        self.node = n
    }

    /// Applies a seeded wind vector. `speed` is m/s along X (sign = direction).
    func configure(from seed: UInt64) {
        var rng = SeededRandom(seed: seed, tag: "wind")
        let speed = rng.float(in: -3...3)
        setWind(SIMD3<Float>(speed, 0, 0))
    }

    func setWind(_ v: SIMD3<Float>) {
        vector = v
        let magnitude = simd_length(v)
        if magnitude < 0.001 {
            field.strength = 0
            return
        }
        field.direction = SCNVector3(v.x, v.y, v.z)
        // Scale into a force that visibly bends light tiles but not heavy ones.
        field.strength = CGFloat(magnitude) * 1.4
        CannonSignals.shared.emit(.windChanged(vector: v))
    }

    /// Temporarily disables wind (Wind Ignore buff).
    func setIgnored(_ ignored: Bool) {
        field.strength = ignored ? 0 : CGFloat(simd_length(vector)) * 1.4
    }

    /// HUD-facing description, e.g. "← 2.1".
    var readout: (arrow: String, speed: Float) {
        let arrow = vector.x < 0 ? "←" : "→"
        return (arrow, abs(vector.x))
    }
}
