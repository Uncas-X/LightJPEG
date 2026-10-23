import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

@main struct NativePreviewTests {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        var assertions = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            assertions += 1
            if !value() { fatalError("FAIL: " + message) }
        }
        func close(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.0001 }
        func image(_ width: Int, _ height: Int, stripes: Bool = false) -> CGImage {
            var bytes = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height { for x in 0..<width {
                let offset = (y * width + x) * 4
                if stripes {
                    bytes[offset] = x.isMultiple(of: 2) ? 255 : 0
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = x.isMultiple(of: 2) ? 0 : 255
                } else {
                    bytes[offset] = x < width / 2 ? 255 : 0
                    bytes[offset + 1] = y < height / 2 ? 255 : 0
                    bytes[offset + 2] = x < width / 2 ? 0 : 255
                }
            }}
            return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                           provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil,
                           shouldInterpolate: false, intent: .defaultIntent)!
        }
        func write(_ image: CGImage, url: URL, orientation: Int = 1) {
            let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
            check(CGImageDestinationFinalize(dest), "write fixture")
        }
        func pixels(_ image: CGImage) -> [UInt8] {
            let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                    bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
        }
        let folder = URL(fileURLWithPath: "/private/tmp/lightjpeg-preview-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let fullURL = folder.appendingPathComponent("full.tiff")
        write(image(2400, 1200), url: fullURL)
        let full = PreviewLoader.decode(fullURL, fullResolution: true)!
        let fit = PreviewLoader.decode(fullURL, fullResolution: false)!
        check(full.width == 2400 && full.height == 1200, "actual mode retains source pixel dimensions above 1600")
        check(fit.width == 1600 && fit.height == 800, "fit mode has bounded thumbnail")
        for orientation in 1...8 {
            let url = folder.appendingPathComponent("orientation-\(orientation).tiff")
            write(image(12, 8), url: url, orientation: orientation)
            let actual = PreviewLoader.decode(url, fullResolution: true)!
            let transformedFit = PreviewLoader.decode(url, fullResolution: false)!
            check(actual.width == transformedFit.width && actual.height == transformedFit.height, "orientation dimensions \(orientation)")
            let a = pixels(actual), b = pixels(transformedFit)
            check(zip(a, b).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "all orientation pixels match ImageIO reference \(orientation)")
        }
        let reference = CGSize(width: 1000, height: 500)
        let viewport = CGSize(width: 200, height: 100)
        let source = CGSize(width: 2000, height: 1000)
        check(PixelComparisonGeometry.pointSize(pixels: reference, scale: 2) == CGSize(width: 500, height: 250), "Retina physical pixel scale")
        check(PixelComparisonGeometry.pointSize(pixels: reference, scale: 1) == reference, "1x display pixel scale")
        let mapped = PixelComparisonGeometry.sourcePixel(at: CGPoint(x: 10, y: 20), sourcePixels: source,
                         referencePixels: reference, viewport: viewport, scale: 2, pan: CGPoint(x: 150, y: 75))!
        check(close(mapped.x, 640) && close(mapped.y, 380), "resized original maps to matching output region")
        let aligned = PixelComparisonGeometry.imageRect(pixels: reference, viewport: viewport, scale: 2,
                                                        pan: CGPoint(x: 1.37, y: 2.12))
        check(close(aligned.minX * 2, (aligned.minX * 2).rounded()), "horizontal pan snaps physical pixels")
        check(close(aligned.minY * 2, (aligned.minY * 2).rounded()), "vertical pan snaps physical pixels")
        let canvas = PixelComparisonCanvas(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        canvas.testBackingScale = 2
        let window = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = canvas
        canvas.configure(original: image(2048, 1024), compressed: image(1024, 512), revision: "test",
                         originalLabel: "Original", compressedLabel: "Compressed", divider: 0.5)
        check(canvas.panOffset == CGPoint(x: 106, y: 28), "initial preview centered on output grid")
        func event(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: [],
                               timestamp: 0, windowNumber: window.windowNumber, context: nil,
                               eventNumber: 1, clickCount: 1, pressure: 1)!
        }
        canvas.mouseDown(with: event(.leftMouseDown, at: CGPoint(x: 50, y: 70)))
        canvas.mouseDragged(with: event(.leftMouseDragged, at: CGPoint(x: 80, y: 90)))
        canvas.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: 80, y: 90)))
        check(canvas.panOffset == CGPoint(x: 76, y: 8), "actual mouse drag pans image without changing scale")
        let rectBeforeDivider = canvas.displayedImageRect
        var lastDivider: CGFloat = 0
        canvas.onDividerChange = { lastDivider = $0 }
        canvas.mouseDown(with: event(.leftMouseDown, at: CGPoint(x: 150, y: 100)))
        canvas.mouseDragged(with: event(.leftMouseDragged, at: CGPoint(x: 240, y: 100)))
        canvas.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: 240, y: 100)))
        check(close(canvas.divider, 0.8) && close(lastDivider, 0.8), "actual divider drag updates binding")
        check(canvas.displayedImageRect == rectBeforeDivider, "divider drag leaves pixel mapping unchanged")
        let beforeScroll = canvas.panOffset
        let cgScroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: -4, wheel2: -7, wheel3: 0)!
        let scroll = NSEvent(cgEvent: cgScroll)!
        let multiplier: CGFloat = scroll.hasPreciseScrollingDeltas ? 1 : 16
        let expectedPan = PixelComparisonGeometry.clampedPan(CGPoint(x: beforeScroll.x - scroll.scrollingDeltaX * multiplier,
                                                                     y: beforeScroll.y - scroll.scrollingDeltaY * multiplier),
                                pixels: canvas.referencePixels, viewport: canvas.bounds.size, scale: 2)
        canvas.scrollWheel(with: scroll)
        check(canvas.panOffset == expectedPan, "real scroll event pans both axes")
        canvas.pan(to: CGPoint(x: -1000, y: 1000))
        check(canvas.panOffset == CGPoint(x: 0, y: 56), "panning clamps to image edges")
        // Draw single-pixel stripes through the actual NSView draw path at 1x and 2x.
        for scale: CGFloat in [1, 2] {
            let stripeCanvas = PixelComparisonCanvas(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
            stripeCanvas.testBackingScale = scale
            stripeCanvas.configure(original: image(512, 512, stripes: true), compressed: nil, revision: "stripe",
                                   originalLabel: "Original", compressedLabel: "Compressed", divider: 0.5)
            let side = Int(128 * scale)
            let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: 0, y: 128)
            context.scaleBy(x: 1, y: -1)
            let old = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            stripeCanvas.draw(stripeCanvas.bounds)
            NSGraphicsContext.current = old
            let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
            let row = side / 2
            let a = (row * side + 10) * 4, b = (row * side + 11) * 4, c = (row * side + 12) * 4
            check(bytes[a] != bytes[b] && bytes[a] == bytes[c] && bytes[a + 2] == bytes[b], "raster preserves one-image-pixel per physical pixel at \(scale)x")
        }
        print("PASS Native preview: \(assertions) assertions; full decode, all EXIF orientations, Retina/1x raster, resize coordinates, mouse and scroll interactions.")
    }
}
