//
//  AchievementsViewController.swift
//  JCannon
//
//  Lists every achievement with its unlock state and a progress bar toward the
//  goal. Reads AchievementVault.
//

import UIKit

final class AchievementsViewController: UIViewController, UITableViewDataSource {

    private let table = UITableView(frame: .zero, style: .plain)
    private let achievements = AchievementVault.shared.catalog

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first(where: { $0.name == "jc.bg" })?.frame = view.bounds
    }

    private func buildLayout() {
        UIKitForge.gradientBackground(for: view,
                                      top: UIColor(red: 0.28, green: 0.22, blue: 0.10, alpha: 1),
                                      bottom: UIColor(red: 0.12, green: 0.10, blue: 0.14, alpha: 1))

        let unlockedCount = achievements.filter { AchievementVault.shared.isUnlocked($0) }.count
        let title = UIKitForge.title("AWARDS  \(unlockedCount)/\(achievements.count)", size: 26)
        view.addSubview(title)

        table.dataSource = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = 78
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(AchievementCell.self, forCellReuseIdentifier: "ach")
        view.addSubview(table)

        let close = UIKitForge.button("BACK", color: UIColor(white: 1, alpha: 0.18))
        close.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(close)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            table.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            table.bottomAnchor.constraint(equalTo: close.topAnchor, constant: -12),

            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            close.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        achievements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ach", for: indexPath) as! AchievementCell
        let a = achievements[indexPath.row]
        cell.configure(a,
                       unlocked: AchievementVault.shared.isUnlocked(a),
                       progress: AchievementVault.shared.progress(for: a))
        return cell
    }

    @objc private func dismissSelf() {
        AudioPulse.shared.play(.uiTap)
        dismiss(animated: true)
    }
}

/// A custom cell with a title, detail and a slim progress bar.
private final class AchievementCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let barBackground = UIView()
    private let barFill = UIView()
    private var fillWidth: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func build() {
        backgroundColor = .clear
        selectionStyle = .none

        let container = UIView()
        container.backgroundColor = UIColor(white: 1, alpha: 0.1)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 16)
        detailLabel.font = UIFont(name: "AvenirNext-Medium", size: 12)
        detailLabel.textColor = UIColor(white: 1, alpha: 0.7)
        detailLabel.numberOfLines = 1

        barBackground.backgroundColor = UIColor(white: 1, alpha: 0.15)
        barBackground.layer.cornerRadius = 3
        barFill.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        barFill.layer.cornerRadius = 3

        [titleLabel, detailLabel, barBackground, barFill].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        container.addSubview(titleLabel)
        container.addSubview(detailLabel)
        container.addSubview(barBackground)
        barBackground.addSubview(barFill)

        let fw = barFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth = fw

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),

            barBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            barBackground.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            barBackground.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            barBackground.heightAnchor.constraint(equalToConstant: 6),

            barFill.leadingAnchor.constraint(equalTo: barBackground.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barBackground.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barBackground.bottomAnchor),
            fw
        ])
    }

    func configure(_ a: Achievement, unlocked: Bool, progress: Float) {
        titleLabel.text = unlocked ? "\(a.title)  ✓" : a.title
        titleLabel.textColor = unlocked ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : .white
        detailLabel.text = a.detail
        // Defer width until layout so the bar background has a real width.
        layoutIfNeeded()
        fillWidth?.constant = barBackground.bounds.width * CGFloat(progress)
    }
}
