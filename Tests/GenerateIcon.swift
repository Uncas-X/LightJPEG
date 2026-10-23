import AppKit

@main struct GenerateIcon {
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
        let outer = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 200, yRadius: 200)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 26
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.25, alpha: 1).setFill()
        outer.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.33, alpha: 1),
                   ending: NSColor(calibratedRed: 0.31, green: 0.66, blue: 0.48, alpha: 1))!.draw(in: outer, angle: 90)
        let card = NSBezierPath(roundedRect: NSRect(x: 230, y: 267, width: 564, height: 470), xRadius: 70, yRadius: 70)
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 0.89, alpha: 1).setFill()
        card.fill()
        NSGraphicsContext.saveGraphicsState()
        card.addClip()
        let mountain = NSBezierPath()
        mountain.move(to: NSPoint(x: 200, y: 285))
        mountain.line(to: NSPoint(x: 406, y: 562))
        mountain.curve(to: NSPoint(x: 449, y: 562), controlPoint1: NSPoint(x: 420, y: 581), controlPoint2: NSPoint(x: 436, y: 581))
        mountain.line(to: NSPoint(x: 718, y: 240))
        mountain.close()
        NSColor(calibratedRed: 0.29, green: 0.57, blue: 0.40, alpha: 1).setFill()
        mountain.fill()
        let second = NSBezierPath()
        second.move(to: NSPoint(x: 472, y: 240))
        second.line(to: NSPoint(x: 676, y: 477))
        second.curve(to: NSPoint(x: 715, y: 477), controlPoint1: NSPoint(x: 688, y: 492), controlPoint2: NSPoint(x: 703, y: 492))
        second.line(to: NSPoint(x: 845, y: 300))
        second.line(to: NSPoint(x: 845, y: 240))
        second.close()
        NSColor(calibratedRed: 0.64, green: 0.80, blue: 0.58, alpha: 1).setFill()
        second.fill()
        NSColor(calibratedRed: 0.97, green: 0.73, blue: 0.37, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 613, y: 565, width: 95, height: 95)).fill()
        NSGraphicsContext.restoreGraphicsState()
        // Opposed arrows make the compression purpose legible at small sizes.
        NSColor.white.withAlphaComponent(0.97).setStroke()
        for (x, dir) in [(CGFloat(140), CGFloat(1)), (CGFloat(884), CGFloat(-1))] {
            let arrow = NSBezierPath()
            arrow.lineWidth = 29
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.move(to: NSPoint(x: x, y: 509))
            arrow.line(to: NSPoint(x: x + dir * 82, y: 509))
            arrow.move(to: NSPoint(x: x + dir * 43, y: 552))
            arrow.line(to: NSPoint(x: x + dir * 85, y: 509))
            arrow.line(to: NSPoint(x: x + dir * 43, y: 466))
            arrow.stroke()
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let source = NSBitmapImageRep(data: tiff), let cg = source.cgImage else { return }
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = points * scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                    bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                NSGraphicsContext.current?.imageInterpolation = .high
                NSGraphicsContext.current?.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
                try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
            }
        }
    }
}
