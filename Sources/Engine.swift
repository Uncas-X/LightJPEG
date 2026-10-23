import Foundation
import CoreGraphics
import ImageIO

struct CompressionSettings: Sendable {
    let quality: Int
    let maxDimension: Int
    let chroma444: Bool
    let preserveEXIF: Bool

    init(quality: Int, maxDimension: Int, chroma444: Bool,
         preserveEXIF: Bool = false) {
        self.quality = quality
        self.maxDimension = maxDimension
        self.chroma444 = chroma444
        self.preserveEXIF = preserveEXIF
    }
}

struct CompressionResult: Sendable {
    let outputURL: URL
    let originalBytes: Int64
    let outputBytes: Int64
    let width: Int
    let height: Int
    let quality: Int
}

struct CompressionFailure: Error {
    let key: String
    let detail: String
}

/// A token owns at most one encoder process. Cancellation may be requested from
/// the main thread while decoding/encoding runs on a background queue.
final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var process: Process?

    init() {}

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        if let process, process.isRunning { process.terminate() }
        lock.unlock()
    }

    fileprivate func run(_ candidate: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        if cancelled { throw CompressionEngine.cancelled() }
        // Holding the lock closes the race between checking cancellation and
        // starting the process; cancel() can terminate it immediately afterward.
        try candidate.run()
        process = candidate
    }

    fileprivate func detach(_ candidate: Process) {
        lock.lock()
        if process === candidate { process = nil }
        lock.unlock()
    }
}

enum CompressionEngine {
    private static let maximumPixels = 100_000_000
    private static let maximumJPEGDimension = 65_500

    fileprivate static func cancelled() -> CompressionFailure {
        CompressionFailure(key: "error.cancelled", detail: "")
    }

    private static func check(_ cancellation: CancellationToken) throws {
        if cancellation.isCancelled { throw cancelled() }
    }

    static func compress(input: URL, outputDirectory: URL,
                         settings: CompressionSettings,
                         cancellation: CancellationToken) throws -> CompressionResult {
        try check(cancellation)
        let fm = FileManager.default
        let originalBytes: Int64
        do {
            let values = try input.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let count = values.fileSize else {
                throw CompressionFailure(key: "error.read", detail: input.lastPathComponent)
            }
            originalBytes = Int64(count)
        } catch let error as CompressionFailure { throw error }
        catch { throw CompressionFailure(key: "error.read", detail: error.localizedDescription) }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(input as CFURL, sourceOptions),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              rawWidth > 0, rawHeight > 0 else {
            throw CompressionFailure(key: "error.decode", detail: input.lastPathComponent)
        }
        // Some ImageIO formats still allocate a full-sized decoder buffer when
        // creating a thumbnail. Bound source pixels as well as output pixels.
        // A resize request must not bypass this memory budget.
        guard rawWidth <= maximumPixels / rawHeight else {
            throw CompressionFailure(key: "error.large", detail: "\(rawWidth) × \(rawHeight)")
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapsAxes = (5...8).contains(orientation)
        let orientedWidth = swapsAxes ? rawHeight : rawWidth
        let orientedHeight = swapsAxes ? rawWidth : rawHeight
        let limit = settings.maxDimension > 0 ? settings.maxDimension : max(orientedWidth, orientedHeight)
        let ratio = min(1.0, Double(limit) / Double(max(orientedWidth, orientedHeight)))
        let width = max(1, Int((Double(orientedWidth) * ratio).rounded()))
        let height = max(1, Int((Double(orientedHeight) * ratio).rounded()))
        guard width <= maximumJPEGDimension, height <= maximumJPEGDimension,
              width <= maximumPixels / height else {
            throw CompressionFailure(key: "error.large", detail: "\(width) × \(height)")
        }

        try check(cancellation)
        // ImageIO applies all EXIF rotations and reflections before rendering.
        // Thumbnail creation also avoids full-resolution decoding when downsizing.
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary) else {
            throw CompressionFailure(key: "error.decode", detail: input.lastPathComponent)
        }
        try check(cancellation)
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: sRGB,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                                  CGBitmapInfo.byteOrder32Big.rawValue),
              let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else {
            throw CompressionFailure(key: "error.large", detail: "\(width) × \(height)")
        }
        context.setFillColor(CGColor(colorSpace: sRGB, components: [1, 1, 1, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: width, height: height))
        try check(cancellation)

        let jobID = UUID().uuidString
        let temporary = fm.temporaryDirectory.appendingPathComponent("LightJPEG-\(jobID)", isDirectory: true)
        do { try fm.createDirectory(at: temporary, withIntermediateDirectories: true) }
        catch { throw CompressionFailure(key: "error.write", detail: error.localizedDescription) }
        defer { try? fm.removeItem(at: temporary) }
        let ppmURL = temporary.appendingPathComponent("pixels.ppm")
        let encodedURL = temporary.appendingPathComponent("encoded.jpg")
        let logURL = temporary.appendingPathComponent("encoder.log")
        do {
            guard fm.createFile(atPath: ppmURL.path, contents: nil) else {
                throw CompressionFailure(key: "error.write", detail: ppmURL.lastPathComponent)
            }
            let ppm = try FileHandle(forWritingTo: ppmURL)
            defer { try? ppm.close() }
            try ppm.write(contentsOf: Data("P6\n\(width) \(height)\n255\n".utf8))
            var row = Data(count: width * 3)
            for y in 0..<height {
                if y % 32 == 0 { try check(cancellation) }
                row.withUnsafeMutableBytes { raw in
                    let destination = raw.bindMemory(to: UInt8.self)
                    let sourceRow = pixels.advanced(by: y * context.bytesPerRow)
                    for x in 0..<width {
                        destination[x * 3] = sourceRow[x * 4]
                        destination[x * 3 + 1] = sourceRow[x * 4 + 1]
                        destination[x * 3 + 2] = sourceRow[x * 4 + 2]
                    }
                }
                try ppm.write(contentsOf: row)
            }
        } catch let error as CompressionFailure { throw error }
        catch { throw CompressionFailure(key: "error.write", detail: error.localizedDescription) }

        let executable = try encoderURL()
        let quality = min(100, max(1, settings.quality))
        var arguments = ["-quality", String(quality), "-progressive", "-optimize",
                         "-sample", settings.chroma444 ? "1x1,1x1,1x1" : "2x2,1x1,1x1"]
        // Embed the output colour description without carrying source EXIF/GPS.
        if let profile = sRGB.copyICCData() {
            let profileURL = temporary.appendingPathComponent("sRGB.icc")
            do { try (profile as Data).write(to: profileURL) }
            catch { throw CompressionFailure(key: "error.write", detail: error.localizedDescription) }
            arguments += ["-icc", profileURL.path]
        }
        arguments += ["-outfile", encodedURL.path, ppmURL.path]
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        guard fm.createFile(atPath: logURL.path, contents: nil),
              let log = try? FileHandle(forWritingTo: logURL) else {
            throw CompressionFailure(key: "error.write", detail: logURL.lastPathComponent)
        }
        defer { try? log.close() }
        process.standardError = log
        do { try cancellation.run(process) }
        catch let error as CompressionFailure { throw error }
        catch { throw CompressionFailure(key: "error.encoder", detail: error.localizedDescription) }
        defer { cancellation.detach(process) }
        process.waitUntilExit()
        try check(cancellation)
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            throw CompressionFailure(key: "error.encode", detail: String(message.prefix(1500)))
        }
        guard let outputSource = CGImageSourceCreateWithURL(encodedURL as CFURL, sourceOptions),
              let outputProperties = CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any],
              (outputProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == width,
              (outputProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == height else {
            throw CompressionFailure(key: "error.encode", detail: "Invalid encoder output")
        }
        try check(cancellation)
        let finishedURL: URL
        if settings.preserveEXIF {
            finishedURL = temporary.appendingPathComponent("with-metadata.jpg")
            try JPEGMetadata.copySelected(from: source, properties: properties,
                                          encodedSource: outputSource, to: finishedURL,
                                          width: width, height: height, settings: settings)
            try check(cancellation)
        } else {
            finishedURL = encodedURL
        }
        // NAME_MAX is a byte limit, not a Swift Character limit. Keep ample
        // space for the suffix even with CJK or multi-scalar emoji basenames.
        var stem = ""
        for character in input.deletingPathExtension().lastPathComponent {
            let next = String(character)
            if stem.utf8.count + next.utf8.count > 180 { break }
            stem.append(character)
        }
        if stem.isEmpty { stem = "image" }
        let outputURL = outputDirectory.appendingPathComponent("\(stem)-compressed-\(jobID.prefix(8)).jpg")
        do {
            try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try fm.moveItem(at: finishedURL, to: outputURL)
            if cancellation.isCancelled {
                try? fm.removeItem(at: outputURL)
                throw cancelled()
            }
            let count = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard count > 0 else {
                try? fm.removeItem(at: outputURL)
                throw CompressionFailure(key: "error.encode", detail: "Empty encoder output")
            }
            return CompressionResult(outputURL: outputURL, originalBytes: originalBytes,
                                     outputBytes: Int64(count), width: width, height: height, quality: quality)
        } catch let error as CompressionFailure { throw error }
        catch { throw CompressionFailure(key: "error.write", detail: error.localizedDescription) }
    }

    private static func encoderURL() throws -> URL {
        let fm = FileManager.default
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("bin/cjpeg"),
           fm.isExecutableFile(atPath: bundled.path) { return bundled }
        // Enables CLI integration tests and direct development builds. Packaged
        // apps require their own bundled encoder and never search PATH.
        if Bundle.main.bundleURL.pathExtension != "app" {
            let development = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/bin/cjpeg")
            if fm.isExecutableFile(atPath: development.path) { return development }
        }
        throw CompressionFailure(key: "error.encoder", detail: "Bundled MozJPEG encoder is missing")
    }
}

/// Adds selected standard metadata to the *already compressed* MozJPEG output.
/// Apple's CGImageDestinationCopyImageSource contract guarantees that image data
/// is copied losslessly; this path never calls AddImage or Finalize, which could
/// invoke another lossy JPEG encoder.
private enum JPEGMetadata {
    static func copySelected(from original: CGImageSource, properties: [CFString: Any],
                             encodedSource: CGImageSource, to destinationURL: URL,
                             width: Int, height: Int, settings: CompressionSettings) throws {
        let selected = CGImageMetadataCreateMutable()
        if let metadata = CGImageSourceCopyMetadataAtIndex(original, 0, nil) {
            var dictionaries: [CFString] = []
            if settings.preserveEXIF {
                dictionaries += [kCGImagePropertyExifDictionary, kCGImagePropertyExifAuxDictionary,
                                 kCGImagePropertyTIFFDictionary]
            }
            if settings.preserveEXIF { dictionaries.append(kCGImagePropertyGPSDictionary) }

            let skipped: Set<String> = [
                kCGImagePropertyExifMakerNote as String,
                kCGImagePropertyExifPixelXDimension as String,
                kCGImagePropertyExifPixelYDimension as String,
                kCGImagePropertyExifColorSpace as String,
                kCGImagePropertyExifSubjectArea as String,
                kCGImagePropertyExifSubjectLocation as String,
                kCGImagePropertyExifComponentsConfiguration as String,
                kCGImagePropertyExifCompressedBitsPerPixel as String,
                kCGImagePropertyTIFFOrientation as String,
                kCGImagePropertyTIFFCompression as String,
                kCGImagePropertyTIFFPhotometricInterpretation as String,
                kCGImagePropertyTIFFTransferFunction as String,
                kCGImagePropertyTIFFWhitePoint as String,
                kCGImagePropertyTIFFPrimaryChromaticities as String,
                kCGImagePropertyTIFFTileWidth as String,
                kCGImagePropertyTIFFTileLength as String
            ]
            for dictionary in dictionaries {
                guard let values = properties[dictionary] as? [String: Any] else { continue }
                for key in values.keys.sorted() where !skipped.contains(key) {
                    // Bridge through ImageIO's standard-property mapping rather
                    // than copying arbitrary XMP namespaces or opaque MakerNotes.
                    // In particular, GPS coordinates and time values retain their
                    // correct XMP/EXIF representations and hemisphere references.
                    guard let tag = CGImageMetadataCopyTagMatchingImageProperty(metadata, dictionary, key as CFString),
                          let prefix = CGImageMetadataTagCopyPrefix(tag),
                          let name = CGImageMetadataTagCopyName(tag) else { continue }
                    let path = "\(prefix):\(name)" as CFString
                    _ = CGImageMetadataSetTagWithPath(selected, nil, path, tag)
                }
            }
        }

        let normalized: [(CFString, CFString, Int)] = [
            (kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation, 1),
            (kCGImagePropertyExifDictionary, kCGImagePropertyExifPixelXDimension, width),
            (kCGImagePropertyExifDictionary, kCGImagePropertyExifPixelYDimension, height),
            (kCGImagePropertyExifDictionary, kCGImagePropertyExifColorSpace, 1)
        ]
        for (dictionary, property, value) in normalized {
            guard CGImageMetadataSetValueMatchingImageProperty(selected, dictionary, property, value as CFNumber) else {
                throw CompressionFailure(key: "error.encode", detail: "Unable to normalize JPEG metadata")
            }
        }
        guard let type = CGImageSourceGetType(encodedSource),
              let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type, 1, nil) else {
            throw CompressionFailure(key: "error.write", detail: "Unable to create metadata destination")
        }
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: selected,
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: !settings.preserveEXIF,
            kCGImageMetadataShouldExcludeXMP: true
        ]
        var error: Unmanaged<CFError>?
        guard CGImageDestinationCopyImageSource(destination, encodedSource, options as CFDictionary, &error) else {
            let detail = error.map { String(describing: $0.takeRetainedValue()) } ?? "Unable to copy JPEG metadata"
            throw CompressionFailure(key: "error.encode", detail: detail)
        }
    }
}
