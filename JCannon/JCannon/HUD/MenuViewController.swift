//
//  MenuViewController.swift
//  JCannon
//
//  The home screen and navigation hub. Storyboard points here; every mode /
//  screen launches from these buttons. Built entirely in code — no storyboard
//  layout beyond the entry reference.
//

import UIKit

final class MenuViewController: UIViewController {

    private var bgLayer: CAGradientLayer?

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }


    override func viewDidLoad() {
        super.viewDidLoad()
        AudioPulse.shared.boot()
        AchievementVault.shared.startListening()
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first(where: { $0.name == "jc.bg" })?.frame = view.bounds
    }

    // MARK: - Layout

    private func buildLayout() {
        UIKitForge.gradientBackground(for: view,
                                      top: UIColor(red: 0.16, green: 0.22, blue: 0.42, alpha: 1),
                                      bottom: UIColor(red: 0.35, green: 0.20, blue: 0.42, alpha: 1))

        let title = UIKitForge.title("MAHJONG\nCANNON", size: 40)
        title.numberOfLines = 2

        let subtitle = UILabel()
        subtitle.text = progressSummary()
        subtitle.font = UIFont(name: "AvenirNext-Medium", size: 15)
        subtitle.textColor = UIColor(white: 1, alpha: 0.8)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 2

        let playButton = UIKitForge.button("PLAY", color: UIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1))
        playButton.addTarget(self, action: #selector(playCampaign), for: .touchUpInside)

        let endlessButton = UIKitForge.button("ENDLESS", color: UIColor(red: 0.85, green: 0.45, blue: 0.2, alpha: 1))
        endlessButton.addTarget(self, action: #selector(playEndless), for: .touchUpInside)

        let dailyButton = UIKitForge.button("DAILY CHALLENGE", color: UIColor(red: 0.3, green: 0.55, blue: 0.85, alpha: 1))
        dailyButton.addTarget(self, action: #selector(playDaily), for: .touchUpInside)

        let sandboxButton = UIKitForge.button("SANDBOX", color: UIColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 1))
        sandboxButton.addTarget(self, action: #selector(playSandbox), for: .touchUpInside)

        // Secondary row: shop / codex / achievements / leaderboard.
        let shopButton = smallButton("SHOP", #selector(openShop))
        let codexButton = smallButton("CODEX", #selector(openCodex))
        let achButton = smallButton("AWARDS", #selector(openAchievements))
        let boardButton = smallButton("RANKS", #selector(openLeaderboard))

        let secondaryRow = UIStackView(arrangedSubviews: [shopButton, codexButton, achButton, boardButton])
        secondaryRow.axis = .horizontal
        secondaryRow.distribution = .fillEqually
        secondaryRow.spacing = 10

        let stack = UIKitForge.stack([title, subtitle, playButton, endlessButton,
                                      dailyButton, sandboxButton, secondaryRow])
        stack.setCustomSpacing(28, after: subtitle)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func smallButton(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 13)
        b.backgroundColor = UIColor(white: 1, alpha: 0.15)
        b.layer.cornerRadius = 10
        b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func progressSummary() -> String {
        let stars = ScoreVault.shared.totalStars
        let stage = max(1, ScoreVault.shared.highestStageCleared)
        return "COINS \(UpgradeVault.shared.coins)   ★ \(stars)\nCAMPAIGN STAGE \(stage)"
    }

    // MARK: - Navigation

    private func launchGame(configure: (ViewController) -> Void) {
        AudioPulse.shared.play(.uiTap)
        let game = ViewController()
        configure(game)
        game.onExitToMenu = { [weak self, weak game] in
            game?.dismiss(animated: true) {
                self?.refresh()
            }
        }
        game.modalPresentationStyle = .fullScreen
        present(game, animated: true)
    }

    @objc private func playCampaign() {
        launchGame { $0.mode = .campaign; $0.startStageIndex = max(1, ScoreVault.shared.highestStageCleared + 1) }
    }

    @objc private func playEndless() {
        launchGame { $0.mode = .endless }
    }

    @objc private func playDaily() {
        launchGame { $0.mode = .daily }
    }

    @objc private func playSandbox() {
        launchGame { $0.mode = .sandbox }
    }

    @objc private func openShop() {
        AudioPulse.shared.play(.uiTap)
        pushList(ShopViewController())
    }

    @objc private func openCodex() {
        AudioPulse.shared.play(.uiTap)
        pushList(CodexViewController())
    }

    @objc private func openAchievements() {
        AudioPulse.shared.play(.uiTap)
        pushList(AchievementsViewController())
    }

    @objc private func openLeaderboard() {
        AudioPulse.shared.play(.uiTap)
        pushList(LeaderboardViewController())
    }

    private func pushList(_ vc: UIViewController) {
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true) { [weak self] in _ = self }
    }

    private func refresh() {
        // Rebuild the summary line to reflect new coins / progress.
        view.subviews.forEach { $0.removeFromSuperview() }
        buildLayout()
    }
}
