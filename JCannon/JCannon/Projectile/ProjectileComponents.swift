//
//  ProjectileComponents.swift
//  JCannon
//
//  Lightweight ECS-style components attached to nodes via userData. Behaviour is
//  composed from these rather than a deep class hierarchy — a tile node carries a
//  LaunchComponent + BounceComponent + AbilityComponent as needed.
//

import SceneKit

// MARK: - Protocols (Protocol First)

/// A node that can be fired from the launcher.
protocol Launchable {
    var tileKind: TileKind { get }
}

/// A node that can take damage and possibly break.
protocol DamageReceiver: AnyObject {
    func receiveDamage(_ amount: Float, at point: SIMD3<Float>)
    var isDestroyed: Bool { get }
}

/// A node that contributes to the stage objective when destroyed.
protocol ObjectiveContributor {
    var objectiveWorth: Int { get }
}

// MARK: - Components

/// Marks a node as an in-flight projectile and tracks its remaining abilities.
final class ProjectileComponent {
    let kind: TileKind
    var bounceBudget: Int
    var hasTriggeredAbility = false
    var critical: Bool
    var launchTime: TimeInterval

    init(kind: TileKind, bounceBudget: Int, critical: Bool, launchTime: TimeInterval) {
        self.kind = kind
        self.bounceBudget = bounceBudget
        self.critical = critical
        self.launchTime = launchTime
    }
}

/// Per-mechanism configuration attached to trap / gadget nodes. Lets the relay
/// react to a spring / portal / rope without hard-coding node lookups.
final class MechanismComponent {
    /// Bounce/launch strength for springs.
    var launchStrength: Float = 0
    /// The paired portal exit node (portalIn only).
    weak var portalExit: SCNNode?
    /// Nodes this rope holds up; when the rope breaks they turn dynamic.
    var suspendedBlocks: [SCNNode] = []
    /// Debounce so a portal/spring doesn't retrigger every frame.
    var lastTriggerTime: TimeInterval = -100

    init() {}
}

/// Health + break threshold for structures and bosses.
final class HealthComponent {
    var current: Float
    let max: Float
    let coinWorth: Int

    init(max: Float, coinWorth: Int) {
        self.current = max
        self.max = max
        self.coinWorth = coinWorth
    }

    var normalized: Float { Swift.max(0, current / max) }
    var isDead: Bool { current <= 0 }

    /// Returns true if this hit killed the component.
    func apply(_ amount: Float) -> Bool {
        current -= amount
        return isDead
    }
}

/// Attaches typed components to an SCNNode without subclassing. Backed by
/// Objective-C associated objects so components travel with the node through the
/// scene graph without relying on the KVC-bridged `userData` dictionary.
private enum ComponentKeys {
    static var projectile: UInt8 = 0
    static var health: UInt8 = 0
    static var role: UInt8 = 0
    static var mechanism: UInt8 = 0
}

extension SCNNode {

    var projectile: ProjectileComponent? {
        get { objc_getAssociatedObject(self, &ComponentKeys.projectile) as? ProjectileComponent }
        set { objc_setAssociatedObject(self, &ComponentKeys.projectile, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var health: HealthComponent? {
        get { objc_getAssociatedObject(self, &ComponentKeys.health) as? HealthComponent }
        set { objc_setAssociatedObject(self, &ComponentKeys.health, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var mechanism: MechanismComponent? {
        get { objc_getAssociatedObject(self, &ComponentKeys.mechanism) as? MechanismComponent }
        set { objc_setAssociatedObject(self, &ComponentKeys.mechanism, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Semantic tag used by the relay to branch collision handling.
    var role: NodeRole {
        get { (objc_getAssociatedObject(self, &ComponentKeys.role) as? String).flatMap(NodeRole.init) ?? .scenery }
        set { objc_setAssociatedObject(self, &ComponentKeys.role, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

/// High-level role of a node for collision routing.
enum NodeRole: String {
    case scenery
    case projectile
    case structure
    case boss
    case bossShield
    case tnt
    case spring
    case hammer
    case portalIn
    case portalOut
    case rope
    case ice
    case objectiveSwitch
    case panda
}
