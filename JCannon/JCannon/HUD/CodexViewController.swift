//
//  CodexViewController.swift
//  JCannon
//
//  The encyclopedia screen. Sectioned by category; locked entries show as "???"
//  until discovered in play. Reads CodexVault.
//

import UIKit

final class CodexViewController: UIViewController, UITableViewDataSource {

    private let table = UITableView(frame: .zero, style: .grouped)
    private let categories = CodexCategory.allCases

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
                                      top: UIColor(red: 0.12, green: 0.20, blue: 0.32, alpha: 1),
                                      bottom: UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1))

        let title = UIKitForge.title("CODEX", size: 30)
        view.addSubview(title)

        table.dataSource = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "codex")
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

    // MARK: - Data source

    func numberOfSections(in tableView: UITableView) -> Int { categories.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cat = categories[section]
        let entries = CodexVault.shared.entries(in: cat)
        let unlocked = entries.filter { CodexVault.shared.isUnlocked($0) }.count
        return "\(cat.rawValue)  (\(unlocked)/\(entries.count))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        CodexVault.shared.entries(in: categories[section]).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "codex", for: indexPath)
        let entry = CodexVault.shared.entries(in: categories[indexPath.section])[indexPath.row]
        let unlocked = CodexVault.shared.isUnlocked(entry)

        var config = cell.defaultContentConfiguration()
        config.textProperties.color = .white
        config.textProperties.font = UIFont(name: "AvenirNext-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        config.secondaryTextProperties.color = UIColor(white: 1, alpha: 0.7)
        config.secondaryTextProperties.font = UIFont(name: "AvenirNext-Medium", size: 13) ?? .systemFont(ofSize: 13)

        if unlocked {
            config.text = entry.title
            config.secondaryText = entry.detail
        } else {
            config.text = "???"
            config.secondaryText = "Discover in play to unlock."
        }
        cell.contentConfiguration = config
        cell.backgroundColor = UIColor(white: 1, alpha: unlocked ? 0.12 : 0.05)
        cell.selectionStyle = .none
        return cell
    }

    @objc private func dismissSelf() {
        AudioPulse.shared.play(.uiTap)
        dismiss(animated: true)
    }
}
