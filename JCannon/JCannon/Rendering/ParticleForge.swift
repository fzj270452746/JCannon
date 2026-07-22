//
//  ParticleForge.swift
//  JCannon
//
//  Builds SCNParticleSystems procedurally. Sprite images come from
//  ProceduralTextureCache-style soft dots generated here, so no .sks / .png
//  particle assets are needed.
//

import SceneKit
import UIKit

/// Factory for the handful of particle effects the game uses. Each effect is
/// short-lived and attached to a throwaway node that removes itself.
enum ParticleForge {

    // MARK: - Sprite images (cached)

    private static var spriteCache: [String: UIImage] = [:]

    private static func softDot(color: UIColor, key: String) -> UIImage {
        if let hit = spriteCache[key] { return hit }
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let colors = [color.withAlphaComponent(1).cgColor,
                          color.withAlphaComponent(0).cgColor]
            let space = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                cg.drawRadialGradient(g,
                                      startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                                      endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width / 2,
                                      options: [])
            }
        }
        spriteCache[key] = image
        return image
    }

    // MARK: - Public effects

    /// Fireball burst used by Red Dragon explosions and TNT.
    static func explosion(radius: CGFloat) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = softDot(color: UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1), key: "fire")
        ps.birthRate = 800
        ps.emissionDuration = 0.12
        ps.loops = false
        ps.particleLifeSpan = 0.5
        ps.particleLifeSpanVariation = 0.3
        ps.particleVelocity = CGFloat(6) * radius
        ps.particleVelocityVariation = CGFloat(4) * radius
        ps.spreadingAngle = 180
        ps.particleSize = 0.25 * radius
        ps.particleSizeVariation = 0.15 * radius
        ps.particleColor = UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.1, 0.2, 0, 0.2)
        ps.blendMode = .additive
        ps.emitterShape = SCNSphere(radius: 0.1)
        ps.isAffectedByGravity = false
        return ps
    }

    /// Lingering smoke after a collapse.
    static func smoke() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = softDot(color: UIColor(white: 0.5, alpha: 1), key: "smoke")
        ps.birthRate = 120
        ps.emissionDuration = 0.4
        ps.loops = false
        ps.particleLifeSpan = 1.6
        ps.particleLifeSpanVariation = 0.6
        ps.particleVelocity = 1.2
        ps.particleVelocityVariation = 0.8
        ps.spreadingAngle = 60
        ps.particleSize = 0.4
        ps.particleSizeVariation = 0.2
        ps.acceleration = SCNVector3(0, 1.2, 0)
        ps.particleColor = UIColor(white: 0.55, alpha: 0.7)
        ps.blendMode = .alpha
        ps.emitterShape = SCNSphere(radius: 0.2)
        return ps
    }

    /// Small debris chips for wood/stone breaking.
    static func debris(color: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = softDot(color: color, key: "debris-\(color.hashValue)")
        ps.birthRate = 300
        ps.emissionDuration = 0.08
        ps.loops = false
        ps.particleLifeSpan = 0.8
        ps.particleVelocity = 5
        ps.particleVelocityVariation = 3
        ps.spreadingAngle = 120
        ps.particleSize = 0.12
        ps.particleSizeVariation = 0.08
        ps.particleColor = color
        ps.isAffectedByGravity = true
        ps.particleColorVariation = SCNVector4(0.05, 0.05, 0.05, 0)
        return ps
    }

    /// Expanding shock ring for White Dragon / ground slams.
    static func shockRing(color: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = softDot(color: color, key: "ring-\(color.hashValue)")
        ps.birthRate = 400
        ps.emissionDuration = 0.05
        ps.loops = false
        ps.particleLifeSpan = 0.4
        ps.particleVelocity = 10
        ps.particleVelocityVariation = 1
        ps.spreadingAngle = 5
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.particleSize = 0.2
        ps.particleColor = color
        ps.blendMode = .additive
        ps.isAffectedByGravity = false
        // Emit in a flat disc so it reads as a ground ring.
        let ring = SCNTorus(ringRadius: 0.4, pipeRadius: 0.02)
        ps.emitterShape = ring
        return ps
    }

    /// Magnetic sparkle for Green Dragon pulses.
    static func magnetPulse() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = softDot(color: UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1), key: "magnet")
        ps.birthRate = 250
        ps.emissionDuration = 0.2
        ps.loops = false
        ps.particleLifeSpan = 0.6
        ps.particleVelocity = 2
        ps.spreadingAngle = 180
        ps.particleSize = 0.15
        ps.particleColor = UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1)
        ps.blendMode = .additive
        ps.acceleration = SCNVector3(0, -2, 0)
        ps.isAffectedByGravity = false
        return ps
    }

    /// Attaches a one-shot system at a world position and auto-removes the host node.
    @discardableResult
    static func burst(_ system: SCNParticleSystem, at position: SCNVector3, in parent: SCNNode) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.addParticleSystem(system)
        parent.addChildNode(node)
        let life = TimeInterval(system.particleLifeSpan + system.emissionDuration + 0.5)
        node.runAction(.sequence([.wait(duration: life), .removeFromParentNode()]))
        return node
    }
}
