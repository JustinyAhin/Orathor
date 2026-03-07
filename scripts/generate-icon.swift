#!/usr/bin/swift

import AppKit
import CoreGraphics

// MARK: - Icon Drawing

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // --- Squircle background ---
    let cornerRadius = size * 0.22
    let squirclePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Dark background
    let bgColor = NSColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1.0)
    bgColor.setFill()
    squirclePath.fill()

    // Subtle inner shadow / depth
    context.saveGState()
    squirclePath.addClip()

    // Amber gradient glow from bottom center
    let gradientColors = [
        NSColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 0.35).cgColor, // #D97706 with alpha
        NSColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 0.0).cgColor,
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: gradientLocations) {
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: size * 0.5, y: size * 0.15),
            startRadius: 0,
            endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
            endRadius: size * 0.6,
            options: []
        )
    }
    context.restoreGState()

    // --- Microphone ---
    // Clip to squircle for all content
    context.saveGState()
    squirclePath.addClip()

    let micWidth = size * 0.22
    let micHeight = size * 0.32
    let micX = (size - micWidth) / 2
    let micY = size * 0.42

    // Mic body (rounded capsule)
    let micRect = CGRect(x: micX, y: micY, width: micWidth, height: micHeight)
    let micPath = NSBezierPath(roundedRect: micRect, xRadius: micWidth / 2, yRadius: micWidth / 2)

    // Amber gradient on mic body
    context.saveGState()
    micPath.addClip()
    let micGradientColors = [
        NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0).cgColor, // #F59E0B gold
        NSColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1.0).cgColor, // #D97706 amber
    ] as CFArray
    if let micGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: micGradientColors, locations: [0.0, 1.0]) {
        context.drawLinearGradient(
            micGradient,
            start: CGPoint(x: size / 2, y: micY + micHeight),
            end: CGPoint(x: size / 2, y: micY),
            options: []
        )
    }
    context.restoreGState()

    // Mic grille lines
    let lineColor = NSColor(red: 0.75, green: 0.40, blue: 0.02, alpha: 0.4)
    lineColor.setStroke()
    let lineWidth = max(1.0, size * 0.008)
    let lineSpacing = micHeight * 0.12
    let grillTop = micY + micHeight * 0.55
    let grillBottom = micY + micHeight * 0.85
    var y = grillTop
    while y <= grillBottom {
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: micX + micWidth * 0.25, y: y))
        linePath.line(to: NSPoint(x: micX + micWidth * 0.75, y: y))
        linePath.lineWidth = lineWidth
        linePath.stroke()
        y += lineSpacing
    }

    // --- Arc around mic (the holder) ---
    let arcRadius = micWidth * 0.75
    let arcCenterX = size / 2
    let arcCenterY = micY + micWidth / 2  // align with bottom of mic capsule curve
    let arcLineWidth = max(2.0, size * 0.025)

    let arcPath = NSBezierPath()
    // Draw arc from left to right, going under the mic
    arcPath.appendArc(
        withCenter: NSPoint(x: arcCenterX, y: arcCenterY),
        radius: arcRadius,
        startAngle: 220,  // left side
        endAngle: 320,    // right side
        clockwise: false
    )
    arcPath.lineWidth = arcLineWidth
    arcPath.lineCapStyle = .round
    NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.9).setStroke()
    arcPath.stroke()

    // --- Stand (vertical line below arc) ---
    let standTop = arcCenterY - arcRadius * sin(40 * .pi / 180) // bottom of arc
    let standBottom = size * 0.22
    let standPath = NSBezierPath()
    standPath.move(to: NSPoint(x: size / 2, y: standTop))
    standPath.line(to: NSPoint(x: size / 2, y: standBottom))
    standPath.lineWidth = arcLineWidth
    standPath.lineCapStyle = .round
    NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.9).setStroke()
    standPath.stroke()

    // --- Base (horizontal line at bottom of stand) ---
    let baseWidth = size * 0.18
    let basePath = NSBezierPath()
    basePath.move(to: NSPoint(x: size / 2 - baseWidth / 2, y: standBottom))
    basePath.line(to: NSPoint(x: size / 2 + baseWidth / 2, y: standBottom))
    basePath.lineWidth = arcLineWidth
    basePath.lineCapStyle = .round
    NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.9).setStroke()
    basePath.stroke()

    // --- Sound waves (right side) ---
    let waveCenter = CGPoint(x: micX + micWidth + size * 0.02, y: micY + micHeight * 0.65)
    let waveColor1 = NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.6)
    let waveColor2 = NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.35)
    let waveColor3 = NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.15)
    let waveLineWidth = max(1.5, size * 0.018)

    for (i, color) in [waveColor1, waveColor2, waveColor3].enumerated() {
        let waveRadius = size * 0.06 + CGFloat(i) * size * 0.045
        let wavePath = NSBezierPath()
        wavePath.appendArc(
            withCenter: NSPoint(x: waveCenter.x, y: waveCenter.y),
            radius: waveRadius,
            startAngle: -40,
            endAngle: 40,
            clockwise: false
        )
        wavePath.lineWidth = waveLineWidth
        wavePath.lineCapStyle = .round
        color.setStroke()
        wavePath.stroke()
    }

    // Mirror waves on left side
    let waveCenterLeft = CGPoint(x: micX - size * 0.02, y: micY + micHeight * 0.65)
    for (i, color) in [waveColor1, waveColor2, waveColor3].enumerated() {
        let waveRadius = size * 0.06 + CGFloat(i) * size * 0.045
        let wavePath = NSBezierPath()
        wavePath.appendArc(
            withCenter: NSPoint(x: waveCenterLeft.x, y: waveCenterLeft.y),
            radius: waveRadius,
            startAngle: 140,
            endAngle: 220,
            clockwise: false
        )
        wavePath.lineWidth = waveLineWidth
        wavePath.lineCapStyle = .round
        color.setStroke()
        wavePath.stroke()
    }

    context.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Export

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    // Use NSBitmapImageRep directly to control exact pixel dimensions
    // (NSImage + lockFocus doubles pixels on Retina displays)
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap for size \(pixelSize)")
        return
    }

    bitmapRep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
        operation: .copy,
        fraction: 1.0
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for size \(pixelSize)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path) (\(pixelSize)x\(pixelSize))")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// MARK: - Main

let outputDir = "Orathor/Assets.xcassets/AppIcon.appiconset"

// Draw at highest resolution
let masterIcon = drawIcon(size: 1024)

// Required sizes for macOS: (point size, scale) -> pixel size
let sizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// Generate all sizes
for size in sizes {
    let pixelSize = size.points * size.scale
    let filename: String
    if size.scale == 1 {
        filename = "icon_\(size.points)x\(size.points).png"
    } else {
        filename = "icon_\(size.points)x\(size.points)@2x.png"
    }
    let path = "\(outputDir)/\(filename)"
    savePNG(masterIcon, to: path, pixelSize: pixelSize)
}

// Update Contents.json
let contentsJSON = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

do {
    try contentsJSON.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
    print("Updated Contents.json")
} catch {
    print("Failed to update Contents.json: \(error)")
}

print("Done! Icon generated successfully.")
