//
//  HUDOverlay.swift
//  JCannon
//
//  SpriteKit overlay drawn on top of the SceneKit view. Owns every on-screen
//  readout (level, coins, wind, power, angle, shots, combo, boss HP, stars) plus
//  the READY / VICTORY / DEFEAT banners. All text is English per the design doc.
//

import SpriteKit

/// Builds and updates the HUD. The scene subscribes gameplay events to it via
/// the update methods rather than the HUD reaching into gameplay.
final class HUDOverlay: SKScene {

    // Labels
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let coinLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let windLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let angleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let shotsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let goalLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // Power meter
    private let powerBackground = SKShapeNode()
    private let powerFill = SKShapeNode()

    // Boss HP bar
    private var bossBarBackground: SKShapeNode?
    private var bossBarFill: SKShapeNode?
    private let bossLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // Banner
    private let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    // Star display for results.
    private var starNodes: [SKLabelNode] = []

    /// Whether the initial node build has run — reflow is a no-op before then.
    private var built = false
    /// Boss bar state kept so the bar can be repositioned on rotation.
    private var bossBarInstalled = false
    private var lastBossNormalized: Float = 1

    /// Callbacks the view controller wires up.
    var onPauseTapped: (() -> Void)?

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = .clear
        buildTopBar()
        buildPowerMeter()
        buildComboLabel()
        buildBanner()
        buildPauseButton()
        built = true
        reflow()
    }

    /// The overlay uses `.resizeFill`, so `size` tracks the view but nodes are
    /// not repositioned automatically. Re-lay them out whenever the view size
    /// changes — crucially when the game rotates between portrait and landscape.
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        reflow()
    }

    /// Positions every persistent node against the current `size`. Safe to call
    /// repeatedly; transient nodes (toasts, result stars) are not managed here.
    private func reflow() {
        guard built else { return }
        levelLabel.position = CGPoint(x: 20, y: size.height - 20)
        coinLabel.position = CGPoint(x: size.width - 20, y: size.height - 20)
        windLabel.position = CGPoint(x: size.width / 2, y: size.height - 20)
        goalLabel.position = CGPoint(x: size.width / 2, y: size.height - 48)
        angleLabel.position = CGPoint(x: 20, y: 30)
        shotsLabel.position = CGPoint(x: size.width - 20, y: 30)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        banner.position = CGPoint(x: size.width / 2, y: size.height / 2)
        childNode(withName: "pauseButton")?.position = CGPoint(x: size.width / 2, y: 34)
        layoutPowerMeter()
        if bossBarInstalled { layoutBossBar() }
    }


    // MARK: - Layout

    private func buildTopBar() {
        levelLabel.fontSize = 20
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .top
        levelLabel.position = CGPoint(x: 20, y: size.height - 20)
        levelLabel.text = "LEVEL 1"
        addChild(levelLabel)

        coinLabel.fontSize = 18
        coinLabel.fontColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        coinLabel.horizontalAlignmentMode = .right
        coinLabel.verticalAlignmentMode = .top
        coinLabel.position = CGPoint(x: size.width - 20, y: size.height - 20)
        coinLabel.text = "COINS 0"
        addChild(coinLabel)

        windLabel.fontSize = 18
        windLabel.horizontalAlignmentMode = .center
        windLabel.verticalAlignmentMode = .top
        windLabel.position = CGPoint(x: size.width / 2, y: size.height - 20)
        windLabel.text = "WIND —"
        addChild(windLabel)

        goalLabel.fontSize = 15
        goalLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        goalLabel.horizontalAlignmentMode = .center
        goalLabel.verticalAlignmentMode = .top
        goalLabel.position = CGPoint(x: size.width / 2, y: size.height - 48)
        goalLabel.text = "DESTROY ALL"
        addChild(goalLabel)

        angleLabel.fontSize = 16
        angleLabel.horizontalAlignmentMode = .left
        angleLabel.verticalAlignmentMode = .bottom
        angleLabel.position = CGPoint(x: 20, y: 30)
        angleLabel.text = "ANGLE 45°"
        addChild(angleLabel)

        shotsLabel.fontSize = 16
        shotsLabel.horizontalAlignmentMode = .right
        shotsLabel.verticalAlignmentMode = .bottom
        shotsLabel.position = CGPoint(x: size.width - 20, y: 30)
        shotsLabel.text = "SHOTS 0"
        addChild(shotsLabel)
    }

    private func buildPowerMeter() {
        powerBackground.fillColor = SKColor(white: 0, alpha: 0.35)
        powerBackground.strokeColor = SKColor(white: 1, alpha: 0.5)
        powerBackground.lineWidth = 2
        powerBackground.isHidden = true
        addChild(powerBackground)

        powerFill.fillColor = SKColor(red: 1, green: 0.4, blue: 0.2, alpha: 1)
        powerFill.strokeColor = .clear
        powerFill.isHidden = true
        addChild(powerFill)
    }

    /// (Re)computes the power-meter geometry against the current size. The fill
    /// rect itself is drawn on demand in `setPower` from the stored geometry.
    private func layoutPowerMeter() {
        let barWidth: CGFloat = 24
        let barHeight: CGFloat = 160
        let x = size.width - 44
        let y: CGFloat = 60
        let bgRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
        powerBackground.path = CGPath(roundedRect: bgRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        powerFill.userData = ["x": x, "y": y, "w": barWidth, "h": barHeight]
    }

    private func buildComboLabel() {
        comboLabel.fontSize = 34
        comboLabel.fontColor = SKColor(red: 1, green: 0.7, blue: 0.1, alpha: 1)
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        comboLabel.alpha = 0
        addChild(comboLabel)
    }

    private func buildBanner() {
        banner.fontSize = 52
        banner.horizontalAlignmentMode = .center
        banner.verticalAlignmentMode = .center
        banner.position = CGPoint(x: size.width / 2, y: size.height / 2)
        banner.alpha = 0
        banner.zPosition = 100
        addChild(banner)
    }

    private func buildPauseButton() {
        let pause = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pause.text = "II"
        pause.name = "pauseButton"
        pause.fontSize = 22
        pause.horizontalAlignmentMode = .center
        pause.verticalAlignmentMode = .center
        pause.position = CGPoint(x: size.width / 2, y: 34)
        addChild(pause)
    }

    // MARK: - Updates (called from gameplay via events)

    func setLevel(_ index: Int) {
        levelLabel.text = index < 0 ? "DAILY" : "LEVEL \(index)"
    }

    func setGoal(_ text: String) { goalLabel.text = text }

    func setCoins(_ total: Int) { coinLabel.text = "COINS \(total)" }

    func setWind(arrow: String, speed: Float) {
        windLabel.text = String(format: "WIND %@ %.1f", arrow, speed)
    }

    func setAngle(_ degrees: Float) {
        angleLabel.text = String(format: "ANGLE %.0f°", degrees)
    }

    func setShots(_ remaining: Int) {
        shotsLabel.text = "SHOTS \(remaining)"
    }

    func setPower(_ normalized: Float, visible: Bool) {
        powerBackground.isHidden = !visible
        powerFill.isHidden = !visible
        guard visible, let d = powerFill.userData,
              let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat,
              let w = d["w"] as? CGFloat, let h = d["h"] as? CGFloat else { return }
        let clamped = CGFloat(min(max(normalized, 0), 1))
        let fillRect = CGRect(x: x, y: y, width: w, height: h * clamped)
        powerFill.path = CGPath(roundedRect: fillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        // Colour shifts from orange to red as it charges.
        powerFill.fillColor = SKColor(red: 1, green: 0.5 - clamped * 0.4, blue: 0.15, alpha: 1)
    }

    func showCombo(chain: Int, multiplier: Int) {
        guard chain >= 2 else {
            comboLabel.run(.fadeOut(withDuration: 0.2))
            return
        }
        comboLabel.text = "COMBO x\(multiplier)"
        comboLabel.removeAllActions()
        comboLabel.setScale(1.4)
        comboLabel.alpha = 1
        comboLabel.run(.group([
            .scale(to: 1.0, duration: 0.2),
            .sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.4)])
        ]))
    }

    // MARK: - Boss bar

    func installBossBar() {
        let bg = SKShapeNode()
        bg.fillColor = SKColor(white: 0, alpha: 0.4)
        bg.strokeColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        bg.lineWidth = 2
        addChild(bg)
        bossBarBackground = bg

        let fill = SKShapeNode()
        fill.fillColor = SKColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        fill.strokeColor = .clear
        addChild(fill)
        bossBarFill = fill

        bossLabel.text = "BOSS"
        bossLabel.fontSize = 14
        bossLabel.horizontalAlignmentMode = .center
        addChild(bossLabel)

        bossBarInstalled = true
        layoutBossBar()
    }

    /// Positions/sizes the boss bar against the current size and redraws the
    /// fill at the last known health so rotation preserves it.
    private func layoutBossBar() {
        let width = size.width * 0.7
        let height: CGFloat = 16
        let x = (size.width - width) / 2
        let y = size.height - 80

        bossBarBackground?.path = CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height),
                                         cornerWidth: 8, cornerHeight: 8, transform: nil)
        bossBarFill?.userData = ["x": x, "y": y, "w": width, "h": height]
        bossLabel.position = CGPoint(x: size.width / 2, y: y + height + 6)
        setBossHealth(normalized: lastBossNormalized)
    }

    func setBossHealth(normalized: Float) {
        lastBossNormalized = normalized
        guard let fill = bossBarFill, let d = fill.userData,
              let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat,
              let w = d["w"] as? CGFloat, let h = d["h"] as? CGFloat else { return }
        let clamped = CGFloat(min(max(normalized, 0), 1))
        fill.path = CGPath(roundedRect: CGRect(x: x, y: y, width: w * clamped, height: h),
                           cornerWidth: 8, cornerHeight: 8, transform: nil)
    }

    func setBossPhase(_ phase: Int, total: Int) {
        bossLabel.text = "BOSS  PHASE \(phase)/\(total)"
    }

    // MARK: - Banners & stars

    func flashBanner(_ text: String, color: SKColor) {
        banner.text = text
        banner.fontColor = color
        banner.removeAllActions()
        banner.setScale(0.4)
        banner.alpha = 0
        banner.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1.0, duration: 0.3)]))
    }

    func hideBanner() {
        banner.run(.fadeOut(withDuration: 0.2))
    }

    /// A transient two-line toast in the upper third for unlock notifications.
    /// Independent of the main banner so it can appear mid-play without clobbering
    /// READY / VICTORY text.
    func showToast(_ text: String, color: SKColor) {
        let toast = SKLabelNode(fontNamed: "AvenirNext-Bold")
        toast.numberOfLines = 2
        toast.preferredMaxLayoutWidth = size.width * 0.8
        toast.horizontalAlignmentMode = .center
        toast.verticalAlignmentMode = .center
        toast.fontSize = 20
        toast.fontColor = color
        toast.text = text
        toast.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        toast.alpha = 0
        toast.zPosition = 90
        addChild(toast)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.2), .moveBy(x: 0, y: 20, duration: 0.3)]),
            .wait(forDuration: 1.8),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
        AudioPulse.shared.play(.combo)
    }

    func showResult(victory: Bool, stars: Int) {
        flashBanner(victory ? "VICTORY" : "DEFEAT",
                    color: victory ? SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1)
                                   : SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1))
        guard victory else { return }
        starNodes.forEach { $0.removeFromParent() }
        starNodes.removeAll()
        for i in 0..<3 {
            let star = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            star.text = i < stars ? "★" : "☆"
            star.fontSize = 44
            star.fontColor = i < stars ? SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : SKColor(white: 0.6, alpha: 1)
            star.position = CGPoint(x: size.width / 2 + CGFloat(i - 1) * 60, y: size.height / 2 - 70)
            star.alpha = 0
            star.zPosition = 101
            addChild(star)
            star.run(.sequence([.wait(forDuration: 0.4 + Double(i) * 0.2), .fadeIn(withDuration: 0.3)]))
            starNodes.append(star)
        }
    }

    /// Clears the result banner and star rating (call when a new stage loads).
    func clearResult() {
        starNodes.forEach { $0.removeFromParent() }
        starNodes.removeAll()
        hideBanner()
    }

    // MARK: - Touch → pause

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)
        if tapped.contains(where: { $0.name == "pauseButton" }) {
            AudioPulse.shared.play(.uiTap)
            onPauseTapped?()
        }
    }
}
