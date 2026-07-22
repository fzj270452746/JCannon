//
//  ViewController.swift
//  JCannon
//
//  The gameplay host. Assembles the world for the current stage, wires single-
//  finger controls (left-drag = angle, right long-press = power), fires tiles
//  with velocity, previews the trajectory, and drives the HUD from CannonSignals.
//
//  Rendering, physics and progression all live in their own layers — this file
//  only orchestrates them.
//

import UIKit
import SceneKit
import SpriteKit

final class ViewController: UIViewController {

    // Scene
    private var sceneView: SCNView!
    private var hud: HUDOverlay!
    private var world: GameWorld!
    private var relay: PhysicsRelay!
    private var boss: BossController?

    // Current stage state
    private var blueprint: StageBlueprint!
    private var ledger: ScoreLedger!
    private var buffs = BuffState()
    private var upgrades = UpgradeState.baseline
    private var stageIndex = 1

    // Mode configuration (set before presentation).
    var mode: GameMode = .campaign
    var startStageIndex = 1
    private var endlessRound = 0
    /// Sandbox lets the player freely choose ammo without win/loss pressure.
    private var sandboxAmmo: [TileKind] = TileKind.allCases
    /// Called when a session wants to return to the menu.
    var onExitToMenu: (() -> Void)?

    // Control state
    private var currentAngle: Float = 45
    private var isCharging = false
    private var chargeStart: TimeInterval = 0
    private var chargeNormalized: Float = 0
    private var selectedTile: TileKind = .wan
    private var trajectoryNode: SCNNode?

    // Event subscription
    private var signalToken: UUID?

    // Tunables
    private let minLaunchSpeed: Float = 14
    private let maxLaunchSpeed: Float = 34
    private let maxChargeDuration: TimeInterval = 1.2

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        AudioPulse.shared.boot()
        upgrades = UpgradeVault.shared.resolvedState()
        setupSceneView()
        subscribeSignals()
        startSession()
    }

    /// Kicks off the first stage appropriate to the configured mode.
    private func startSession() {
        switch mode {
        case .campaign:
            loadStage(index: startStageIndex)
        case .endless:
            endlessRound = 0
            loadStage(index: 1_000)          // 1000+ => endless procedural band
        case .daily:
            loadDaily()
        case .sandbox:
            loadStage(index: 1)              // any base; sandbox ignores objective
        }
    }

    override var prefersStatusBarHidden: Bool { true }

    // The play field is laid out horizontally (launcher on the left, tiles fly
    // toward +X), so the game must run in landscape to keep the mahjong tiles on
    // screen. Menus stay portrait; only this screen forces landscape.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }


    deinit {
        if let token = signalToken { CannonSignals.shared.unsubscribe(token) }
    }

    // MARK: - Setup

    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.antialiasingMode = .multisampling2X
        sceneView.isPlaying = true
        sceneView.rendersContinuously = true
        sceneView.delegate = self
        view.addSubview(sceneView)

        hud = HUDOverlay(size: view.bounds.size)
        hud.onPauseTapped = { [weak self] in self?.togglePause() }
        sceneView.overlaySKScene = hud

        // Controls: left half drags angle, right half charges power.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        sceneView.addGestureRecognizer(pan)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0.01
        press.delegate = self
        sceneView.addGestureRecognizer(press)
        // Tap on ammo strip handled via a separate tap recognizer.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        sceneView.addGestureRecognizer(tap)
    }

    private func subscribeSignals() {
        signalToken = CannonSignals.shared.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - Stage loading

    private func loadStage(index: Int) {
        stageIndex = index
        install(blueprint: StageVault.blueprint(for: index))
    }

    /// Loads today's daily challenge.
    private func loadDaily() {
        stageIndex = -1
        install(blueprint: StageVault.dailyChallenge())
    }

    /// Shared world-assembly core used by every mode.
    private func install(blueprint bp: StageBlueprint) {
        hud.clearResult()
        blueprint = bp
        buffs = BuffState()
        rollBuff()

        upgrades = UpgradeVault.shared.resolvedState()

        world = WorldForge.build(theme: blueprint.theme)
        sceneView.scene = world.scene

        // Wind: explicit override or seed-derived.
        if let ws = blueprint.windSpeed {
            world.wind.setWind(SIMD3<Float>(ws, 0, 0))
        } else {
            world.wind.configure(from: SeedVault.stage(stageIndex))
        }
        if buffs.windIgnore { world.wind.setIgnored(true) }

        // Sandbox has no shot limit or fail pressure — give a generous pool.
        let shotLimit = mode == .sandbox ? 999 : blueprint.shots

        ledger = ScoreLedger(totalShots: shotLimit,
                             buffCoinScale: buffs.coinScale,
                             startTime: CACurrentMediaTime())

        relay = PhysicsRelay(scene: world.scene, world: world, ledger: ledger,
                             buffs: buffs, upgrades: upgrades,
                             goal: blueprint.goal, shotLimit: shotLimit)

        populateStage()
        configureAmmo()
        refreshHUD()

        currentAngle = 45
        world.launcher.setAngle(degrees: currentAngle)
        let banner = mode == .sandbox ? "SANDBOX" : "READY"
        hud.flashBanner(banner, color: .white)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.hud.hideBanner()
            self?.updateTrajectoryPreview()
        }
    }

    private func populateStage() {
        var allBreakables: [SCNNode] = []

        for placement in blueprint.structures {
            let built = StructureBuilder.build(placement.kind,
                                               at: placement.position,
                                               seed: SeedVault.stage(stageIndex) &+ UInt64(placement.x * 100))
            world.stageRoot.addChildNode(built.root)
            allBreakables.append(contentsOf: built.breakables)
            if placement.kind == .dragonPillar {
                relay.registerPillar(root: built.root)
            }
            CodexVault.shared.discoverStructure(placement.kind)
        }

        // Unlock codex entries for the ammo and gadgets this stage introduces.
        blueprint.ammo.forEach { CodexVault.shared.discoverTile($0) }
        blueprint.gadgets.forEach { CodexVault.shared.discoverMechanism($0.kind) }

        // Objective-specific mechanisms.
        switch blueprint.goal {
        case .hitSwitch:
            let sw = MechanismBuilder.switchTarget(at: SCNVector3(9, 3.5, 0))
            world.stageRoot.addChildNode(sw)
        case .savePanda:
            let panda = MechanismBuilder.panda(at: SCNVector3(6, 0.7, 0))
            world.stageRoot.addChildNode(panda)
        default:
            break
        }

        // Interactive gadgets from the blueprint.
        placeMechanisms(breakables: &allBreakables)

        relay.registerTargets(allBreakables)

        // Boss.
        if blueprint.hasBoss, let hp = blueprint.bossHP {
            let rig = BossBuilder.build(at: SCNVector3(10, 0, 0), hp: hp)
            world.stageRoot.addChildNode(rig.root)
            let controller = BossController(rig: rig, scene: world.scene)
            self.boss = controller
            relay.boss = controller
            hud.installBossBar()
            CodexVault.shared.discoverBoss()
        }
    }

    /// Instantiates the blueprint's mechanisms. A rope adds its own suspended
    /// blocks to the breakable set so the objective can still be satisfied.
    private func placeMechanisms(breakables: inout [SCNNode]) {
        for gadget in blueprint.gadgets {
            switch gadget.kind {
            case .spring:
                world.stageRoot.addChildNode(MechanismBuilder.spring(at: gadget.position))
            case .swingHammer:
                world.stageRoot.addChildNode(MechanismBuilder.swingHammer(at: gadget.position))
            case .ice:
                world.stageRoot.addChildNode(MechanismBuilder.icePatch(at: gadget.position))
            case .tnt:
                world.stageRoot.addChildNode(MechanismBuilder.tntBarrel(at: gadget.position))
            case .portal:
                let pair = MechanismBuilder.portalPair(entry: gadget.position, exit: gadget.exitPosition)
                world.stageRoot.addChildNode(pair.entry)
                world.stageRoot.addChildNode(pair.exit)
            case .rope:
                // The rope holds a couple of stone blocks that count as targets.
                var held: [SCNNode] = []
                let built = StructureBuilder.build(.stoneTower, at: SCNVector3(gadget.x, gadget.y + 2.5, gadget.z),
                                                   seed: SeedVault.stage(stageIndex) &+ 999)
                world.stageRoot.addChildNode(built.root)
                for block in built.breakables { block.physicsBody?.type = .static }
                held.append(contentsOf: built.breakables)
                breakables.append(contentsOf: built.breakables)
                world.stageRoot.addChildNode(MechanismBuilder.rope(at: gadget.position, holding: held))
            }
        }
    }

    /// The tiles offered this session — every kind in sandbox, else the
    /// blueprint's curated set.
    private var activeAmmo: [TileKind] {
        mode == .sandbox ? TileKind.allCases : blueprint.ammo
    }

    private func configureAmmo() {
        selectedTile = activeAmmo.first ?? .wan
    }

    private func rollBuff() {
        var rng = SeededRandom(seed: SeedVault.stage(stageIndex), tag: "buff")
        // 60% chance to grant one buff for the run.
        if rng.chance(0.6) {
            let buff = rng.pick(BuffKind.allCases)
            buffs.apply(buff)
            CannonSignals.shared.emit(.buffGranted(buff: buff))
        }
    }

    // MARK: - HUD

    private func refreshHUD() {
        hud.setLevel(blueprint.index)
        hud.setGoal(blueprint.goal.label)
        hud.setCoins(UpgradeVault.shared.coins)
        hud.setShots(relay.shotsRemaining)
        hud.setAngle(currentAngle)
        let wind = world.wind.readout
        hud.setWind(arrow: wind.arrow, speed: wind.speed)
        if boss != nil, let h = boss?.rig.core.health {
            hud.setBossHealth(normalized: h.normalized)
        }
    }

    // MARK: - Controls

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        // Only the left half of the screen adjusts angle.
        let start = gr.location(in: sceneView)
        guard start.x < view.bounds.width * 0.5 else { return }
        let translation = gr.translation(in: sceneView)
        // Dragging up increases angle.
        let delta = Float(-translation.y) * 0.2
        currentAngle = min(max(currentAngle + delta, 20), 85)
        gr.setTranslation(.zero, in: sceneView)
        world.launcher.setAngle(degrees: currentAngle)
        hud.setAngle(currentAngle)
        CannonSignals.shared.emit(.angleAdjusted(degrees: currentAngle))
        updateTrajectoryPreview()
    }

    @objc private func handlePress(_ gr: UILongPressGestureRecognizer) {
        // Right half charges + releases to fire.
        let loc = gr.location(in: sceneView)
        switch gr.state {
        case .began:
            guard loc.x >= view.bounds.width * 0.5 else { return }
            beginCharge()
        case .changed:
            break
        case .ended, .cancelled:
            if isCharging { releaseFire() }
        default:
            break
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        // Tapping the top-right area cycles ammo.
        let loc = gr.location(in: sceneView)
        if loc.y < 90 && loc.x > view.bounds.width * 0.5 {
            cycleAmmo()
        }
    }

    private func cycleAmmo() {
        let ammo = activeAmmo
        guard let idx = ammo.firstIndex(of: selectedTile) else {
            selectedTile = ammo.first ?? .wan
            return
        }
        selectedTile = ammo[(idx + 1) % ammo.count]
        AudioPulse.shared.play(.uiTap)
        hud.setGoal("\(blueprint.goal.label)  •  \(selectedTile.displayName)")
    }

    // MARK: - Charge / fire

    private func beginCharge() {
        guard relay.outcome == .ongoing, relay.shotsRemaining > 0 else { return }
        isCharging = true
        chargeStart = CACurrentMediaTime()
    }

    private func releaseFire() {
        isCharging = false
        let held = CACurrentMediaTime() - chargeStart
        chargeNormalized = Float(min(held / maxChargeDuration, 1))
        hud.setPower(0, visible: false)
        launchTile(power: chargeNormalized)
    }

    private func launchTile(power: Float) {
        guard relay.outcome == .ongoing, relay.shotsRemaining > 0 else { return }

        var rng = SeededRandom(seed: SeedVault.stage(stageIndex) &+ UInt64(ledger.shotsFired), tag: "crit")
        let critical = rng.chance(upgrades.criticalChance)

        let tile = TileForge.makeTile(kind: selectedTile, upgrades: upgrades,
                                      critical: critical, now: CACurrentMediaTime())

        // Spawn at the live muzzle position/direction read from the scene graph.
        let muzzle = world.launcher.muzzleWorldPosition
        tile.position = muzzle
        world.scene.rootNode.addChildNode(tile)

        let dir = world.launcher.fireDirection
        let speedBoost = upgrades.launchSpeedMultiplier * buffs.timeScale.magnitude.squareRoot().magnitude
        let speed = (minLaunchSpeed + (maxLaunchSpeed - minLaunchSpeed) * power) * upgrades.launchSpeedMultiplier
        let velocity = dir * speed
        tile.physicsBody?.velocity = SCNVector3(velocity.x, velocity.y, velocity.z)
        tile.physicsBody?.applyTorque(SCNVector4(0, 0, 1, Double(speed) * 0.3), asImpulse: true)
        _ = speedBoost

        relay.registerProjectile(tile)
        AudioPulse.shared.play(.launch)
        CannonSignals.shared.emit(.tileLaunched(kind: selectedTile, shotsLeft: relay.shotsRemaining))

        // Slow-motion buff.
        world.scene.physicsWorld.speed = CGFloat(buffs.timeScale)

        clearTrajectoryPreview()
        hud.setShots(relay.shotsRemaining)
    }

    // MARK: - Trajectory preview

    private func updateTrajectoryPreview() {
        guard blueprint != nil else { return }
        clearTrajectoryPreview()
        // Only show the dotted arc when laser sight buff is active or always for aiming aid.
        let container = SCNNode()
        let origin = world.launcher.muzzleWorldPosition
        let dir = world.launcher.fireDirection
        let previewSpeed = (minLaunchSpeed + maxLaunchSpeed) * 0.5 * upgrades.launchSpeedMultiplier
        var velocity = dir * previewSpeed
        var pos = SIMD3<Float>(origin.x, origin.y, origin.z)
        let gravity = SIMD3<Float>(0, -9.8, 0)
        let dt: Float = 0.08
        let dotCount = buffs.laserSight ? 30 : 16

        for i in 0..<dotCount {
            pos += velocity * dt
            velocity += gravity * dt
            velocity += world.wind.vector * dt * 0.1
            if pos.y < 0.2 { break }
            let dot = SCNSphere(radius: 0.08)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 1, alpha: 0.7)
            m.emission.contents = UIColor.white
            dot.materials = [m]
            let node = SCNNode(geometry: dot)
            node.position = SCNVector3(pos.x, pos.y, pos.z)
            node.opacity = CGFloat(1 - Float(i) / Float(dotCount))
            container.addChildNode(node)
        }
        world.scene.rootNode.addChildNode(container)
        trajectoryNode = container
    }

    private func clearTrajectoryPreview() {
        trajectoryNode?.removeFromParentNode()
        trajectoryNode = nil
    }

    // MARK: - Pause

    private func togglePause() {
        let paused = sceneView.scene?.isPaused ?? false
        if paused {
            resumeGame()
        } else {
            pauseGame()
        }
    }

    /// Pause the scene and offer resume / return-to-menu choices.
    private func pauseGame() {
        guard sceneView.scene?.isPaused == false else { return }
        sceneView.scene?.isPaused = true
        hud.flashBanner("PAUSED", color: .white)

        let sheet = UIAlertController(title: "PAUSED", message: nil, preferredStyle: .alert)
        sheet.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
            self?.resumeGame()
        })
        sheet.addAction(UIAlertAction(title: "Quit to Menu", style: .destructive) { [weak self] _ in
            self?.exitToMenu()
        })
        present(sheet, animated: true)
    }

    private func resumeGame() {
        sceneView.scene?.isPaused = false
        hud.hideBanner()
    }

    /// Leave the current session and hand control back to the menu.
    private func exitToMenu() {
        sceneView.scene?.isPaused = false
        AudioPulse.shared.play(.uiTap)
        onExitToMenu?()
    }

    // MARK: - Event handling

    private func handle(_ event: CannonEvent) {
        switch event {
        case .coinsChanged(let total):
            hud.setCoins(total)
        case .comboChanged(let chain, let mult):
            hud.showCombo(chain: chain, multiplier: mult)
            if chain >= 2 { AudioPulse.shared.play(.combo) }
        case .windChanged(let v):
            hud.setWind(arrow: v.x < 0 ? "←" : "→", speed: abs(v.x))
        case .bossDamaged(let cur, let mx):
            hud.setBossHealth(normalized: mx > 0 ? Float(cur) / Float(mx) : 0)
        case .bossPhaseChanged(let phase, let total):
            hud.setBossPhase(phase, total: total)
        case .projectileExpired(let remaining):
            hud.setShots(remaining)
        case .stageCleared(let score):
            presentResult(victory: true, score: score)
        case .stageFailed:
            presentResult(victory: false, score: nil)
        case .buffGranted(let buff):
            hud.flashBanner(buff.displayName, color: SKColor(red: 0.4, green: 0.9, blue: 1, alpha: 1))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if self?.relay.outcome == .ongoing { self?.hud.hideBanner() }
            }
        case .achievementUnlocked(let title):
            hud.showToast("ACHIEVEMENT\n\(title)", color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1))
        case .codexEntryUnlocked(let title):
            hud.showToast("NEW CODEX\n\(title)", color: SKColor(red: 0.5, green: 0.85, blue: 1, alpha: 1))
        default:
            break
        }
    }

    private func presentResult(victory: Bool, score: StageScore?) {
        hud.showResult(victory: victory, stars: score?.stars ?? 0)
        world.scene.physicsWorld.speed = 1

        if victory {
            // Achievement / codex bookkeeping on a win.
            if blueprint.hasBoss { AchievementVault.shared.recordBossDefeat() }
            if let s = score { AchievementVault.shared.recordCoinsEarned(s.coins) }
            // Persist per-mode records.
            switch mode {
            case .campaign:
                if let s = score {
                    ScoreVault.shared.recordStage(index: stageIndex, stars: s.stars, coins: s.coins)
                }
            case .daily:
                if let s = score {
                    ScoreVault.shared.recordDaily(dayKey: Self.todayKey(), coins: s.coins, stars: s.stars)
                }
            case .endless, .sandbox:
                break
            }
        }

        advanceAfterResult(victory: victory, score: score)
    }

    /// Mode-aware progression once the result banner has shown.
    private func advanceAfterResult(victory: Bool, score: StageScore?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .campaign:
                if victory {
                    let next = min(self.stageIndex + 1, StageVault.campaignLength)
                    self.loadStage(index: next)
                } else {
                    self.loadStage(index: self.stageIndex)
                }
            case .endless:
                if victory {
                    self.endlessRound += 1
                    ScoreVault.shared.recordEndless(round: self.endlessRound)
                    self.loadStage(index: 1_000 + self.endlessRound)
                } else {
                    self.onExitToMenu?()
                }
            case .daily:
                self.onExitToMenu?()
            case .sandbox:
                // Sandbox never really "ends"; reload the same playground.
                self.loadStage(index: self.stageIndex)
            }
        }
    }

    /// yyyymmdd key for today, used to dedupe daily-challenge records.
    static func todayKey() -> Int {
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    }
}

// MARK: - Frame loop

extension ViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Drive charging visuals and the relay's per-frame resolution off the
        // render loop so timing tracks the display.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.relay != nil else { return }
            if self.isCharging {
                let held = time - self.chargeStart
                let normalized = Float(min(held / self.maxChargeDuration, 1))
                self.hud.setPower(normalized, visible: true)
            }
            self.relay.update(now: time)
        }
    }
}

// MARK: - Gesture coordination

extension ViewController: UIGestureRecognizerDelegate {
    // The angle-drag (left half) and the charge long-press (right half) each own
    // half the screen, so they must be allowed to recognise simultaneously —
    // otherwise the eager long-press (minimumPressDuration 0.01) swallows the
    // left-half drag and the angle never changes.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
