//
//  CannonSignals.swift
//  JCannon
//
//  Lightweight typed event bus. Replaces NotificationCenter across the project
//  so gameplay, rendering and UI stay decoupled without string-keyed posts.
//

import Foundation

/// Every gameplay-relevant event flows through `CannonSignals`. Payloads are
/// value types so subscribers never hold onto scene-graph references by accident.
enum CannonEvent {
    case tileLaunched(kind: TileKind, shotsLeft: Int)
    case impact(point: SIMD3<Float>, force: Float, kind: TileKind)
    case structureCollapsed(worth: Int, position: SIMD3<Float>)
    case comboChanged(chain: Int, multiplier: Int)
    case coinsChanged(total: Int)
    case bossDamaged(current: Int, max: Int)
    case bossPhaseChanged(phase: Int, total: Int)
    case buffGranted(buff: BuffKind)
    case projectileExpired(remaining: Int)
    case windChanged(vector: SIMD3<Float>)
    case powerCharging(normalized: Float)
    case angleAdjusted(degrees: Float)
    case stageCleared(score: StageScore)
    case stageFailed(reason: FailureReason)
    case achievementUnlocked(title: String)
    case codexEntryUnlocked(title: String)
}

enum FailureReason {
    case outOfShots
    case timeExpired
    case abandoned
}

/// A minimal broadcast hub. Handlers are keyed by an opaque token so callers can
/// unsubscribe deterministically (e.g. when a scene tears down).
final class CannonSignals {

    static let shared = CannonSignals()

    private var handlers: [UUID: (CannonEvent) -> Void] = [:]

    private init() {}

    @discardableResult
    func subscribe(_ handler: @escaping (CannonEvent) -> Void) -> UUID {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func unsubscribe(_ token: UUID) {
        handlers.removeValue(forKey: token)
    }

    func emit(_ event: CannonEvent) {
        // Snapshot to tolerate handlers that unsubscribe during dispatch.
        for handler in handlers.values {
            handler(event)
        }
    }

    /// Clears every subscription. Used when returning to the menu / reloading a stage.
    func reset() {
        handlers.removeAll()
    }
}
