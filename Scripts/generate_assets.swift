#!/usr/bin/env swift

import AppKit

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "GeneratedAssets"
let fileManager = FileManager.default
try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

let appIconPath = (outputDirectory as NSString).appendingPathComponent("AppIcon-1024.png")
let statusBarIconPath = (outputDirectory as NSString).appendingPathComponent("StatusBarIconTemplate.png")

func savePNG(image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FloatTranslatorAssets", code: 1)
    }

    try png.write(to: URL(fileURLWithPath: path))
}

func paragraphStyle(alignment: NSTextAlignment) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    return style
}

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.23
    let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.imageInterpolation = .high

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.71, blue: 0.76, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.92, alpha: 1)
    ])!
    gradient.draw(in: background, angle: -45)

    NSColor.white.withAlphaComponent(0.12).setStroke()
    background.lineWidth = size * 0.016
    background.stroke()

    let panelRect = rect.insetBy(dx: size * 0.14, dy: size * 0.16)
    let panel = NSBezierPath(roundedRect: panelRect, xRadius: size * 0.14, yRadius: size * 0.14)
    NSColor.white.withAlphaComponent(0.18).setFill()
    panel.fill()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: panelRect.minX + panelRect.width * 0.42, y: panelRect.minY + panelRect.height * 0.18))
    divider.curve(
        to: NSPoint(x: panelRect.minX + panelRect.width * 0.58, y: panelRect.maxY - panelRect.height * 0.18),
        controlPoint1: NSPoint(x: panelRect.minX + panelRect.width * 0.48, y: panelRect.minY + panelRect.height * 0.42),
        controlPoint2: NSPoint(x: panelRect.minX + panelRect.width * 0.52, y: panelRect.minY + panelRect.height * 0.58)
    )
    NSColor.white.withAlphaComponent(0.9).setStroke()
    divider.lineWidth = size * 0.03
    divider.lineCapStyle = .round
    divider.stroke()

    let dark = NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.24, alpha: 1)
    let leftAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.33, weight: .black),
        .foregroundColor: dark,
        .paragraphStyle: paragraphStyle(alignment: .center)
    ]
    let rightAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.29, weight: .black),
        .foregroundColor: dark,
        .paragraphStyle: paragraphStyle(alignment: .center)
    ]

    let leftRect = NSRect(x: panelRect.minX + panelRect.width * 0.06, y: panelRect.minY + panelRect.height * 0.26, width: panelRect.width * 0.32, height: panelRect.height * 0.42)
    let rightRect = NSRect(x: panelRect.minX + panelRect.width * 0.61, y: panelRect.minY + panelRect.height * 0.24, width: panelRect.width * 0.26, height: panelRect.height * 0.42)
    ("A" as NSString).draw(in: leftRect, withAttributes: leftAttributes)
    ("文" as NSString).draw(in: rightRect, withAttributes: rightAttributes)

    let sparkle = NSBezierPath(ovalIn: NSRect(x: panelRect.maxX - size * 0.16, y: panelRect.maxY - size * 0.2, width: size * 0.07, height: size * 0.07))
    NSColor.white.withAlphaComponent(0.95).setFill()
    sparkle.fill()

    image.unlockFocus()
    return image
}

func drawStatusBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    let panelRect = canvas.insetBy(dx: size * 0.12, dy: size * 0.14)
    let panel = NSBezierPath(roundedRect: panelRect, xRadius: size * 0.18, yRadius: size * 0.18)

    NSColor.black.setStroke()
    panel.lineWidth = size * 0.08
    panel.stroke()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: panelRect.minX + panelRect.width * 0.42, y: panelRect.minY + panelRect.height * 0.2))
    divider.line(to: NSPoint(x: panelRect.minX + panelRect.width * 0.58, y: panelRect.maxY - panelRect.height * 0.2))
    divider.lineWidth = size * 0.07
    divider.lineCapStyle = .round
    divider.stroke()

    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraphStyle(alignment: .center)
    ]

    let leftFont = NSFont.systemFont(ofSize: size * 0.28, weight: .heavy)
    let rightFont = NSFont.systemFont(ofSize: size * 0.25, weight: .heavy)
    let leftRect = NSRect(x: panelRect.minX + panelRect.width * 0.04, y: panelRect.minY + panelRect.height * 0.16, width: panelRect.width * 0.3, height: panelRect.height * 0.38)
    let rightRect = NSRect(x: panelRect.minX + panelRect.width * 0.58, y: panelRect.minY + panelRect.height * 0.14, width: panelRect.width * 0.22, height: panelRect.height * 0.38)
    ("A" as NSString).draw(in: leftRect, withAttributes: attributes.merging([.font: leftFont]) { _, new in new })
    ("文" as NSString).draw(in: rightRect, withAttributes: attributes.merging([.font: rightFont]) { _, new in new })

    image.unlockFocus()
    return image
}

try savePNG(image: drawAppIcon(size: 1024), to: appIconPath)
try savePNG(image: drawStatusBarIcon(size: 36), to: statusBarIconPath)
