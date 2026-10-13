#!/usr/bin/env swift
// Generates Void Echo's app icon (all macOS sizes) into Assets.xcassets/AppIcon.appiconset.
// Void's eclipse on its night background — a dark disc over a luminous ring — and, on the lit
// side, three arcs going out and fading: a voice carrying. Of the Void family at first glance.
// Usage: swift scripts/make-icon.swift [output folder] [--preview file.png]
import AppKit
import CoreGraphics

let args = Array(CommandLine.arguments.dropFirst())
let previewPath = args.firstIndex(of: "--preview").map { args[$0 + 1] }
let output = URL(fileURLWithPath: args.first.flatMap { $0.hasPrefix("--") ? nil : $0 } ?? "VoidEcho/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // macOS icon grid: 824/1024 body with ~185/1024 corner radius.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = body.width * 0.225
    let path = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: color(0x000000, 0.45))
    ctx.addPath(path); ctx.setFillColor(color(0x0B0B0E)); ctx.fillPath()
    ctx.restoreGState()

    // Background: deep night gradient, a faint violet glow around the eclipse.
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [color(0x1B1A26), color(0x07070A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])

    // The mark — eclipse and echo together — centered on the icon. The arcs open to the right,
    // symmetric about the middle: the group spans from the eclipse's left edge (−r) to the outer
    // arc (+2.26 r and half a stroke), so its center lies 0.66 r right of the eclipse's.
    let r = body.width * 0.19
    let arcs: [(radius: CGFloat, alpha: CGFloat)] = [(1.42, 0.85), (1.84, 0.55), (2.26, 0.28)]
    let stroke = r * 0.13
    let reach = r * arcs.last!.radius + stroke / 2
    let center = CGPoint(x: body.midX - (reach - r) / 2, y: body.midY)
    let glow = CGGradient(colorsSpace: space, colors: [color(0x7B6CFF, 0.38), color(0x7B6CFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: body.width * 0.55, options: [])

    // The echo: three arcs on the lit side, wider and fainter as they go.
    ctx.setLineCap(.round)
    ctx.setLineWidth(stroke)
    for arc in arcs {
        ctx.setStrokeColor(color(0xC4BAFF, arc.alpha))
        ctx.addArc(center: center, radius: r * arc.radius, startAngle: -.pi / 4, endAngle: .pi / 4, clockwise: false)
        ctx.strokePath()
    }

    // The eclipse: the luminous ring, lit from the right, then the dark disc moved a little left.
    ctx.saveGState()
    let halo = CGGradient(colorsSpace: space, colors: [color(0x9D8FFF, 0.45), color(0x9D8FFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: center, startRadius: r * 0.85, endCenter: center, endRadius: r * 1.35, options: [])
    ctx.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    ctx.clip()
    let corona = CGGradient(colorsSpace: space, colors: [color(0x4B3FD0), color(0xA597FF), color(0xF6F3FF)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(corona, start: CGPoint(x: center.x - r, y: center.y), end: CGPoint(x: center.x + r, y: center.y), options: [])
    ctx.restoreGState()
    let vr = r * 0.86
    let offset = r * 0.13
    ctx.addEllipse(in: CGRect(x: center.x - vr - offset, y: center.y - vr, width: 2 * vr, height: 2 * vr))
    ctx.setFillColor(color(0x08080B))
    ctx.fillPath()
    ctx.restoreGState()

    // Hairline highlight on the icon's edge.
    ctx.addPath(path)
    ctx.setStrokeColor(color(0xFFFFFF, 0.08))
    ctx.setLineWidth(max(1, s * 0.004))
    ctx.strokePath()

    let image = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

if let previewPath {
    // Preview: the icon at 512, 128, 64, 32 and 16 px side by side.
    let sizes = [512, 128, 64, 32, 16]
    let width = sizes.reduce(0, +) + 20 * (sizes.count + 1)
    let sheet = NSImage(size: NSSize(width: width, height: 552))
    sheet.lockFocus()
    NSColor(white: 0.93, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: 552).fill()
    var x = 20
    for size in sizes {
        NSImage(data: render(size * 2))!.draw(in: NSRect(x: x, y: 20, width: size, height: size))
        x += size + 20
    }
    sheet.unlockFocus()
    let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: previewPath))
    print("Preview written to \(previewPath)")
    exit(0)
}

try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try! render(px).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: output.appendingPathComponent("Contents.json"))
print("Icon written to \(output.path)")
