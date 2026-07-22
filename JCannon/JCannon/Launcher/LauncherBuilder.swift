//
//  LauncherBuilder.swift
//  JCannon
//
//  Builds the cannon from a cylinder base + cone barrel. Exposes a `muzzleTip`
//  child node so the firing code reads the real world-space muzzle position at
//  runtime instead of hard-coding launch coordinates.
//

import SceneKit
import UIKit

/// The assembled launcher plus the pivot node that aims the barrel.
struct Launcher {
    let root: SCNNode
    /// Rotating around its Z axis changes launch angle.
    let barrelPivot: SCNNode
    /// Empty node at the very end of the barrel; its world transform is the spawn point.
    let muzzleTip: SCNNode

    /// Sets the launch angle (degrees above horizontal, 20…85).
    func setAngle(degrees: Float) {
        let clamped = min(max(degrees, 20), 85)
        // Barrel points +X by default; rotate about Z so higher angle tips it up.
        barrelPivot.eulerAngles.z = clamped * .pi / 180
    }

    /// World-space muzzle position, evaluated live from the scene graph.
    var muzzleWorldPosition: SCNVector3 {
        muzzleTip.presentation.worldPosition
    }

    /// World-space firing direction (unit vector) from the barrel orientation.
    var fireDirection: SIMD3<Float> {
        let world = muzzleTip.presentation.worldTransform
        // The barrel's local +X axis mapped into world space.
        let dir = SIMD3<Float>(world.m11, world.m12, world.m13)
        return simd_normalize(dir)
    }
}

enum LauncherBuilder {

    static func build(at position: SCNVector3) -> Launcher {
        let root = SCNNode()
        root.position = position
        root.name = "launcher"

        // Base — a squat cylinder.
        let base = SCNCylinder(radius: 1.4, height: 0.9)
        base.materials = [metal()]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(baseNode)

        // Pivot around which the barrel rotates.
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 1.25, 0)
        root.addChildNode(pivot)

        // Barrel — a cone laid on its side, tip pointing +X.
        let barrel = SCNCone(topRadius: 0.30, bottomRadius: 0.68, height: 3.2)
        barrel.materials = [metal(), metalDark(), metal()]
        let barrelNode = SCNNode(geometry: barrel)
        // Cone's height axis is +Y; rotate -90° about Z so the tip faces +X.
        barrelNode.eulerAngles.z = -.pi / 2
        barrelNode.position = SCNVector3(1.6, 0, 0)
        pivot.addChildNode(barrelNode)

        // Muzzle tip marker at the wide open end (+X from pivot).
        let muzzle = SCNNode()
        muzzle.position = SCNVector3(3.2, 0, 0)
        pivot.addChildNode(muzzle)

        // Decorative rim ring.
        let ring = SCNTorus(ringRadius: 0.68, pipeRadius: 0.10)
        ring.materials = [gold()]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.z = .pi / 2
        ringNode.position = SCNVector3(3.05, 0, 0)
        pivot.addChildNode(ringNode)

        let launcher = Launcher(root: root, barrelPivot: pivot, muzzleTip: muzzle)
        launcher.setAngle(degrees: 45)
        return launcher
    }

    // MARK: - Materials

    private static func metal() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = ProceduralTextureCache.shared.image(.metal)
        m.metalness.contents = 0.8
        m.roughness.contents = 0.3
        m.lightingModel = .physicallyBased
        return m
    }

    private static func metalDark() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        m.metalness.contents = 0.9
        m.roughness.contents = 0.4
        m.lightingModel = .physicallyBased
        return m
    }

    private static func gold() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = ProceduralTextureCache.shared.image(.gold)
        m.metalness.contents = 1.0
        m.roughness.contents = 0.2
        m.lightingModel = .physicallyBased
        return m
    }
}
