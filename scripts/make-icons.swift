// Generates the app icon and the menu bar icon from vector shapes.
// Usage: swift scripts/make-icons.swift <output-dir>
//   <output-dir>/AppIcon.appiconset/icon_{16..1024}.png  (yellow tile, black hand, white slits)
//   <output-dir>/MenuBarIcon.imageset/menubar{,@2x}.png  (solid hand, slits cut out, template)
import AppKit

let yellow = CGColor(srgbRed: 0.98, green: 0.80, blue: 0.08, alpha: 1)
let yellowDark = CGColor(srgbRed: 0.94, green: 0.69, blue: 0.0, alpha: 1)
let ink = CGColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

// MARK: - Shapes (1024-unit canvas, y pointing down)

/// Hand silhouette: union of simple rounded shapes (non-zero fill).
func handPath() -> CGPath {
    let p = CGMutablePath()
    p.addPath(rr(466, 160, 92, 330, 46))                         // middle finger
    p.addPath(rr(382, 386, 100, 156, 50))                        // index knuckle
    p.addPath(rr(548, 398, 92, 156, 46))                         // ring knuckle
    p.addPath(rr(616, 428, 82, 150, 41))                         // pinky knuckle
    p.addPath(rr(364, 446, 332, 262, 124))                       // palm
    let t = CGAffineTransform(translationX: 372, y: 598).rotated(by: -0.30)
    p.addPath(rr(-58, -104, 116, 212, 58), transform: t)         // thumb, slightly tilted
    p.addPath(rr(410, 650, 220, 110, 44))                        // wrist
    p.addPath(rr(370, 740, 300, 104, 52))                        // cuff
    return p
}

/// A tapered slit: round head at the top, point at the bottom.
func slit(cx: CGFloat, top: CGFloat, length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
    let r = width / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -r, y: 0))
    p.addArc(center: .zero, radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
    p.addQuadCurve(to: CGPoint(x: 0, y: length), control: CGPoint(x: r * 0.6, y: length * 0.55))
    p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -r * 0.6, y: length * 0.55))
    p.closeSubpath()
    var t = CGAffineTransform(translationX: cx, y: top + r).rotated(by: angle)
    return p.copy(using: &t)!
}

/// The three slits. Outer ones lean in so they converge downwards.
/// `boldness` widens them for tiny renderings (menu bar).
func slits(boldness: CGFloat = 1) -> [CGPath] {
    [slit(cx: 446, top: 552, length: 112, width: 30 * boldness, angle: -0.20),
     slit(cx: 512, top: 530, length: 140, width: 36 * boldness, angle: 0),
     slit(cx: 578, top: 552, length: 112, width: 30 * boldness, angle: 0.20)]
}

// MARK: - Rendering

func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func write(_ ctx: CGContext, _ url: URL) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

/// App icon: yellow rounded tile (Apple grid: 824 px tile, 100 px margin), black hand, white slits.
func appIcon(size: Int) -> CGContext {
    let ctx = context(size, size)
    let s = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: s, y: -s)

    let tile = rr(100, 100, 824, 824, 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(tile); ctx.setFillColor(yellow); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [yellow, yellowDark] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    ctx.restoreGState()

    ctx.addPath(handPath()); ctx.setFillColor(ink); ctx.fillPath()
    // Slightly bolder slits at small sizes so they stay visible.
    let bold: CGFloat = size <= 32 ? 1.6 : size <= 64 ? 1.25 : 1
    for sl in slits(boldness: bold) { ctx.addPath(sl) }
    ctx.setFillColor(white); ctx.fillPath()
    return ctx
}

/// Menu bar icon: solid hand with the slits cut out, cropped to the hand, 18 pt tall.
func menuBarIcon(scale: Int) -> CGContext {
    let box = handPath().boundingBox.insetBy(dx: -8, dy: -8)
    let h = 18 * scale
    let w = Int((CGFloat(h) * box.width / box.height).rounded(.up))
    let ctx = context(w, h)
    let s = CGFloat(h) / box.height
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: s, y: -s)
    ctx.translateBy(x: -box.minX, y: -box.minY)

    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(handPath()); ctx.setFillColor(white); ctx.fillPath()
    ctx.setBlendMode(.clear)
    for sl in slits(boldness: 1.7) { ctx.addPath(sl) }
    ctx.fillPath()
    ctx.endTransparencyLayer()
    return ctx
}

// MARK: - Main

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let appDir = out.appendingPathComponent("AppIcon.appiconset")
let barDir = out.appendingPathComponent("MenuBarIcon.imageset")
for d in [appDir, barDir] { try! FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }

for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(appIcon(size: size), appDir.appendingPathComponent("icon_\(size).png"))
}
for (scale, suffix) in [(1, ""), (2, "@2x")] {
    write(menuBarIcon(scale: scale), barDir.appendingPathComponent("menubar\(suffix).png"))
}
print("Icons written to \(out.path)")
