// scripts/make-icon.swift
// Generates Resources/AppIcon.icns from vector drawing (no external assets).
//
// Usage:  swift scripts/make-icon.swift <output.icns> [iconset-dir]
// Requires: macOS with `iconutil` (ships with the system).

import Foundation
import CoreGraphics
import ImageIO

// MARK: - Geometry helpers

/// Superellipse (squircle) path — approximates Apple's continuous corners.
func squirclePath(size: CGFloat, n: Double = 5.0) -> CGPath {
    let path = CGMutablePath()
    let a = size / 2
    let count = 256
    for i in 0...count {
        let t = Double(i) / Double(count) * 2.0 * Double.pi
        let cosT = cos(t), sinT = sin(t)
        let sx: Double = cosT < 0 ? -1 : 1
        let sy: Double = sinT < 0 ? -1 : 1
        let x = a * sx * pow(abs(cosT), 2.0 / n)
        let y = a * sy * pow(abs(sinT), 2.0 / n)
        let p = CGPoint(x: size / 2 + CGFloat(x), y: size / 2 + CGFloat(y))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
}

/// One sakura petal pointing up (−Y), with the characteristic notch at the tip.
func petalPath(scale: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let w = 0.32 * scale      // petal half width
    let tip = 0.98 * scale    // tip distance from center
    let notchH = 0.14 * scale
    p.move(to: CGPoint(x: 0, y: 0))
    p.addCurve(to: CGPoint(x: -w, y: -tip + notchH),
               control1: CGPoint(x: -w * 0.95, y: -0.25 * scale),
               control2: CGPoint(x: -w * 1.08, y: -0.66 * scale))
    p.addLine(to: CGPoint(x: -w * 0.62, y: -tip))
    p.addLine(to: CGPoint(x: 0, y: -tip + notchH * 1.9))
    p.addLine(to: CGPoint(x: w * 0.62, y: -tip))
    p.addLine(to: CGPoint(x: w, y: -tip + notchH))
    p.addCurve(to: CGPoint(x: 0, y: 0),
               control1: CGPoint(x: w * 1.08, y: -0.66 * scale),
               control2: CGPoint(x: w * 0.95, y: -0.25 * scale))
    p.closeSubpath()
    return p
}

func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// MARK: - Rendering

func drawIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    guard let ctx = CGContext(data: nil,
                              width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

    // macOS icon canvas convention: content occupies ~82.5% centered.
    let canvasInset = s * 0.0875
    let canvasSize = s - canvasInset * 2
    // Work in canvas-local coordinates.
    ctx.translateBy(x: canvasInset, y: canvasInset)
    let canvas = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

    // Soft blush background gradient (kept subtle and neutral).
    ctx.saveGState()
    ctx.addPath(squirclePath(size: canvas.width))
    ctx.clip()
    let colors = [rgba(1.00, 0.90, 0.93), rgba(0.97, 0.72, 0.80)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: canvas.midX, y: canvas.maxY),
                           end: CGPoint(x: canvas.midX, y: canvas.minY),
                           options: [])
    // Hairline inner highlight.
    ctx.setStrokeColor(rgba(1, 1, 1, 0.35))
    ctx.setLineWidth(canvas.width * 0.012)
    ctx.addPath(squirclePath(size: canvas.width))
    ctx.strokePath()
    ctx.restoreGState()

    // Blossom: 5 notched petals.
    let blossomR = canvas.width * 0.34
    let cx = canvas.midX, cy = canvas.midY

    // Soft shadow under the blossom.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -canvas.width * 0.012),
                  blur: canvas.width * 0.025,
                  color: rgba(0.55, 0.15, 0.25, 0.28))
    ctx.setFillColor(rgba(1, 1, 1, 0.95))
    for i in 0..<5 {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: CGFloat(i) * 72 * .pi / 180)
        ctx.addPath(petalPath(scale: blossomR))
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Petal shading: slightly deeper pink toward the center.
    ctx.saveGState()
    for i in 0..<5 {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: CGFloat(i) * 72 * .pi / 180)
        ctx.addPath(petalPath(scale: blossomR))
        ctx.clip()
        let petalGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   colors: [rgba(1, 1, 1, 0.0), rgba(1.0, 0.82, 0.88, 0.55)] as CFArray,
                                   locations: [0.55, 1.0])!
        ctx.drawLinearGradient(petalGrad,
                               start: CGPoint(x: 0, y: -blossomR),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Stamens: center disc + dots.
    ctx.setFillColor(rgba(0.99, 0.80, 0.86, 1))
    ctx.fillEllipse(in: CGRect(x: cx - blossomR * 0.10, y: cy - blossomR * 0.10,
                               width: blossomR * 0.20, height: blossomR * 0.20))
    for i in 0..<5 {
        let angle = CGFloat(i) * 72 * .pi / 180 - .pi / 2
        let r = blossomR * 0.155
        let px = cx + cos(angle) * r
        let py = cy + sin(angle) * r
        ctx.setFillColor(rgba(1, 0.97, 0.86, 1))
        ctx.fillEllipse(in: CGRect(x: px - blossomR * 0.035, y: py - blossomR * 0.035,
                                   width: blossomR * 0.07, height: blossomR * 0.07))
    }

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// MARK: - Main

let arguments = CommandLine.arguments
let output = arguments.count > 1 ? arguments[1] : "Resources/AppIcon.icns"
let iconsetDir = arguments.count > 2 ? arguments[2] : "build/icon.iconset"

let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

struct Variant {
    let name: String
    let pixels: Int
}

let variants: [Variant] = [
    Variant(name: "icon_16x16.png", pixels: 16),
    Variant(name: "icon_16x16@2x.png", pixels: 32),
    Variant(name: "icon_32x32.png", pixels: 32),
    Variant(name: "icon_32x32@2x.png", pixels: 64),
    Variant(name: "icon_128x128.png", pixels: 128),
    Variant(name: "icon_128x128@2x.png", pixels: 256),
    Variant(name: "icon_256x256.png", pixels: 256),
    Variant(name: "icon_256x256@2x.png", pixels: 512),
    Variant(name: "icon_512x512.png", pixels: 512),
    Variant(name: "icon_512x512@2x.png", pixels: 1024),
]

for variant in variants {
    guard let image = drawIcon(size: variant.pixels) else {
        FileHandle.standardError.write("Failed to render \(variant.name)\n".data(using: .utf8)!)
        exit(1)
    }
    let url = URL(fileURLWithPath: iconsetDir).appendingPathComponent(variant.name)
    guard writePNG(image, to: url) else {
        FileHandle.standardError.write("Failed to write \(variant.name)\n".data(using: .utf8)!)
        exit(1)
    }
}

// Invoke iconutil.
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir, "-o", output]
try? process.run()
process.waitUntilExit()
if process.terminationStatus == 0 {
    print("✅ Wrote \(output)")
} else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
