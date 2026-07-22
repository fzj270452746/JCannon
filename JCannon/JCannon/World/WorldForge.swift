//
//  WorldForge.swift
//  JCannon
//
//  Assembles the single SCNScene: camera, lights, ground, sky, wind field and
//  launcher. Gameplay systems attach to the world it returns — no rendering
//  logic leaks into gameplay code.
//

import SceneKit
import UIKit

/// The assembled play world handed to the gameplay layer.
final class GameWorld {
    let scene: SCNScene
    let cameraNode: SCNNode
    let launcher: Launcher
    let wind: WindField
    let groundNode: SCNNode
    let theme: BiomeTheme
    /// Container for all spawned structures / boss / mechanisms.
    let stageRoot: SCNNode

    init(scene: SCNScene, cameraNode: SCNNode, launcher: Launcher,
         wind: WindField, groundNode: SCNNode, theme: BiomeTheme, stageRoot: SCNNode) {
        self.scene = scene
        self.cameraNode = cameraNode
        self.launcher = launcher
        self.wind = wind
        self.groundNode = groundNode
        self.theme = theme
        self.stageRoot = stageRoot
    }
}

enum WorldForge {

    static func build(theme: BiomeTheme) -> GameWorld {
        let scene = SCNScene()
        scene.background.contents = SkyBuilder.background(for: theme)

        // Distance fog for depth in stylised scenes.
        scene.fogColor = theme.fogColor
        scene.fogStartDistance = 40
        scene.fogEndDistance = 130
        scene.fogDensityExponent = 2

        let stageRoot = SCNNode()
        stageRoot.name = "stageRoot"
        scene.rootNode.addChildNode(stageRoot)

        installCamera(in: scene)
        let camera = scene.rootNode.childNode(withName: "camera", recursively: false)!
        installLights(in: scene, theme: theme)
        let ground = installGround(in: scene, theme: theme)

        // Wind field.
        let wind = WindField()
        scene.rootNode.addChildNode(wind.node)

        // Launcher on the left, tiles fly toward +X.
        let launcher = LauncherBuilder.build(at: SCNVector3(-9, 0, 0))
        scene.rootNode.addChildNode(launcher.root)

        return GameWorld(scene: scene, cameraNode: camera, launcher: launcher,
                         wind: wind, groundNode: ground, theme: theme, stageRoot: stageRoot)
    }

    // MARK: - Camera

    private static func installCamera(in scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 300
        cam.wantsHDR = true

        let node = SCNNode()
        node.name = "camera"
        node.camera = cam
        // Side-on framing of the play field, slightly elevated.
        node.position = SCNVector3(2, 6, 22)
        node.eulerAngles = SCNVector3(-0.12, 0, 0)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Lights

    private static func installLights(in scene: SCNScene, theme: BiomeTheme) {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1100
        sun.color = theme.accentLight
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 4
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 450
        ambient.color = UIColor(white: 0.9, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: - Ground

    private static func installGround(in scene: SCNScene, theme: BiomeTheme) -> SCNNode {
        let floor = SCNFloor()
        floor.reflectivity = theme == .snow ? 0.15 : 0.05
        let mat = SCNMaterial()
        let tex = ProceduralTextureCache.shared.image(.ground(theme))
        mat.diffuse.contents = tex
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(20, 20, 1)
        mat.lightingModel = .physicallyBased
        floor.materials = [mat]

        let node = SCNNode(geometry: floor)
        node.name = "ground"
        node.role = .scenery
        let body = SCNPhysicsBody(type: .static, shape: nil)
        body.categoryBitMask = PhysicsCategory.ground.rawValue
        body.contactTestBitMask = PhysicsCategory.projectile.rawValue
        body.friction = 0.9
        body.restitution = 0.1
        node.physicsBody = body
        scene.rootNode.addChildNode(node)
        return node
    }
}
