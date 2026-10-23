import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private struct TestError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestError(message) }
}

@main
struct EngineTests {
    static let fm = FileManager.default

    static func main() throws {
        let root = fm.temporaryDirectory.appendingPathComponent("LightJPEG-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let outputs = root.appendingPathComponent("out")
        let settings = CompressionSettings(quality: 92, maxDimension: 0, chroma444: true)
        let expected = [
            [0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
            [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]
        ]
        let palette: [[UInt8]] = [[240, 10, 10], [10, 220, 10], [10, 10, 240], [235, 220, 10]]
        for orientation in 1...8 {
            let input = root.appendingPathComponent("orientation-\(orientation).tiff")
            try fixture(url: input, type: .tiff, width: 120, height: 80,
                        properties: [kCGImagePropertyOrientation: orientation]) { x, y in
                let color = palette[(y >= 40 ? 2 : 0) + (x >= 60 ? 1 : 0)]
                return color + [255]
            }
            let original = try Data(contentsOf: input)
            let result = try CompressionEngine.compress(input: input, outputDirectory: outputs,
                                                       settings: settings, cancellation: CancellationToken())
            try require(result.width == (orientation >= 5 ? 80 : 120), "Orientation \(orientation): width")
            try require(result.height == (orientation >= 5 ? 120 : 80), "Orientation \(orientation): height")
            let samples = try corners(result.outputURL)
            for index in 0..<4 {
                try require(close(samples[index], palette[expected[orientation - 1][index]]),
                            "Orientation \(orientation): corner \(index) is \(samples[index])")
            }
            try require(tryData(input) == original, "Source was modified")
        }
        print("PASS all eight EXIF orientations, oriented dimensions, source immutability")

        let source = root.appendingPathComponent("orientation-6.tiff")
        let resized = try CompressionEngine.compress(input: source, outputDirectory: outputs,
                                                    settings: .init(quality: 75, maxDimension: 60, chroma444: false),
                                                    cancellation: CancellationToken())
        try require(resized.width == 40 && resized.height == 60, "Aspect ratio / resize")
        let noUpscale = try CompressionEngine.compress(input: source, outputDirectory: outputs,
                                                      settings: .init(quality: 75, maxDimension: 300, chroma444: false),
                                                      cancellation: CancellationToken())
        try require(noUpscale.width == 80 && noUpscale.height == 120, "Unexpected upscale")
        print("PASS resizing and no upscaling")

        let transparent = root.appendingPathComponent("alpha.png")
        try fixture(url: transparent, type: .png, width: 120, height: 80) { x, _ in
            x < 60 ? [0, 0, 0, 0] : [240, 0, 0, 255]
        }
        let alphaResult = try CompressionEngine.compress(input: transparent, outputDirectory: outputs,
                                                        settings: settings, cancellation: CancellationToken())
        let alphaCorners = try corners(alphaResult.outputURL)
        try require(close(alphaCorners[0], [255, 255, 255]), "Transparent pixels were not flattened white")
        try require(close(alphaCorners[1], [240, 0, 0]), "Opaque pixels changed unexpectedly")
        let profileData = try Data(contentsOf: alphaResult.outputURL)
        try require(profileData.range(of: Data("ICC_PROFILE".utf8)) != nil, "Missing ICC profile")
        print("PASS white alpha flattening and embedded sRGB ICC")

        let withMetadata = root.appendingPathComponent("metadata.jpg")
        try fixture(url: withMetadata, type: .jpeg, width: 80, height: 60, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 31.2,
                                          kCGImagePropertyGPSLatitudeRef: "N",
                                          kCGImagePropertyGPSLongitude: 121.5,
                                          kCGImagePropertyGPSLongitudeRef: "E"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private-test"]
        ]) { _, _ in [120, 80, 200, 255] }
        let metadataResult = try CompressionEngine.compress(input: withMetadata, outputDirectory: outputs,
                                                           settings: settings, cancellation: CancellationToken())
        let metadataSource = CGImageSourceCreateWithURL(metadataResult.outputURL as CFURL, nil)!
        let metadata = CGImageSourceCopyPropertiesAtIndex(metadataSource, 0, nil)! as NSDictionary
        try require(metadata[kCGImagePropertyGPSDictionary] == nil, "GPS metadata was retained")
        try require(metadata[kCGImagePropertyExifDictionary] == nil, "EXIF metadata was retained")
        print("PASS GPS and EXIF removal")

        try metadataRetentionTests(root: root, outputs: outputs)

        let tiny = root.appendingPathComponent("tiny.jpg")
        try fixture(url: tiny, type: .jpeg, width: 8, height: 8,
                    properties: [kCGImageDestinationLossyCompressionQuality: 0.01]) { _, _ in [100, 100, 100, 255] }
        let tinyOriginal = try Data(contentsOf: tiny)
        let tinyResult = try CompressionEngine.compress(input: tiny, outputDirectory: outputs,
                                                       settings: settings, cancellation: CancellationToken())
        try require(tinyResult.outputBytes > tinyResult.originalBytes, "Expected ICC-tagged tiny JPEG to grow")
        try require(tryData(tinyResult.outputURL) != tinyOriginal, "Engine silently copied original")
        try require(tryData(tiny) == tinyOriginal, "Tiny source changed")
        print("PASS larger encoded output is returned, without copying or modifying original")

        let emojiInput = root.appendingPathComponent(String(repeating: "🙂", count: 61) + ".png")
        try fixture(url: emojiInput, type: .png, width: 16, height: 12) { _, _ in [60, 120, 180, 255] }
        let emojiOriginal = try Data(contentsOf: emojiInput)
        let emojiResult = try CompressionEngine.compress(input: emojiInput, outputDirectory: outputs,
                                                        settings: settings, cancellation: CancellationToken())
        try require(emojiResult.outputURL.lastPathComponent.utf8.count <= 255, "Output exceeds NAME_MAX")
        try require(tryData(emojiInput) == emojiOriginal, "Long-name source changed")
        print("PASS long emoji basename without NAME_MAX overflow")

        // A valid uncompressed grayscale TIFF uses a sparse zero-filled pixel
        // strip. It tests the source budget without allocating a giant fixture.
        let oversized = root.appendingPathComponent("oversized.tiff")
        var tiff = Data([0x49, 0x49, 42, 0, 8, 0, 0, 0])
        func little16(_ value: UInt16) {
            tiff.append(UInt8(truncatingIfNeeded: value))
            tiff.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func little32(_ value: UInt32) {
            for shift in stride(from: 0, through: 24, by: 8) {
                tiff.append(UInt8(truncatingIfNeeded: value >> shift))
            }
        }
        let tags: [(UInt16, UInt16, UInt32)] = [
            (256, 4, 20_000), (257, 4, 10_000), (258, 3, 8),
            (259, 3, 1), (262, 3, 1), (273, 4, 122),
            (277, 3, 1), (278, 4, 10_000), (279, 4, 200_000_000)
        ]
        little16(UInt16(tags.count))
        for (tag, type, value) in tags {
            little16(tag); little16(type); little32(1); little32(value)
        }
        little32(0)
        try tiff.write(to: oversized)
        let sparse = try FileHandle(forWritingTo: oversized)
        try sparse.truncate(atOffset: 200_000_122)
        try sparse.close()
        try failure("error.large") {
            _ = try CompressionEngine.compress(input: oversized, outputDirectory: outputs,
                                               settings: .init(quality: 75, maxDimension: 1280, chroma444: false),
                                               cancellation: CancellationToken())
        }
        print("PASS source-pixel memory budget cannot be bypassed by downsizing")

        let corrupt = root.appendingPathComponent("broken.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0x00, 0x01]).write(to: corrupt)
        try failure("error.decode") {
            _ = try CompressionEngine.compress(input: corrupt, outputDirectory: outputs,
                                               settings: settings, cancellation: CancellationToken())
        }
        try failure("error.read") {
            _ = try CompressionEngine.compress(input: root.appendingPathComponent("missing.jpg"),
                                               outputDirectory: outputs, settings: settings,
                                               cancellation: CancellationToken())
        }
        let cancelled = CancellationToken()
        cancelled.cancel()
        try failure("error.cancelled") {
            _ = try CompressionEngine.compress(input: source, outputDirectory: outputs,
                                               settings: settings, cancellation: cancelled)
        }
        print("PASS corrupt/missing inputs and pre-cancellation")

        // A large noise image gives the real encoder enough work to test
        // cancellation while compression runs, without a fake implementation.
        let noisy = root.appendingPathComponent("noise.png")
        var state: UInt32 = 12_345
        try fixture(url: noisy, type: .png, width: 3500, height: 2500) { _, _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            return [UInt8(truncatingIfNeeded: state >> 24), UInt8(truncatingIfNeeded: state >> 16),
                    UInt8(truncatingIfNeeded: state >> 8), 255]
        }
        let activeToken = CancellationToken()
        let cancelOutputs = root.appendingPathComponent("cancelled-output")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { activeToken.cancel() }
        let started = Date()
        try failure("error.cancelled") {
            _ = try CompressionEngine.compress(input: noisy, outputDirectory: cancelOutputs,
                                               settings: settings, cancellation: activeToken)
        }
        let elapsed = Date().timeIntervalSince(started)
        try require(elapsed < 5.0, "Cancellation was not prompt: \(elapsed) seconds")
        let cancelledFiles = (try? fm.contentsOfDirectory(atPath: cancelOutputs.path)) ?? []
        try require(cancelledFiles.isEmpty, "Cancelled job left final output")
        print("PASS active cancellation (\(String(format: "%.2f", elapsed))s), no final output")
        print("All engine integration tests passed.")
    }

    static func fixture(url: URL, type: UTType, width: Int, height: Int,
                        properties: [CFString: Any] = [:],
                        pixel: (Int, Int) -> [UInt8]) throws {
        var bytes = Data(count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let color = pixel(x, y)
                    let offset = (y * width + x) * 4
                    for c in 0..<4 { buffer[offset + c] = color[c] }
                }
            }
        }
        let provider = CGDataProvider(data: bytes as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                            bitsPerPixel: 32, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw TestError("Could not create fixture")
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        try require(CGImageDestinationFinalize(destination), "Could not write fixture")
    }

    static func corners(_ url: URL) throws -> [[UInt8]] {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let context = CGContext(data: nil, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                            CGBitmapInfo.byteOrder32Big.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        let points = [(image.width / 4, image.height / 4), (image.width * 3 / 4, image.height / 4),
                      (image.width / 4, image.height * 3 / 4), (image.width * 3 / 4, image.height * 3 / 4)]
        return points.map { x, y in
            let offset = y * context.bytesPerRow + x * 4
            return [data[offset], data[offset + 1], data[offset + 2]]
        }
    }

    static func close(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        zip(lhs, rhs).allSatisfy { abs(Int($0.0) - Int($0.1)) < 25 }
    }

    static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }

    static func failure(_ key: String, action: () throws -> Void) throws {
        do { try action(); throw TestError("Expected \(key)") }
        catch let error as CompressionFailure { try require(error.key == key, "Expected \(key), got \(error.key)") }
    }

    static func metadataRetentionTests(root: URL, outputs: URL) throws {
        let types: [(UTType, String)] = [(.jpeg, "jpg"), (.png, "png"), (.tiff, "tiff"), (.heic, "heic")]
        for (type, ext) in types {
            let input = root.appendingPathComponent("metadata-source.\(ext)")
            let properties: [CFString: Any] = [
                kCGImagePropertyOrientation: 6,
                kCGImageDestinationEmbedThumbnail: true,
                kCGImagePropertyTIFFDictionary: [
                    kCGImagePropertyTIFFMake: "Example Camera",
                    kCGImagePropertyTIFFModel: "Test Model",
                    kCGImagePropertyTIFFOrientation: 6
                ],
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifDateTimeOriginal: "2024:03:05 14:25:36",
                    kCGImagePropertyExifExposureTime: 0.01,
                    kCGImagePropertyExifFNumber: 2.8,
                    kCGImagePropertyExifISOSpeedRatings: [200],
                    kCGImagePropertyExifPixelXDimension: 120,
                    kCGImagePropertyExifPixelYDimension: 80,
                    kCGImagePropertyExifUserComment: "kept-standard-comment"
                ],
                kCGImagePropertyGPSDictionary: [
                    kCGImagePropertyGPSLatitude: 31.2,
                    kCGImagePropertyGPSLatitudeRef: "N",
                    kCGImagePropertyGPSLongitude: 121.5,
                    kCGImagePropertyGPSLongitudeRef: "E",
                    kCGImagePropertyGPSAltitude: 12.5,
                    kCGImagePropertyGPSAltitudeRef: 0,
                    kCGImagePropertyGPSDateStamp: "2024:03:05",
                    kCGImagePropertyGPSTimeStamp: "06:25:36"
                ]
            ]
            do {
                try fixture(url: input, type: type, width: 120, height: 80, properties: properties) { x, y in
                    [UInt8((x * 3) % 255), UInt8((y * 4) % 255), 160, 255]
                }
            } catch {
                guard type == .heic else { throw error }
                guard let fixturePath = ProcessInfo.processInfo.environment["LIGHTJPEG_HEIC_FIXTURE"] else {
                    print("SKIP HEIC fixture creation: system HEIC encoder unavailable in this headless environment")
                    continue
                }
                // Optional existing HEIC sample avoids requiring a hardware
                // encoder on headless CI. Metadata is attached losslessly.
                let sampleURL = URL(fileURLWithPath: fixturePath)
                guard let sample = CGImageSourceCreateWithURL(sampleURL as CFURL, nil),
                      let sampleType = CGImageSourceGetType(sample),
                      let template = CGImageSourceCreateWithURL(root.appendingPathComponent("metadata-source.jpg") as CFURL, nil),
                      let tags = CGImageSourceCopyMetadataAtIndex(template, 0, nil),
                      let destination = CGImageDestinationCreateWithURL(input as CFURL, sampleType, 1, nil) else {
                    throw TestError("Cannot read optional HEIC fixture")
                }
                var metadataError: Unmanaged<CFError>?
                guard CGImageDestinationCopyImageSource(destination, sample, [
                    kCGImageDestinationMetadata: tags,
                    kCGImageDestinationMergeMetadata: false
                ] as CFDictionary, &metadataError) else {
                    throw TestError("Cannot attach HEIC fixture metadata: \(String(describing: metadataError?.takeRetainedValue()))")
                }
            }
            let original = try Data(contentsOf: input)
            let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
            let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
            let rawWidth = (sourceProperties[kCGImagePropertyPixelWidth] as! NSNumber).intValue
            let rawHeight = (sourceProperties[kCGImagePropertyPixelHeight] as! NSNumber).intValue
            let sourceOrientation = (sourceProperties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            let swaps = (5...8).contains(sourceOrientation)
            let orientedWidth = swaps ? rawHeight : rawWidth
            let orientedHeight = swaps ? rawWidth : rawHeight
            let scale = min(1, 60.0 / Double(max(orientedWidth, orientedHeight)))
            let expectedWidth = max(1, Int((Double(orientedWidth) * scale).rounded()))
            let expectedHeight = max(1, Int((Double(orientedHeight) * scale).rounded()))
            try require(sourceProperties[kCGImagePropertyGPSDictionary] != nil, "\(ext): fixture did not store GPS")
            let stripped = try CompressionEngine.compress(input: input, outputDirectory: outputs,
                settings: .init(quality: 82, maxDimension: 60, chroma444: true), cancellation: CancellationToken())
            let retained = try CompressionEngine.compress(input: input, outputDirectory: outputs,
                settings: .init(quality: 82, maxDimension: 60, chroma444: true, preserveEXIF: true),
                cancellation: CancellationToken())
            let retainedData = try Data(contentsOf: retained.outputURL)
            let strippedData = try Data(contentsOf: stripped.outputURL)
            let retainedSource = CGImageSourceCreateWithURL(retained.outputURL as CFURL, nil)!
            let retainedProperties = CGImageSourceCopyPropertiesAtIndex(retainedSource, 0, nil)! as NSDictionary
            let exif = retainedProperties[kCGImagePropertyExifDictionary] as? NSDictionary
            let gps = retainedProperties[kCGImagePropertyGPSDictionary] as? NSDictionary
            let tiff = retainedProperties[kCGImagePropertyTIFFDictionary] as? NSDictionary
            let strippedSource = CGImageSourceCreateWithURL(stripped.outputURL as CFURL, nil)!
            let strippedProperties = CGImageSourceCopyPropertiesAtIndex(strippedSource, 0, nil)! as NSDictionary
            try require(strippedProperties[kCGImagePropertyGPSDictionary] == nil, "\(ext): default retained GPS")
            try require(strippedProperties[kCGImagePropertyExifDictionary] == nil, "\(ext): default retained EXIF")
            try require(retained.width == expectedWidth && retained.height == expectedHeight, "\(ext): oriented dimensions not preserved")
            try require((retainedProperties[kCGImagePropertyOrientation] as? NSNumber)?.intValue == 1,
                        "\(ext): retained orientation not normalized")
            try require((exif?[kCGImagePropertyExifPixelXDimension] as? NSNumber)?.intValue == expectedWidth &&
                        (exif?[kCGImagePropertyExifPixelYDimension] as? NSNumber)?.intValue == expectedHeight,
                        "\(ext): stale EXIF dimensions")
            try require(exif?[kCGImagePropertyExifDateTimeOriginal] as? String == "2024:03:05 14:25:36",
                        "\(ext): capture date was not retained: \(String(describing: exif))")
            try require(abs(((exif?[kCGImagePropertyExifExposureTime] as? NSNumber)?.doubleValue ?? -1) - 0.01) < 0.0001,
                        "\(ext): exposure missing")
            try require(exif?[kCGImagePropertyExifUserComment] as? String == "kept-standard-comment",
                        "\(ext): standard user comment missing")
            try require(tiff?[kCGImagePropertyTIFFMake] as? String == "Example Camera", "\(ext): camera make missing")
            try require(abs(((gps?[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue ?? 0) - 31.2) < 0.00001 &&
                        abs(((gps?[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue ?? 0) - 121.5) < 0.00001,
                        "\(ext): GPS coordinates not retained: \(String(describing: gps))")
            try require(gps?[kCGImagePropertyGPSLatitudeRef] as? String == "N" &&
                        gps?[kCGImagePropertyGPSLongitudeRef] as? String == "E", "\(ext): GPS hemispheres changed")
            try require(retainedData.range(of: Data("ICC_PROFILE".utf8)) != nil, "\(ext): sRGB ICC lost")
            let retainedPayload = try jpegImagePayload(retainedData)
            let strippedPayload = try jpegImagePayload(strippedData)
            try require(retainedPayload == strippedPayload,
                        "\(ext): JPEG scan/image payload changed during metadata copy")
            try require(!hasExifThumbnail(retainedData), "\(ext): stale thumbnail retained")
            try require(tryData(input) == original, "\(ext): source metadata fixture changed")
            print("PASS \(ext) EXIF+GPS on/off, normalized orientation/size, no thumbnail, byte-identical JPEG scans")
        }
    }

    /// Removes APP0...APP15 and COM only. All quantization/Huffman/frame/scan
    /// headers, entropy bytes, byte-stuffing and restart markers are preserved.
    static func jpegImagePayload(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0] == 0xff, bytes[1] == 0xd8 else { throw TestError("Invalid JPEG") }
        var result = Data(bytes[0..<2])
        var offset = 2
        while offset < bytes.count {
            let start = offset
            guard bytes[offset] == 0xff else { throw TestError("Expected JPEG marker") }
            while offset < bytes.count && bytes[offset] == 0xff { offset += 1 }
            guard offset < bytes.count else { throw TestError("Incomplete marker") }
            let marker = bytes[offset]
            offset += 1
            if marker == 0xd9 {
                result.append(contentsOf: bytes[start..<offset])
                return result
            }
            guard offset + 2 <= bytes.count else { throw TestError("Missing JPEG length") }
            let length = Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
            guard length >= 2, offset + length <= bytes.count else { throw TestError("Invalid JPEG length") }
            offset += length
            if marker == 0xda {
                while offset < bytes.count {
                    if bytes[offset] != 0xff { offset += 1; continue }
                    guard offset + 1 < bytes.count else { throw TestError("Incomplete scan") }
                    let following = bytes[offset + 1]
                    if following == 0 || (0xd0...0xd7).contains(following) { offset += 2; continue }
                    break
                }
            }
            if !(0xe0...0xef).contains(marker) && marker != 0xfe {
                result.append(contentsOf: bytes[start..<offset])
            }
        }
        throw TestError("Missing JPEG end marker")
    }

    static func hasExifThumbnail(_ data: Data) -> Bool {
        guard let signature = data.range(of: Data([0x45, 0x78, 0x69, 0x66, 0, 0])) else { return false }
        let bytes = [UInt8](data)
        let base = signature.upperBound
        guard base + 8 <= bytes.count else { return true }
        let little = bytes[base] == 0x49
        func integer(_ offset: Int, _ length: Int) -> Int {
            guard offset >= 0, offset + length <= bytes.count else { return Int.max }
            var value = 0
            for i in 0..<length {
                let shift = little ? i * 8 : (length - 1 - i) * 8
                value |= Int(bytes[offset + i]) << shift
            }
            return value
        }
        let relative = integer(base + 4, 4)
        guard relative <= bytes.count - base else { return true }
        let start = base + relative
        let count = integer(start, 2)
        guard count <= 65535 else { return true }
        return integer(start + 2 + count * 12, 4) != 0
    }
}
