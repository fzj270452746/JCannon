//
//  SkyBuilder.swift
//  JCannon
//
//  Procedural sky. Each biome gets a vertical gradient rendered to a single
//  image and assigned as the scene background — cheaper than a six-face cubemap
//  and matches the stylised look.
//

import SceneKit
import UIKit

/// Visual theme for a stage. Drives sky colours, ground gradient and fog.
enum BiomeTheme: String, CaseIterable, Codable {
    case forest
    case snow
    case temple
    case volcano
    case sky
    case moon

    /// Top-to-bottom sky colours.
    var skyGradient: [UIColor] {
        switch self {
        case .forest:  return [UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1),
                               UIColor(red: 0.82, green: 0.94, blue: 0.85, alpha: 1)]
        case .snow:    return [UIColor(red: 0.70, green: 0.80, blue: 0.92, alpha: 1),
                               UIColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1)]
        case .temple:  return [UIColor(red: 0.98, green: 0.78, blue: 0.45, alpha: 1),
                               UIColor(red: 0.99, green: 0.90, blue: 0.70, alpha: 1)]
        case .volcano: return [UIColor(red: 0.35, green: 0.12, blue: 0.10, alpha: 1),
                               UIColor(red: 0.85, green: 0.35, blue: 0.12, alpha: 1)]
        case .sky:     return [UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1),
                               UIColor(red: 0.75, green: 0.88, blue: 1.00, alpha: 1)]
        case .moon:    return [UIColor(red: 0.03, green: 0.03, blue: 0.12, alpha: 1),
                               UIColor(red: 0.14, green: 0.16, blue: 0.34, alpha: 1)]
        }
    }

    var groundGradient: [UIColor] {
        switch self {
        case .forest:  return [UIColor(red: 0.40, green: 0.62, blue: 0.28, alpha: 1),
                               UIColor(red: 0.28, green: 0.45, blue: 0.18, alpha: 1)]
        case .snow:    return [UIColor(red: 0.92, green: 0.95, blue: 0.99, alpha: 1),
                               UIColor(red: 0.78, green: 0.85, blue: 0.92, alpha: 1)]
        case .temple:  return [UIColor(red: 0.80, green: 0.70, blue: 0.50, alpha: 1),
                               UIColor(red: 0.62, green: 0.52, blue: 0.35, alpha: 1)]
        case .volcano: return [UIColor(red: 0.25, green: 0.16, blue: 0.14, alpha: 1),
                               UIColor(red: 0.15, green: 0.09, blue: 0.08, alpha: 1)]
        case .sky:     return [UIColor(red: 0.85, green: 0.90, blue: 0.98, alpha: 1),
                               UIColor(red: 0.70, green: 0.80, blue: 0.92, alpha: 1)]
        case .moon:    return [UIColor(red: 0.30, green: 0.30, blue: 0.36, alpha: 1),
                               UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)]
        }
    }

    var fogColor: UIColor { skyGradient.last ?? .white }

    var accentLight: UIColor {
        switch self {
        case .volcano: return UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1)
        case .moon:    return UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1)
        default:       return .white
        }
    }
}

/// Builds sky background images. Caches per theme.
enum SkyBuilder {

    private static var cache: [BiomeTheme: UIImage] = [:]

    static func background(for theme: BiomeTheme) -> UIImage {
        if let hit = cache[theme] { return hit }
        let image = renderGradient(theme)
        cache[theme] = image
        return image
    }

    private static func renderGradient(_ theme: BiomeTheme) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cg = ctx.cgContext
            let colors = theme.skyGradient.map { $0.cgColor }
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [])
            }
            decorate(theme, cg, rect)
        }
    }

    /// Theme-specific flourishes drawn over the gradient (stars, clouds, etc.).
    private static func decorate(_ theme: BiomeTheme, _ cg: CGContext, _ rect: CGRect) {
        var rng = SeededRandom(seed: UInt64(theme.hashValue & 0xFFFF), tag: "sky")
        switch theme {
        case .moon, .sky:
            UIColor(white: 1, alpha: 0.9).setFill()
            for _ in 0..<60 {
                let s = CGFloat(rng.float(in: 1...3))
                cg.fillEllipse(in: CGRect(x: CGFloat(rng.float(in: 0...Float(rect.width))),
                                          y: CGFloat(rng.float(in: 0...Float(rect.height * 0.6))),
                                          width: s, height: s))
            }
        case .forest, .snow:
            UIColor(white: 1, alpha: 0.55).setFill()
            for _ in 0..<6 {
                drawCloud(cg, at: CGPoint(x: CGFloat(rng.float(in: 0...Float(rect.width))),
                                          y: CGFloat(rng.float(in: 20...Float(rect.height * 0.5)))),
                          scale: CGFloat(rng.float(in: 0.6...1.4)))
            }
        case .volcano:
            UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.3).setFill()
            for _ in 0..<20 {
                let s = CGFloat(rng.float(in: 2...6))
                cg.fillEllipse(in: CGRect(x: CGFloat(rng.float(in: 0...Float(rect.width))),
                                          y: CGFloat(rng.float(in: 0...Float(rect.height))),
                                          width: s, height: s))
            }
        case .temple:
            break
        }
    }

    private static func drawCloud(_ cg: CGContext, at p: CGPoint, scale: CGFloat) {
        let puffs = [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: -8), CGPoint(x: 60, y: 0), CGPoint(x: 30, y: 8)]
        for puff in puffs {
            let r = 26 * scale
            cg.fillEllipse(in: CGRect(x: p.x + puff.x * scale - r, y: p.y + puff.y * scale - r,
                                      width: r * 2, height: r * 2))
        }
    }
}
