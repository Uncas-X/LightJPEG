import AppKit
import SwiftUI

/// Coordinates are expressed in the output pixel grid (the original grid before compression).
/// A reference pixel occupies exactly one physical screen pixel in actual-size mode.
struct PixelComparisonGeometry {
    static func pointSize(pixels: CGSize, scale: CGFloat) -> CGSize {
        let divisor = max(1, scale)
        return CGSize(width: pixels.width / divisor, height: pixels.height / divisor)
    }

    static func maximumPan(pixels: CGSize, viewport: CGSize, scale: CGFloat) -> CGPoint {
        let size = pointSize(pixels: pixels, scale: scale)
        return CGPoint(x: max(0, size.width - viewport.width), y: max(0, size.height - viewport.height))
    }

    static func clampedPan(_ pan: CGPoint, pixels: CGSize, viewport: CGSize, scale: CGFloat) -> CGPoint {
        let maximum = maximumPan(pixels: pixels, viewport: viewport, scale: scale)
        return CGPoint(x: min(maximum.x, max(0, pan.x)), y: min(maximum.y, max(0, pan.y)))
    }

    static func imageRect(pixels: CGSize, viewport: CGSize, scale: CGFloat, pan: CGPoint) -> CGRect {
        let size = pointSize(pixels: pixels, scale: scale)
        let limited = clampedPan(pan, pixels: pixels, viewport: viewport, scale: scale)
        let pixelScale = max(1, scale)
        // Pan positions also land on physical pixel boundaries; no half-pixel blur at 100%.
        let x = ((max(0, (viewport.width - size.width) / 2) - limited.x) * pixelScale).rounded() / pixelScale
        let y = ((max(0, (viewport.height - size.height) / 2) - limited.y) * pixelScale).rounded() / pixelScale
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    static func sourcePixel(at point: CGPoint, sourcePixels: CGSize, referencePixels: CGSize,
                            viewport: CGSize, scale: CGFloat, pan: CGPoint) -> CGPoint? {
        let rect = imageRect(pixels: referencePixels, viewport: viewport, scale: scale, pan: pan)
        guard rect.width > 0, rect.height > 0, rect.contains(point) else { return nil }
        return CGPoint(x: (point.x - rect.minX) / rect.width * sourcePixels.width,
                       y: (point.y - rect.minY) / rect.height * sourcePixels.height)
    }
}

struct NativePixelComparison: NSViewRepresentable {
    let original: CGImage
    let compressed: CGImage?
    let revision: String
    let originalLabel: String
    let compressedLabel: String
    let help: String
    @Binding var divider: CGFloat

    func makeNSView(context: Context) -> PixelComparisonCanvas {
        let view = PixelComparisonCanvas(frame: .zero)
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        update(view)
        return view
    }

    func updateNSView(_ view: PixelComparisonCanvas, context: Context) { update(view) }

    static func dismantleNSView(_ view: PixelComparisonCanvas, coordinator: ()) {
        view.releaseImages()
    }

    private func update(_ view: PixelComparisonCanvas) {
        view.configure(original: original, compressed: compressed, revision: revision,
                       originalLabel: originalLabel, compressedLabel: compressedLabel,
                       divider: divider)
        view.toolTip = help
        view.setAccessibilityLabel(help)
        view.onDividerChange = { value in divider = value }
    }
}

/// A fixed-size viewport avoids allocating an enormous layer for a full-resolution image.
/// Core Graphics clips drawing to the visible viewport; panning never rescales either image.
final class PixelComparisonCanvas: NSView {
    private(set) var original: CGImage?
    private(set) var compressed: CGImage?
    private(set) var panOffset = CGPoint.zero
    private(set) var divider: CGFloat = 0.5
    var onDividerChange: ((CGFloat) -> Void)?
    // Kept internal so coordinate and raster tests can emulate Retina and 1x displays.
    var testBackingScale: CGFloat?
    private var revision = ""
    private var originalLabel = ""
    private var compressedLabel = ""
    private var centerOnNextLayout = true
    private var tracking: NSTrackingArea?
    private var dragStart = CGPoint.zero
    private var dragPan = CGPoint.zero
    private var draggingDivider = false
    private var lastScale: CGFloat = 1

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    var displayScale: CGFloat { testBackingScale ?? window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1 }
    var referencePixels: CGSize {
        guard let image = compressed ?? original else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }
    var displayedImageRect: CGRect {
        PixelComparisonGeometry.imageRect(pixels: referencePixels, viewport: bounds.size,
                                          scale: displayScale, pan: panOffset)
    }

    func configure(original: CGImage, compressed: CGImage?, revision: String,
                   originalLabel: String, compressedLabel: String, divider: CGFloat) {
        let oldPixels = referencePixels
        self.original = original
        self.compressed = compressed
        self.originalLabel = originalLabel
        self.compressedLabel = compressedLabel
        self.divider = min(0.98, max(0.02, divider))
        if self.revision != revision || oldPixels != referencePixels {
            self.revision = revision
            centerOnNextLayout = true
        }
        updateGeometry()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        lastScale = displayScale
        updateGeometry()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateGeometry()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let oldRect = PixelComparisonGeometry.imageRect(pixels: referencePixels, viewport: bounds.size,
                                                        scale: lastScale, pan: panOffset)
        let centerPixel = CGPoint(x: (center.x - oldRect.minX) * lastScale,
                                  y: (center.y - oldRect.minY) * lastScale)
        panOffset = CGPoint(x: centerPixel.x / displayScale - center.x,
                            y: centerPixel.y / displayScale - center.y)
        lastScale = displayScale
        updateGeometry()
    }

    private func updateGeometry() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if centerOnNextLayout && referencePixels.width > 0 {
            let maximum = PixelComparisonGeometry.maximumPan(pixels: referencePixels, viewport: bounds.size, scale: displayScale)
            panOffset = CGPoint(x: maximum.x / 2, y: maximum.y / 2)
            centerOnNextLayout = false
        }
        panOffset = PixelComparisonGeometry.clampedPan(panOffset, pixels: referencePixels,
                                                       viewport: bounds.size, scale: displayScale)
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        guard let original, let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = displayedImageRect
        context.saveGState()
        context.clip(to: bounds)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        drawImage(original, in: rect, context: context, interpolate: compressed != nil &&
                  (original.width != compressed!.width || original.height != compressed!.height))
        if let compressed {
            context.saveGState()
            context.clip(to: CGRect(x: divider * bounds.width, y: 0,
                                    width: (1 - divider) * bounds.width, height: bounds.height))
            drawImage(compressed, in: rect, context: context, interpolate: false)
            context.restoreGState()
        }
        context.restoreGState()
        drawOverlay()
    }

    private func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext, interpolate: Bool) {
        context.saveGState()
        context.interpolationQuality = interpolate ? .high : .none
        // NSView uses top-left coordinates; CGImage drawing uses bottom-left coordinates.
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private func drawOverlay() {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        func badge(_ text: String, right: Bool) {
            let string = text as NSString
            let size = string.size(withAttributes: textAttributes)
            let width = min(size.width + 20, max(20, bounds.width / 2 - 16))
            let rect = CGRect(x: right ? bounds.width - width - 10 : 10, y: 10, width: width, height: 24)
            NSColor.black.withAlphaComponent(0.56).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            string.draw(in: rect.insetBy(dx: 10, dy: 5), withAttributes: textAttributes)
        }
        badge(originalLabel, right: false)
        guard compressed != nil else { return }
        badge(compressedLabel, right: true)
        let x = divider * bounds.width
        NSColor.white.setFill()
        CGRect(x: x - 0.75, y: 0, width: 1.5, height: bounds.height).fill()
        let handle = CGRect(x: x - 15, y: bounds.midY - 18, width: 30, height: 36)
        NSBezierPath(roundedRect: handle, xRadius: 15, yRadius: 15).fill()
        NSColor(calibratedRed: 0.18, green: 0.53, blue: 0.38, alpha: 1).setStroke()
        for direction: CGFloat in [-1, 1] {
            let chevron = NSBezierPath()
            chevron.move(to: CGPoint(x: x + direction * 3, y: bounds.midY - 4))
            chevron.line(to: CGPoint(x: x + direction * 7, y: bounds.midY))
            chevron.line(to: CGPoint(x: x + direction * 3, y: bounds.midY + 4))
            chevron.lineWidth = 1.5
            chevron.stroke()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let newTracking = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect], owner: self)
        addTrackingArea(newTracking)
        tracking = newTracking
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
        if compressed != nil {
            addCursorRect(CGRect(x: divider * bounds.width - 14, y: 0, width: 28, height: bounds.height), cursor: .resizeLeftRight)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragStart = convert(event.locationInWindow, from: nil)
        dragPan = panOffset
        draggingDivider = compressed != nil && abs(dragStart.x - divider * bounds.width) <= 14
        (draggingDivider ? NSCursor.resizeLeftRight : .closedHand).set()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if draggingDivider {
            moveDivider(to: point.x / max(1, bounds.width))
        } else {
            pan(to: CGPoint(x: dragPan.x - (point.x - dragStart.x), y: dragPan.y - (point.y - dragStart.y)))
        }
    }

    override func mouseUp(with event: NSEvent) {
        draggingDivider = false
        window?.invalidateCursorRects(for: self)
        NSCursor.openHand.set()
    }

    override func scrollWheel(with event: NSEvent) {
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
        var dx = event.scrollingDeltaX * multiplier
        var dy = event.scrollingDeltaY * multiplier
        if event.modifierFlags.contains(.shift) && dx == 0 { dx = dy; dy = 0 }
        pan(to: CGPoint(x: panOffset.x - dx, y: panOffset.y - dy))
    }

    override func keyDown(with event: NSEvent) {
        let distance: CGFloat = event.modifierFlags.contains(.shift) ? 100 : 24
        switch event.keyCode {
        case 123: pan(to: CGPoint(x: panOffset.x - distance, y: panOffset.y))
        case 124: pan(to: CGPoint(x: panOffset.x + distance, y: panOffset.y))
        case 125: pan(to: CGPoint(x: panOffset.x, y: panOffset.y + distance))
        case 126: pan(to: CGPoint(x: panOffset.x, y: panOffset.y - distance))
        default: super.keyDown(with: event)
        }
    }

    func releaseImages() {
        original = nil
        compressed = nil
        onDividerChange = nil
    }

    // These same operations serve mouse/scroll input and deterministic interaction tests.
    func moveDivider(to fraction: CGFloat) {
        divider = min(0.98, max(0.02, fraction))
        onDividerChange?(divider)
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    func pan(to proposed: CGPoint) {
        panOffset = PixelComparisonGeometry.clampedPan(proposed, pixels: referencePixels,
                                                       viewport: bounds.size, scale: displayScale)
        needsDisplay = true
    }
}
