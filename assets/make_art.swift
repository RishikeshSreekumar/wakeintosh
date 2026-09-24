// Renders Wakeintosh artwork: icon_1024.png, logo.png, logo-dark.png
// Usage: swift make_art.swift <outdir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func render(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

func linear(_ ctx: CGContext, _ colors: [NSColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [NSColor], at c: CGPoint, r: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}

/// Draws the full icon into a 1024x1024 coordinate space.
func drawIcon(_ ctx: CGContext) {
    // Squircle tile (macOS icon grid: 824pt tile inset 100pt).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: hex(0x000000, 0.35).cgColor)
    ctx.addPath(tilePath); ctx.setFillColor(hex(0x1B1F4B).cgColor); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()

    // Dawn sky: night indigo at top melting into sunrise orange.
    linear(ctx, [hex(0x2B2A6B), hex(0x7B3F8C), hex(0xF26B5B), hex(0xFFB35C)],
           from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))

    // A few fading stars up top.
    for (x, y, r, a) in [(220.0, 830.0, 6.0, 0.9), (330, 870, 4, 0.7), (790, 850, 5, 0.8),
                         (700, 800, 3.5, 0.6), (170, 720, 3.5, 0.5), (860, 730, 4, 0.5)] {
        ctx.setFillColor(hex(0xFFFFFF, a).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    // Rising sun behind the Mac, with glow and rays.
    let sun = CGPoint(x: 512, y: 300)
    radial(ctx, [hex(0xFFE08A, 0.9), hex(0xFFB35C, 0.0)], at: sun, r: 460)
    ctx.saveGState()
    ctx.translateBy(x: sun.x, y: sun.y)
    ctx.setFillColor(hex(0xFFE7A3, 0.35).cgColor)
    for i in 0..<14 {
        ctx.saveGState()
        ctx.rotate(by: CGFloat(i) * .pi / 7)
        ctx.move(to: CGPoint(x: -18, y: 250)); ctx.addLine(to: CGPoint(x: 18, y: 250))
        ctx.addLine(to: CGPoint(x: 34, y: 520)); ctx.addLine(to: CGPoint(x: -34, y: 520)); ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()
    ctx.setFillColor(hex(0xFFD36E).cgColor)
    ctx.fillEllipse(in: CGRect(x: sun.x - 230, y: sun.y - 230, width: 460, height: 460))

    ctx.restoreGState()

    // Ground / horizon.

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let horizon = CGMutablePath()
    horizon.move(to: CGPoint(x: 100, y: 230))
    horizon.addQuadCurve(to: CGPoint(x: 924, y: 230), control: CGPoint(x: 512, y: 290))
    horizon.addLine(to: CGPoint(x: 924, y: 100)); horizon.addLine(to: CGPoint(x: 100, y: 100)); horizon.closeSubpath()
    ctx.addPath(horizon); ctx.clip()
    linear(ctx, [hex(0x4A2A63), hex(0x22183B)], from: CGPoint(x: 512, y: 280), to: CGPoint(x: 512, y: 100))
    ctx.restoreGState()

    // Compact retro Mac.
    let body = CGRect(x: 312, y: 210, width: 400, height: 480)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: hex(0x1A0F2E, 0.55).cgColor)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.setFillColor(hex(0xF1E9D8).cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 44, cornerHeight: 44, transform: nil)); ctx.clip()
    linear(ctx, [hex(0xFBF6EB), hex(0xE6DCC6)], from: CGPoint(x: body.minX, y: body.maxY), to: CGPoint(x: body.maxX, y: body.minY))
    // Bottom chin shading.
    ctx.setFillColor(hex(0xD9CDB3, 0.6).cgColor)
    ctx.fill(CGRect(x: body.minX, y: body.minY, width: body.width, height: 36))
    ctx.restoreGState()

    // Screen bezel + glowing screen.
    let bezel = CGRect(x: 356, y: 380, width: 312, height: 262)
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 28, cornerHeight: 28, transform: nil))
    ctx.setFillColor(hex(0xCFC3A8).cgColor); ctx.fillPath()
    let screen = bezel.insetBy(dx: 22, dy: 22)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.saveGState()
    ctx.addPath(screenPath); ctx.clip()
    linear(ctx, [hex(0x2E3B7A), hex(0x15183A)], from: CGPoint(x: screen.midX, y: screen.maxY), to: CGPoint(x: screen.midX, y: screen.minY))
    radial(ctx, [hex(0x7FE7FF, 0.28), hex(0x7FE7FF, 0)], at: CGPoint(x: screen.midX, y: screen.midY), r: 170)
    ctx.restoreGState()

    // Wide-open eyes.
    let eyeY = screen.midY + 8
    for dx in [-60.0, 60.0] {
        let c = CGPoint(x: screen.midX + dx, y: eyeY)
        let eye = CGRect(x: c.x - 44, y: c.y - 50, width: 88, height: 100)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 18, color: hex(0x9FF0FF, 0.8).cgColor)
        ctx.setFillColor(hex(0xFFFFFF).cgColor); ctx.fillEllipse(in: eye)
        ctx.restoreGState()
        // Iris + pupil, looking slightly up (it's morning!).
        let iris = CGRect(x: c.x - 26, y: c.y - 16, width: 52, height: 52)
        ctx.saveGState()
        ctx.addEllipse(in: iris); ctx.clip()
        linear(ctx, [hex(0x36C2E8), hex(0x1C5FB8)], from: CGPoint(x: iris.midX, y: iris.maxY), to: CGPoint(x: iris.midX, y: iris.minY))
        ctx.restoreGState()
        ctx.setFillColor(hex(0x0D1026).cgColor)
        ctx.fillEllipse(in: iris.insetBy(dx: 12, dy: 12))
        ctx.setFillColor(hex(0xFFFFFF).cgColor)
        ctx.fillEllipse(in: CGRect(x: iris.midX + 2, y: iris.midY + 6, width: 12, height: 12))
        // Lashes.
        ctx.setStrokeColor(hex(0xFFFFFF, 0.9).cgColor); ctx.setLineWidth(7); ctx.setLineCap(.round)
        for a in [-0.5, 0.0, 0.5] {
            let ang = CGFloat.pi / 2 + CGFloat(a)
            let p1 = CGPoint(x: c.x + cos(ang) * 58, y: c.y + sin(ang) * 62)
            let p2 = CGPoint(x: c.x + cos(ang) * 76, y: c.y + sin(ang) * 80)
            ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()
        }
    }

    // Screen glare.
    ctx.saveGState()
    ctx.addPath(screenPath); ctx.clip()
    ctx.setFillColor(hex(0xFFFFFF, 0.07).cgColor)
    ctx.move(to: CGPoint(x: screen.minX, y: screen.maxY))
    ctx.addLine(to: CGPoint(x: screen.minX + 120, y: screen.maxY))
    ctx.addLine(to: CGPoint(x: screen.minX, y: screen.maxY - 120)); ctx.closePath(); ctx.fillPath()
    ctx.restoreGState()

    // Floppy slot + power light.
    ctx.addPath(CGPath(roundedRect: CGRect(x: 520, y: 300, width: 130, height: 16), cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.setFillColor(hex(0x8F826A).cgColor); ctx.fillPath()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 10, color: hex(0x5CFF9D).cgColor)
    ctx.setFillColor(hex(0x5CFF9D).cgColor)
    ctx.fillEllipse(in: CGRect(x: 372, y: 298, width: 20, height: 20))
    ctx.restoreGState()

    // Tile edge highlight.
    ctx.addPath(tilePath)
    ctx.setStrokeColor(hex(0xFFFFFF, 0.18).cgColor); ctx.setLineWidth(4); ctx.strokePath()
}

// Icon
save(render(1024, 1024, drawIcon), "icon_1024.png")

// Logo: icon mark + rounded wordmark.
func drawLogo(dark: Bool) -> NSBitmapImageRep {
    render(1820, 560) { ctx in
        ctx.saveGState()
        ctx.translateBy(x: 0, y: 8)
        ctx.scaleBy(x: 0.53, y: 0.53)
        drawIcon(ctx)
        ctx.restoreGState()

        let base = NSFont.systemFont(ofSize: 220, weight: .heavy)
        let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: 220)!
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Wake", attributes: [.font: font, .foregroundColor: hex(0xF26B5B), .kern: -4]))
        text.append(NSAttributedString(string: "intosh", attributes: [.font: font, .foregroundColor: dark ? hex(0xF4EFE6) : hex(0x2B2A6B), .kern: -4]))
        let size = text.size()
        text.draw(at: CGPoint(x: 560, y: (560 - size.height) / 2 + 12))

        let tagFont = NSFont(descriptor: NSFont.systemFont(ofSize: 54, weight: .semibold).fontDescriptor.withDesign(.rounded)!, size: 54)!
        NSAttributedString(string: "keeps your Mac wide awake", attributes: [
            .font: tagFont, .foregroundColor: dark ? hex(0xF4EFE6, 0.6) : hex(0x2B2A6B, 0.55), .kern: 1,
        ]).draw(at: CGPoint(x: 572, y: 96))
    }
}
save(drawLogo(dark: false), "logo.png")
save(drawLogo(dark: true), "logo-dark.png")
print("ok")
