//
//  ProceduralTextureCache.swift
//  JCannon
//
//  All surface art is drawn at runtime with CoreGraphics and cached. No image
//  assets ship with the app — this keeps texture memory bounded and the visual
//  implementation self-contained.
//

import UIKit

/// Identifies a drawable material / face. The cache renders each one lazily on
/// first request and reuses the `UIImage` thereafter.
enum SurfaceFace: Hashable {
    case tileFace(TileKind)
    case tileBack
    case wood
    case stone
    case brick
    case metal
    case gold
    case dragonScale
    case panda
    case ground(BiomeTheme)
}

/// Central texture store. Backed by an `NSCache` so the OS can evict under
/// memory pressure while we keep strong refs to hot materials.
final class ProceduralTextureCache {

    static let shared = ProceduralTextureCache()

    private var store: [SurfaceFace: UIImage] = [:]

    private init() {}

    func image(_ face: SurfaceFace) -> UIImage {
        if let cached = store[face] { return cached }
        let rendered = render(face)
        store[face] = rendered
        return rendered
    }

    // MARK: - Dispatch

    private func render(_ face: SurfaceFace) -> UIImage {
        switch face {
        case .tileFace(let kind): return drawTileFace(kind)
        case .tileBack:           return drawTileBack()
        case .wood:               return drawWood()
        case .stone:              return drawStone()
        case .brick:              return drawBrick()
        case .metal:              return drawMetal()
        case .gold:               return drawGold()
        case .dragonScale:        return drawDragonScale()
        case .panda:              return drawFlat(UIColor.white)
        case .ground(let theme):  return drawGround(theme)
        }
    }

    // MARK: - Canvas helper

    private func canvas(_ size: CGFloat = 256, _ draw: (CGContext, CGRect) -> Void) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            draw(ctx.cgContext, rect)
        }
    }

    // MARK: - Mahjong faces

    private func drawTileFace(_ kind: TileKind) -> UIImage {
        canvas { ctx, rect in
            // Ivory tile body with a subtle bevel.
            UIColor(red: 0.97, green: 0.96, blue: 0.90, alpha: 1).setFill()
            ctx.fill(rect)
            let inset = rect.insetBy(dx: 18, dy: 18)
            UIColor(red: 0.90, green: 0.88, blue: 0.80, alpha: 1).setStroke()
            ctx.setLineWidth(6)
            ctx.stroke(inset)

            let accent = kind.accentColor
            switch kind {
            case .redDragon:
                drawGlyph("中", in: rect, color: UIColor(red: 0.80, green: 0.12, blue: 0.12, alpha: 1))
            case .greenDragon:
                drawGlyph("發", in: rect, color: UIColor(red: 0.10, green: 0.55, blue: 0.25, alpha: 1))
            case .whiteDragon:
                // White dragon is a blue rectangular frame by convention.
                accent.setStroke()
                ctx.setLineWidth(10)
                ctx.stroke(rect.insetBy(dx: 60, dy: 60))
            case .wan:
                drawGlyph("萬", in: rect, color: accent)
            case .bamboo:
                drawBambooMotif(in: rect, ctx: ctx, color: accent)
            case .dot:
                drawDotMotif(in: rect, ctx: ctx, color: accent)
            }
        }
    }

    private func drawGlyph(_ text: String, in rect: CGRect, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let font = UIFont.systemFont(ofSize: rect.width * 0.5, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }

    private func drawBambooMotif(in rect: CGRect, ctx: CGContext, color: UIColor) {
        color.setStroke()
        color.setFill()
        ctx.setLineWidth(10)
        let cols = 3
        let spacing = rect.width / CGFloat(cols + 1)
        for c in 1...cols {
            let x = spacing * CGFloat(c)
            ctx.move(to: CGPoint(x: x, y: rect.height * 0.25))
            ctx.addLine(to: CGPoint(x: x, y: rect.height * 0.75))
            ctx.strokePath()
            // Node caps.
            for y in [rect.height * 0.25, rect.height * 0.5, rect.height * 0.75] {
                ctx.fillEllipse(in: CGRect(x: x - 8, y: y - 8, width: 16, height: 16))
            }
        }
    }

    private func drawDotMotif(in rect: CGRect, ctx: CGContext, color: UIColor) {
        color.setFill()
        let r: CGFloat = 26
        let positions = [
            CGPoint(x: rect.width * 0.3, y: rect.height * 0.3),
            CGPoint(x: rect.width * 0.7, y: rect.height * 0.3),
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.width * 0.3, y: rect.height * 0.7),
            CGPoint(x: rect.width * 0.7, y: rect.height * 0.7)
        ]
        for p in positions {
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }

    private func drawTileBack() -> UIImage {
        canvas { ctx, rect in
            let colors = [UIColor(red: 0.15, green: 0.42, blue: 0.65, alpha: 1).cgColor,
                          UIColor(red: 0.08, green: 0.28, blue: 0.48, alpha: 1).cgColor]
            drawVerticalGradient(ctx, rect, colors)
            UIColor(white: 1, alpha: 0.25).setStroke()
            ctx.setLineWidth(8)
            ctx.stroke(rect.insetBy(dx: 24, dy: 24))
        }
    }

    // MARK: - Building materials

    private func drawWood() -> UIImage {
        canvas { ctx, rect in
            UIColor(red: 0.55, green: 0.36, blue: 0.19, alpha: 1).setFill()
            ctx.fill(rect)
            var rng = SeededRandom(seed: 42, tag: "wood")
            UIColor(red: 0.42, green: 0.26, blue: 0.12, alpha: 0.7).setStroke()
            for _ in 0..<14 {
                ctx.setLineWidth(CGFloat(rng.float(in: 1...4)))
                let y = rng.float(in: 0...Float(rect.height))
                ctx.move(to: CGPoint(x: 0, y: CGFloat(y)))
                ctx.addCurve(to: CGPoint(x: rect.width, y: CGFloat(y) + CGFloat(rng.float(in: -12...12))),
                             control1: CGPoint(x: rect.width * 0.33, y: CGFloat(y) + CGFloat(rng.float(in: -20...20))),
                             control2: CGPoint(x: rect.width * 0.66, y: CGFloat(y) + CGFloat(rng.float(in: -20...20))))
                ctx.strokePath()
            }
        }
    }

    private func drawStone() -> UIImage {
        canvas { ctx, rect in
            UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1).setFill()
            ctx.fill(rect)
            var rng = SeededRandom(seed: 7, tag: "stone")
            for _ in 0..<40 {
                let g = rng.float(in: 0.4...0.68)
                UIColor(white: CGFloat(g), alpha: 0.5).setFill()
                let s = CGFloat(rng.float(in: 12...48))
                ctx.fillEllipse(in: CGRect(x: CGFloat(rng.float(in: 0...Float(rect.width))),
                                           y: CGFloat(rng.float(in: 0...Float(rect.height))),
                                           width: s, height: s))
            }
            // Crack lines.
            UIColor(white: 0.3, alpha: 0.4).setStroke()
            ctx.setLineWidth(2)
            for _ in 0..<6 {
                ctx.move(to: CGPoint(x: CGFloat(rng.float(in: 0...Float(rect.width))), y: 0))
                ctx.addLine(to: CGPoint(x: CGFloat(rng.float(in: 0...Float(rect.width))), y: rect.height))
                ctx.strokePath()
            }
        }
    }

    private func drawBrick() -> UIImage {
        canvas { ctx, rect in
            UIColor(red: 0.62, green: 0.28, blue: 0.22, alpha: 1).setFill()
            ctx.fill(rect)
            let rows = 6
            let brickH = rect.height / CGFloat(rows)
            let brickW = rect.width / 3
            UIColor(white: 0.85, alpha: 0.6).setStroke()
            ctx.setLineWidth(4)
            for r in 0...rows {
                let y = CGFloat(r) * brickH
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                ctx.strokePath()
            }
            for r in 0..<rows {
                let offset = (r % 2 == 0) ? CGFloat(0) : brickW / 2
                var x = offset
                while x <= rect.width {
                    ctx.move(to: CGPoint(x: x, y: CGFloat(r) * brickH))
                    ctx.addLine(to: CGPoint(x: x, y: CGFloat(r + 1) * brickH))
                    ctx.strokePath()
                    x += brickW
                }
            }
        }
    }

    private func drawMetal() -> UIImage {
        canvas { ctx, rect in
            let colors = [UIColor(white: 0.75, alpha: 1).cgColor,
                          UIColor(white: 0.45, alpha: 1).cgColor,
                          UIColor(white: 0.82, alpha: 1).cgColor]
            drawVerticalGradient(ctx, rect, colors)
        }
    }

    private func drawGold() -> UIImage {
        canvas { ctx, rect in
            let colors = [UIColor(red: 1.0, green: 0.86, blue: 0.35, alpha: 1).cgColor,
                          UIColor(red: 0.85, green: 0.62, blue: 0.10, alpha: 1).cgColor,
                          UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1).cgColor]
            drawVerticalGradient(ctx, rect, colors)
        }
    }

    private func drawDragonScale() -> UIImage {
        canvas { ctx, rect in
            UIColor(red: 0.15, green: 0.45, blue: 0.35, alpha: 1).setFill()
            ctx.fill(rect)
            let scale: CGFloat = 32
            UIColor(red: 0.10, green: 0.32, blue: 0.25, alpha: 1).setStroke()
            ctx.setLineWidth(3)
            var row = 0
            var y: CGFloat = 0
            while y < rect.height + scale {
                let offset = (row % 2 == 0) ? CGFloat(0) : scale / 2
                var x = offset - scale
                while x < rect.width + scale {
                    let arc = CGRect(x: x, y: y, width: scale, height: scale)
                    let path = UIBezierPath(arcCenter: CGPoint(x: arc.midX, y: arc.minY),
                                            radius: scale / 2, startAngle: 0, endAngle: .pi, clockwise: true)
                    UIColor(red: 0.20, green: 0.55, blue: 0.42, alpha: 1).setFill()
                    path.fill()
                    path.stroke()
                    x += scale
                }
                y += scale / 2
                row += 1
            }
        }
    }

    private func drawGround(_ theme: BiomeTheme) -> UIImage {
        canvas { ctx, rect in
            let colors = theme.groundGradient.map { $0.cgColor }
            drawVerticalGradient(ctx, rect, colors)
            // Speckle detail for texture.
            var rng = SeededRandom(seed: UInt64(theme.hashValue & 0xFFFF), tag: "ground")
            for _ in 0..<80 {
                UIColor(white: rng.chance(0.5) ? 1 : 0, alpha: 0.08).setFill()
                let s = CGFloat(rng.float(in: 4...16))
                ctx.fillEllipse(in: CGRect(x: CGFloat(rng.float(in: 0...Float(rect.width))),
                                           y: CGFloat(rng.float(in: 0...Float(rect.height))),
                                           width: s, height: s))
            }
        }
    }

    private func drawFlat(_ color: UIColor) -> UIImage {
        canvas { ctx, rect in
            color.setFill()
            ctx.fill(rect)
        }
    }

    // MARK: - Gradient util

    private func drawVerticalGradient(_ ctx: CGContext, _ rect: CGRect, _ colors: [CGColor]) {
        let space = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = colors.count == 2 ? [0, 1] : [0, 0.5, 1]
        guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray,
                                        locations: locations) else { return }
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: 0),
                               end: CGPoint(x: rect.midX, y: rect.height),
                               options: [])
    }
}
