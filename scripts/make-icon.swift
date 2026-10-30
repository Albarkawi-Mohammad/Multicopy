#!/usr/bin/env swift
import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/icon_1024.png"

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}
bitmap.size = NSSize(width: size, height: size)

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create graphics context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.setAllowsAntialiasing(true)
context.cgContext.setShouldAntialias(true)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let inset: CGFloat = 84
let iconRect = canvas.insetBy(dx: inset, dy: inset)
let cornerRadius: CGFloat = 220
let backgroundPath = NSBezierPath(
    roundedRect: iconRect,
    xRadius: cornerRadius,
    yRadius: cornerRadius
)

let backgroundGradient = NSGradient(colors: [
    NSColor(srgbRed: 1.00, green: 0.53, blue: 0.32, alpha: 1),
    NSColor(srgbRed: 0.87, green: 0.25, blue: 0.12, alpha: 1)
])!
backgroundGradient.draw(in: backgroundPath, angle: -90)

NSGraphicsContext.saveGraphicsState()
backgroundPath.addClip()

let sheen = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.28),
    NSColor.white.withAlphaComponent(0.0)
])!
sheen.draw(
    in: NSRect(
        x: iconRect.minX,
        y: iconRect.midY,
        width: iconRect.width,
        height: iconRect.height / 2
    ),
    angle: 90
)
NSGraphicsContext.restoreGraphicsState()

let center = NSPoint(x: iconRect.midX, y: iconRect.midY)

func drawCard(rect: NSRect, radius: CGFloat, rotation: CGFloat, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()

    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()

    NSGraphicsContext.restoreGraphicsState()
}

let cardWidth: CGFloat = 470
let cardHeight: CGFloat = 390
let frontRect = NSRect(
    x: center.x - cardWidth / 2,
    y: center.y - cardHeight / 2 - 8,
    width: cardWidth,
    height: cardHeight
)

drawCard(
    rect: frontRect.offsetBy(dx: -16, dy: 28),
    radius: 46,
    rotation: -11,
    color: NSColor.white.withAlphaComponent(0.18)
)

drawCard(
    rect: frontRect.offsetBy(dx: 18, dy: 17),
    radius: 46,
    rotation: 8,
    color: NSColor.white.withAlphaComponent(0.30)
)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 46
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: 46, yRadius: 46)
NSColor.white.withAlphaComponent(0.97).setFill()
frontPath.fill()
NSGraphicsContext.restoreGraphicsState()

let accent = NSColor(srgbRed: 0.88, green: 0.29, blue: 0.14, alpha: 1)
let ink = NSColor(srgbRed: 0.22, green: 0.14, blue: 0.11, alpha: 0.26)

func drawPill(_ rect: NSRect, color: NSColor) {
    let path = NSBezierPath(
        roundedRect: rect,
        xRadius: rect.height / 2,
        yRadius: rect.height / 2
    )
    color.setFill()
    path.fill()
}

let lineLeft = frontRect.minX + 62
drawPill(NSRect(x: lineLeft, y: frontRect.maxY - 96, width: 92, height: 18), color: accent)
drawPill(NSRect(x: lineLeft, y: frontRect.maxY - 156, width: 342, height: 24), color: ink)
drawPill(NSRect(x: lineLeft, y: frontRect.maxY - 204, width: 292, height: 24), color: ink)
drawPill(
    NSRect(x: lineLeft, y: frontRect.maxY - 252, width: 208, height: 24),
    color: ink.withAlphaComponent(0.65)
)

NSColor.white.withAlphaComponent(0.16).setStroke()
let borderPath = NSBezierPath(
    roundedRect: iconRect.insetBy(dx: 2, dy: 2),
    xRadius: cornerRadius - 2,
    yRadius: cornerRadius - 2
)
borderPath.lineWidth = 4
borderPath.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
