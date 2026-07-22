//
//  ShopViewController.swift
//  JCannon
//
//  Coin-driven upgrade shop. Lists the five upgrade tracks with current level,
//  next-level cost and a buy button. Reads / writes UpgradeVault; no networking.
//

import UIKit

final class ShopViewController: UIViewController {

    private let coinLabel = UILabel()
    private var rows: [UpgradeTrack: UpgradeRow] = [:]

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first(where: { $0.name == "jc.bg" })?.frame = view.bounds
    }

    private func buildLayout() {
        UIKitForge.gradientBackground(for: view,
                                      top: UIColor(red: 0.20, green: 0.16, blue: 0.30, alpha: 1),
                                      bottom: UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1))

        let title = UIKitForge.title("SHOP", size: 30)

        coinLabel.font = UIFont(name: "AvenirNext-Bold", size: 18)
        coinLabel.textColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        coinLabel.textAlignment = .center

        var rowViews: [UIView] = []
        for track in UpgradeTrack.allCases {
            let row = UpgradeRow(track: track) { [weak self] in self?.purchase(track) }
            rows[track] = row
            rowViews.append(row)
        }

        let close = UIKitForge.button("BACK", color: UIColor(white: 1, alpha: 0.18))
        close.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let stack = UIKitForge.stack([title, coinLabel] + rowViews + [close])
        stack.setCustomSpacing(24, after: coinLabel)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func purchase(_ track: UpgradeTrack) {
        if UpgradeVault.shared.purchase(track) {
            AudioPulse.shared.play(.combo)
        } else {
            AudioPulse.shared.play(.uiTap)
        }
        refresh()
    }

    private func refresh() {
        coinLabel.text = "COINS  \(UpgradeVault.shared.coins)"
        for (track, row) in rows {
            row.update(level: UpgradeVault.shared.level(of: track),
                       coins: UpgradeVault.shared.coins)
        }
    }

    @objc private func dismissSelf() {
        AudioPulse.shared.play(.uiTap)
        dismiss(animated: true)
    }
}

/// One upgrade track row: name, pips for level, cost + buy.
private final class UpgradeRow: UIView {

    private let track: UpgradeTrack
    private let onBuy: () -> Void
    private let nameLabel = UILabel()
    private let levelLabel = UILabel()
    private let buyButton = UIButton(type: .system)

    init(track: UpgradeTrack, onBuy: @escaping () -> Void) {
        self.track = track
        self.onBuy = onBuy
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func build() {
        backgroundColor = UIColor(white: 1, alpha: 0.12)
        layer.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 66).isActive = true

        nameLabel.font = UIFont(name: "AvenirNext-Bold", size: 16)
        nameLabel.textColor = .white
        nameLabel.text = track.displayName

        levelLabel.font = UIFont(name: "AvenirNext-Medium", size: 13)
        levelLabel.textColor = UIColor(white: 1, alpha: 0.8)

        buyButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 14)
        buyButton.setTitleColor(.white, for: .normal)
        buyButton.backgroundColor = UIColor(red: 0.2, green: 0.65, blue: 0.4, alpha: 1)
        buyButton.layer.cornerRadius = 9
        buyButton.addTarget(self, action: #selector(buyTapped), for: .touchUpInside)

        let text = UIKitForge.stack([nameLabel, levelLabel], spacing: 4)
        text.alignment = .leading
        addSubview(text)
        buyButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buyButton)

        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            buyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            buyButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            buyButton.widthAnchor.constraint(equalToConstant: 96),
            buyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func update(level: Int, coins: Int) {
        let pips = String(repeating: "●", count: level) + String(repeating: "○", count: track.maxLevel - level)
        levelLabel.text = pips
        if level >= track.maxLevel {
            buyButton.setTitle("MAX", for: .normal)
            buyButton.backgroundColor = UIColor(white: 1, alpha: 0.2)
            buyButton.isEnabled = false
        } else {
            let cost = track.cost(atLevel: level)
            buyButton.setTitle("\(cost)", for: .normal)
            let affordable = coins >= cost
            buyButton.isEnabled = affordable
            buyButton.backgroundColor = affordable
                ? UIColor(red: 0.2, green: 0.65, blue: 0.4, alpha: 1)
                : UIColor(white: 1, alpha: 0.2)
        }
    }

    @objc private func buyTapped() { onBuy() }
}
