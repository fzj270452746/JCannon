//
//  LeaderboardViewController.swift
//  JCannon
//
//  Local, offline records board. Shows campaign totals, endless best round and
//  the daily-challenge history. Reads ScoreVault. No networking, per the design.
//

import UIKit

final class LeaderboardViewController: UIViewController, UITableViewDataSource {

    private let table = UITableView(frame: .zero, style: .grouped)

    // Sections: 0 = summary, 1 = daily history.
    private var dailyRecords: [DailyRecord] = []

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        dailyRecords = ScoreVault.shared.dailyRecords
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first(where: { $0.name == "jc.bg" })?.frame = view.bounds
    }

    private func buildLayout() {
        UIKitForge.gradientBackground(for: view,
                                      top: UIColor(red: 0.14, green: 0.18, blue: 0.30, alpha: 1),
                                      bottom: UIColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1))

        let title = UIKitForge.title("RANKS", size: 30)
        view.addSubview(title)

        table.dataSource = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "rank")
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

    // MARK: - Data

    private var summaryRows: [(String, String)] {
        [
            ("Highest Stage", "\(ScoreVault.shared.highestStageCleared)"),
            ("Total Stars", "★ \(ScoreVault.shared.totalStars)"),
            ("Endless Best", "ROUND \(ScoreVault.shared.endlessBest)"),
            ("Coins", "\(UpgradeVault.shared.coins)")
        ]
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "CAMPAIGN & ENDLESS" : "DAILY CHALLENGE HISTORY"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? summaryRows.count : max(dailyRecords.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "rank", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = .white
        config.textProperties.font = UIFont(name: "AvenirNext-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        config.secondaryTextProperties.color = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        config.secondaryTextProperties.font = UIFont(name: "AvenirNext-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)

        if indexPath.section == 0 {
            let row = summaryRows[indexPath.row]
            config.text = row.0
            config.secondaryText = row.1
        } else if dailyRecords.isEmpty {
            config.text = "No daily runs yet"
            config.secondaryText = ""
        } else {
            let rec = dailyRecords[indexPath.row]
            config.text = formatDay(rec.dayKey)
            config.secondaryText = "\(rec.coins)c  ★\(rec.stars)"
        }
        cell.contentConfiguration = config
        cell.backgroundColor = UIColor(white: 1, alpha: 0.1)
        cell.selectionStyle = .none
        return cell
    }

    private func formatDay(_ key: Int) -> String {
        let y = key / 10000
        let m = (key / 100) % 100
        let d = key % 100
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    @objc private func dismissSelf() {
        AudioPulse.shared.play(.uiTap)
        dismiss(animated: true)
    }
}
