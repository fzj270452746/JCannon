//
//  UIKitForge.swift
//  JCannon
//
//  Small procedural UIKit helpers shared by the menu / shop / codex screens.
//  Keeps the controllers terse and gives every screen the same stylised look
//  without storyboards or asset images.
//

import UIKit

enum UIKitForge {

    /// A gradient background layer matching the game's palette.
    static func gradientBackground(for view: UIView, top: UIColor, bottom: UIColor) {
        let layer = CAGradientLayer()
        layer.colors = [top.cgColor, bottom.cgColor]
        layer.frame = view.bounds
        layer.name = "jc.bg"
        view.layer.insertSublayer(layer, at: 0)
    }

    /// A chunky rounded action button.
    static func button(_ title: String, color: UIColor) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)
        b.backgroundColor = color
        b.layer.cornerRadius = 14
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.25
        b.layer.shadowOffset = CGSize(width: 0, height: 3)
        b.layer.shadowRadius = 4
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return b
    }

    /// A title label in the heavy display font.
    static func title(_ text: String, size: CGFloat = 34) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont(name: "AvenirNext-Heavy", size: size)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    /// A vertical stack pinned with padding inside a container.
    static func stack(_ views: [UIView], spacing: CGFloat = 16) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .vertical
        s.spacing = spacing
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    /// A translucent rounded card used to group content.
    static func card() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.12)
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}
