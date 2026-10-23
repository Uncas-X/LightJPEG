import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private struct ModelTestError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

@main
struct ModelTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ModelTestError(message) }
    }

    @MainActor
    static func until(_ label: String, timeout: TimeInterval = 25,
                      _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw ModelTestError("Timed out: \(label)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    static func main() async throws {
        let fm = FileManager.default
        let identifier = UUID().uuidString
        let root = fm.temporaryDirectory.appendingPathComponent("LightJPEG-model-tests-\(identifier)")
        let inputs = root.appendingPathComponent("Inputs")
        let nested = inputs.appendingPathComponent("Nested")
        let exports = root.appendingPathComponent("Exports")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        let suite = "LightJPEG.ModelTests.\(identifier)"
        let defaults = UserDefaults(suiteName: suite)!
        let localizer = Localizer(defaults: defaults, preferredLanguages: ["en"])
        var chooserResult: URL? = exports
        var chooserCalls = 0
        let model = AppModel(localizer: localizer, directoryChooser: {
            chooserCalls += 1
            return chooserResult
        })
        defer {
            model.cleanUp()
            defaults.removePersistentDomain(forName: suite)
            try? fm.removeItem(at: root)
        }

        let jpeg = inputs.appendingPathComponent("照片.jpg")
        let png = nested.appendingPathComponent("透明🙂.png")
        let broken = inputs.appendingPathComponent("00-broken.jpg")
        try fixture(jpeg, type: .jpeg, width: 640, height: 480) { x, y in
            [UInt8(x % 256), UInt8(y % 256), UInt8((x + y) % 256), 255]
        }
        try fixture(png, type: .png, width: 320, height: 240) { x, y in
            x < 160 ? [0, 0, 0, 0] : [UInt8(y % 256), 90, 200, 255]
        }
        try Data([0xff, 0xd8, 0xff, 0x00, 0x01]).write(to: broken)
        var originals: [URL: Data] = [:]
        for url in [jpeg, png, broken] { originals[url] = try Data(contentsOf: url) }

        model.addFiles([inputs, jpeg, nested, png])
        try await until("directory import") { !model.importing }
        try require(model.items.count == 3, "Duplicate directory/file paths were not deduplicated")
        try require(Set(model.items.map(\.url)).count == 3, "Duplicate items in queue")
        try require(model.items.filter { $0.url != broken }.allSatisfy { $0.thumbnail != nil },
                    "Expected native thumbnails without NSApplication")
        model.addFiles([jpeg, png])
        try await until("duplicate import") { !model.importing }
        try require(model.items.count == 3, "Repeat import created duplicates")
        print("PASS recursive directory import, repeat/path deduplication, headless NSImage thumbnails")

        chooserResult = nil
        model.startCompression()
        try require(chooserCalls == 1 && !model.running && model.outputDirectory == nil,
                    "Cancelling destination selection unexpectedly started compression")
        try require(model.items.allSatisfy { $0.state == .queued && $0.result == nil },
                    "Cancelling destination selection modified queue")
        chooserResult = exports
        print("PASS destination selection is first and cancelling leaves queue unchanged")

        // Put the corrupt file first, so successful later results prove that a
        // decoding error does not abort the batch.
        model.items.sort { $0.url == broken && $1.url != broken }
        model.startCompression()
        try await until("first batch") { !model.running }
        try require(model.finishedItems.count == 2, "Corrupt first image blocked later images")
        try require(model.items.first(where: { $0.url == broken })?.state == .failed,
                    "Corrupt image was not marked failed")
        try require(model.items.first(where: { $0.url == broken })?.errorKey == "error.decode",
                    "Corrupt image did not expose decode error key")
        try require(model.completed == 3 && model.progress == 1, "Completion count did not include failures")
        try require(model.finishedItems.allSatisfy { $0.result?.quality == 75 }, "Unexpected initial quality")
        try require(!model.settingsChanged, "Fresh results were marked stale")
        let firstSaved = model.finishedItems.compactMap(\.savedURL)
        try require(firstSaved.count == 2 && firstSaved.allSatisfy { fm.fileExists(atPath: $0.path) },
                    "Finished images were not automatically saved to the selected folder")
        try require(model.outputDirectory == exports && model.noticeKey == "status.saved", "Saved destination/status missing")
        var savedSnapshots: [URL: Data] = [:]
        for url in firstSaved { savedSnapshots[url] = try Data(contentsOf: url) }
        print("PASS batch continues after corrupt input, automatically saves each completed file")

        let previousOutputs = model.finishedItems.compactMap { $0.result?.outputURL }
        chooserResult = nil
        model.startCompression()
        try require(model.finishedItems.count == 2 && !model.running,
                    "Cancelling recompression folder selection discarded existing results")
        chooserResult = exports
        model.preserveEXIF = true
        try require(model.settingsChanged, "EXIF change was not detected")
        model.preserveEXIF = false
        try require(!model.settingsChanged, "Restoring EXIF choice should restore original settings")
        model.quality = 43
        try require(model.settingsChanged, "Quality change was not detected")
        model.startCompression()
        try await until("quality recompression") { !model.running }
        try require(model.finishedItems.count == 2, "Recompression dropped valid files")
        try require(model.finishedItems.allSatisfy { $0.result?.quality == 43 }, "New quality not used")
        try require(!model.settingsChanged, "Recompressed results remain marked stale")
        try require(previousOutputs.allSatisfy { !fm.fileExists(atPath: $0.path) }, "Old temporary results retained")
        try require(Set(model.finishedItems.compactMap(\.savedURL)).isDisjoint(with: Set(firstSaved)),
                    "Recompression reused an existing saved filename")
        for (url, data) in savedSnapshots { try require((try? Data(contentsOf: url)) == data, "Recompression overwrote a saved file") }
        print("PASS settingsChanged, EXIF setting, recompression saves new files without changing prior exports")

        model.selectionID = model.items.first(where: { $0.url == broken })!.id
        model.removeSelected()
        try require(model.items.count == 2, "Selected item was not removed")
        try require(model.completed == 2 && model.progress <= 1, "Removal left progress above one")
        print("PASS removal recomputes completion/progress")

        let noise = inputs.appendingPathComponent("noise.png")
        var random: UInt32 = 54_321
        try fixture(noise, type: .png, width: 3500, height: 2500) { _, _ in
            random = random &* 1_664_525 &+ 1_013_904_223
            return [UInt8(truncatingIfNeeded: random >> 24), UInt8(truncatingIfNeeded: random >> 16),
                    UInt8(truncatingIfNeeded: random >> 8), 255]
        }
        originals[noise] = try Data(contentsOf: noise)
        model.addFiles([noise])
        try await until("noise import") { !model.importing }
        try require(model.items.count == 3, "Large valid sample was not imported")
        let order = [jpeg: 0, noise: 1, png: 2]
        model.items.sort { (order[$0.url] ?? 9) < (order[$1.url] ?? 9) }
        model.startCompression()
        try await until("first result before cancellation") { !model.finishedItems.isEmpty || !model.running }
        try require(model.running, "Cancellation fixture finished before the cancellation checkpoint")
        model.cancel()
        try await until("cancelled batch", timeout: 5) { !model.running }
        try require(model.noticeKey == "status.cancelled", "Cancellation status was not reported")
        try require(!model.finishedItems.isEmpty && model.finishedItems.count < 3,
                    "Cancellation did not preserve partial completed results")
        try require(model.items.allSatisfy { $0.state != .processing }, "Processing state remained after cancellation")
        try require(model.finishedItems.allSatisfy { $0.savedURL != nil && fm.fileExists(atPath: $0.savedURL!.path) },
                    "Completed images were not saved before cancellation")
        let completedEntries: [(source: URL, name: String)] = model.finishedItems.compactMap { item in
            guard let result = item.result else { return nil }
            return (result.outputURL, item.url.deletingPathExtension().lastPathComponent + "_compressed")
        }
        let export = Exporter.copy(completedEntries, to: exports)
        try require(export.failures == 0 && export.urls.count == completedEntries.count,
                    "Completed results could not be exported after cancellation")
        for (index, target) in export.urls.enumerated() {
            try require((try? Data(contentsOf: target)) == (try? Data(contentsOf: completedEntries[index].source)),
                        "Exported result differs from completed result")
        }
        print("PASS active cancellation retains already saved images, with no processing state left")

        // Simulate a destination disappearing after selection but before the first save.
        let vanished = root.appendingPathComponent("Vanishing")
        try fm.createDirectory(at: vanished, withIntermediateDirectories: true)
        let saveFailureModel = AppModel(localizer: localizer)
        saveFailureModel.addFiles([png])
        try await until("save failure import") { !saveFailureModel.importing }
        saveFailureModel.startCompression(to: vanished)
        try fm.removeItem(at: vanished)
        try await until("save failure batch") { !saveFailureModel.running }
        try require(saveFailureModel.items.first?.state == .failed && saveFailureModel.items.first?.errorKey == "error.save",
                    "A failed automatic save was incorrectly reported as completed")
        try require(saveFailureModel.items.first?.savedURL == nil && saveFailureModel.items.first?.result != nil,
                    "Save failure should retain the compressed preview without claiming a saved path")
        saveFailureModel.cleanUp()
        print("PASS destination failure is reported accurately and keeps the recoverable preview")

        let persisted = model.finishedItems.compactMap(\.savedURL)
        model.clear()
        model.cleanUp()
        try require(persisted.allSatisfy { fm.fileExists(atPath: $0.path) }, "Clear/quit deleted saved outputs")
        for (url, data) in savedSnapshots { try require((try? Data(contentsOf: url)) == data, "Clear/quit changed earlier saved results") }
        let directoryEntries = try fm.contentsOfDirectory(atPath: exports.path)
        try require(!directoryEntries.contains { $0.hasPrefix(".lightjpeg-") }, "Staging file leaked")
        print("PASS clear/quit preserves saved files and automatic saves leave no staging files")

        for (url, data) in originals {
            try require((try? Data(contentsOf: url)) == data, "Source file changed: \(url.lastPathComponent)")
        }
        print("PASS all original files remain byte-for-byte unchanged")
        print("All AppModel integration tests passed.")
    }

    static func fixture(_ url: URL, type: UTType, width: Int, height: Int,
                        pixel: (Int, Int) -> [UInt8]) throws {
        var bytes = Data(count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let value = pixel(x, y)
                    let offset = (y * width + x) * 4
                    for channel in 0..<4 { buffer[offset + channel] = value[channel] }
                }
            }
        }
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: CGDataProvider(data: bytes as CFData)!, decode: nil,
                            shouldInterpolate: false, intent: .defaultIntent)!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ModelTestError("Cannot create fixture")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        try require(CGImageDestinationFinalize(destination), "Cannot write fixture")
    }
}
