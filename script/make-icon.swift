#!/usr/bin/env swift
import AppKit

// Mac SMB Keeper icon: network drive with a shield/checkmark
func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 512.0 // scale factor

    // --- Background: rounded rectangle with gradient ---
    let bgRect = CGRect(x: 20 * s, y: 20 * s, width: 472 * s, height: 472 * s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 100 * s, cornerHeight: 100 * s, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1.0),
        CGColor(red: 0.08, green: 0.25, blue: 0.60, alpha: 1.0),
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: size / 2, y: size * 0.96), end: CGPoint(x: size / 2, y: size * 0.04), options: [])
    ctx.restoreGState()

    // --- Hard drive body ---
    let driveW: CGFloat = 280 * s
    let driveH: CGFloat = 80 * s
    let driveX: CGFloat = (size - driveW) / 2
    let driveY: CGFloat = 145 * s

    // Drive shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4 * s), blur: 12 * s, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    let driveShadowRect = CGRect(x: driveX, y: driveY, width: driveW, height: driveH)
    let driveShadowPath = CGPath(roundedRect: driveShadowRect, cornerWidth: 14 * s, cornerHeight: 14 * s, transform: nil)
    ctx.setFillColor(CGColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0))
    ctx.addPath(driveShadowPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Drive body
    let driveRect = CGRect(x: driveX, y: driveY, width: driveW, height: driveH)
    let drivePath = CGPath(roundedRect: driveRect, cornerWidth: 14 * s, cornerHeight: 14 * s, transform: nil)
    ctx.saveGState()
    ctx.addPath(drivePath)
    ctx.clip()
    let driveGrad = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
        CGColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1.0),
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(driveGrad, start: CGPoint(x: driveX, y: driveY + driveH), end: CGPoint(x: driveX, y: driveY), options: [])
    ctx.restoreGState()

    // Drive indicator light
    let lightR: CGFloat = 8 * s
    let lightX: CGFloat = driveX + driveW - 35 * s
    let lightY: CGFloat = driveY + driveH / 2
    ctx.setFillColor(CGColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: lightX - lightR, y: lightY - lightR, width: lightR * 2, height: lightR * 2))

    // Drive slot lines
    ctx.setStrokeColor(CGColor(red: 0.65, green: 0.67, blue: 0.72, alpha: 1.0))
    ctx.setLineWidth(2.5 * s)
    for i in 0..<3 {
        let lineY = driveY + 22 * s + CGFloat(i) * 18 * s
        ctx.move(to: CGPoint(x: driveX + 25 * s, y: lineY))
        ctx.addLine(to: CGPoint(x: driveX + 120 * s, y: lineY))
        ctx.strokePath()
    }

    // --- Network lines going up from drive ---
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.8))
    ctx.setLineWidth(3 * s)
    ctx.setLineCap(.round)

    let topCenter = CGPoint(x: size / 2, y: driveY + driveH)
    // Center line
    ctx.move(to: topCenter)
    ctx.addLine(to: CGPoint(x: size / 2, y: driveY + driveH + 60 * s))
    ctx.strokePath()
    // Left branch
    ctx.move(to: CGPoint(x: size / 2, y: driveY + driveH + 35 * s))
    ctx.addLine(to: CGPoint(x: size / 2 - 55 * s, y: driveY + driveH + 65 * s))
    ctx.strokePath()
    // Right branch
    ctx.move(to: CGPoint(x: size / 2, y: driveY + driveH + 35 * s))
    ctx.addLine(to: CGPoint(x: size / 2 + 55 * s, y: driveY + driveH + 65 * s))
    ctx.strokePath()

    // Small dots at branch ends
    let dotR: CGFloat = 5 * s
    ctx.setFillColor(CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.9))
    for p in [
        CGPoint(x: size / 2, y: driveY + driveH + 60 * s),
        CGPoint(x: size / 2 - 55 * s, y: driveY + driveH + 65 * s),
        CGPoint(x: size / 2 + 55 * s, y: driveY + driveH + 65 * s),
    ] {
        ctx.fillEllipse(in: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
    }

    // --- Shield / checkmark badge (lower-right area) ---
    let shieldCX: CGFloat = size / 2 + 75 * s
    let shieldCY: CGFloat = 160 * s
    let shieldW: CGFloat = 110 * s
    let shieldH: CGFloat = 130 * s

    // Shield shape
    let shield = CGMutablePath()
    shield.move(to: CGPoint(x: shieldCX, y: shieldCY + shieldH / 2))
    shield.addQuadCurve(to: CGPoint(x: shieldCX - shieldW / 2, y: shieldCY + shieldH * 0.15),
                        control: CGPoint(x: shieldCX - shieldW / 2, y: shieldCY + shieldH / 2))
    shield.addLine(to: CGPoint(x: shieldCX - shieldW / 2, y: shieldCY - shieldH * 0.05))
    shield.addQuadCurve(to: CGPoint(x: shieldCX, y: shieldCY - shieldH / 2),
                        control: CGPoint(x: shieldCX - shieldW * 0.15, y: shieldCY - shieldH * 0.35))
    shield.addQuadCurve(to: CGPoint(x: shieldCX + shieldW / 2, y: shieldCY - shieldH * 0.05),
                        control: CGPoint(x: shieldCX + shieldW * 0.15, y: shieldCY - shieldH * 0.35))
    shield.addLine(to: CGPoint(x: shieldCX + shieldW / 2, y: shieldCY + shieldH * 0.15))
    shield.addQuadCurve(to: CGPoint(x: shieldCX, y: shieldCY + shieldH / 2),
                        control: CGPoint(x: shieldCX + shieldW / 2, y: shieldCY + shieldH / 2))
    shield.closeSubpath()

    // Shield fill
    ctx.saveGState()
    ctx.addPath(shield)
    ctx.clip()
    let shieldGrad = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.18, green: 0.78, blue: 0.38, alpha: 1.0),
        CGColor(red: 0.12, green: 0.58, blue: 0.28, alpha: 1.0),
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(shieldGrad,
                           start: CGPoint(x: shieldCX, y: shieldCY + shieldH / 2),
                           end: CGPoint(x: shieldCX, y: shieldCY - shieldH / 2),
                           options: [])
    ctx.restoreGState()

    // Checkmark on shield
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(8 * s)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: shieldCX - 22 * s, y: shieldCY - 2 * s))
    ctx.addLine(to: CGPoint(x: shieldCX - 5 * s, y: shieldCY - 20 * s))
    ctx.addLine(to: CGPoint(x: shieldCX + 25 * s, y: shieldCY + 22 * s))
    ctx.strokePath()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        print("Failed to generate PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved \(path)")
    } catch {
        print("Error saving \(path): \(error)")
    }
}

// Icon sizes for macOS: 16, 32, 64, 128, 256, 512, 1024
let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let scriptDir = CommandLine.arguments[0]
let projectDir = URL(fileURLWithPath: scriptDir).deletingLastPathComponent().deletingLastPathComponent()
let iconDir = projectDir.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")

for entry in sizes {
    let image = generateIcon(size: CGFloat(entry.size))
    let path = iconDir.appendingPathComponent("\(entry.name).png").path
    savePNG(image, to: path)
}

// Update Contents.json
let contents: [String: Any] = [
    "images": sizes.map { entry -> [String: String] in
        let baseName = entry.name
        let parts = baseName.replacingOccurrences(of: "icon_", with: "").split(separator: "@")
        let sizeStr = String(parts[0])
        let scale = parts.count > 1 ? String(parts[1]) : "1x"
        return [
            "filename": "\(entry.name).png",
            "idiom": "mac",
            "scale": scale,
            "size": sizeStr,
        ]
    },
    "info": [
        "author": "xcode",
        "version": 1,
    ] as [String: Any],
]

let jsonData = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
let jsonPath = iconDir.appendingPathComponent("Contents.json").path
try! jsonData.write(to: URL(fileURLWithPath: jsonPath))
print("Updated Contents.json")
