import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ItemState { case queued, processing, done, failed }

struct CompressionItem: Identifiable {
    let id: UUID
    let url: URL
    let originalBytes: Int64
    var state: ItemState = .queued
    var result: CompressionResult?
    var savedURL: URL?
    var errorKey: String?
    var errorDetail: String?
    var thumbnail: NSImage?
}

struct ExportOutcome {
    var urls: [URL] = []
    var failures = 0
}

enum Exporter {
    static func outputName(for input: URL) -> String {
        var stem = ""
        for character in input.deletingPathExtension().lastPathComponent {
            if (stem + String(character)).utf8.count > 180 { break }
            stem.append(character)
        }
        return (stem.isEmpty ? "image" : stem) + "_compressed"
    }
    // copyItem fails if a destination already exists, including races with other apps.
    // A fresh name is selected; originals and existing exports are never overwritten.
    static func copy(_ entries: [(source: URL, name: String)], to directory: URL) -> ExportOutcome {
        var outcome = ExportOutcome()
        for entry in entries {
            // Copy to a private staging file first. Only a complete image becomes
            // visible under its final name, even on a failed filesystem write.
            let staging = directory.appendingPathComponent(".lightjpeg-\(UUID().uuidString).tmp")
            do { try FileManager.default.copyItem(at: entry.source, to: staging) }
            catch { try? FileManager.default.removeItem(at: staging); outcome.failures += 1; continue }
            defer { try? FileManager.default.removeItem(at: staging) }
            var safeName = ""
            for character in entry.name {
                if (safeName + String(character)).utf8.count > 200 { break }
                safeName.append(character)
            }
            if safeName.isEmpty { safeName = "image" }
            var copied = false
            for suffix in 0..<10_000 {
                let name = safeName + (suffix == 0 ? "" : "-\(suffix + 1)") + ".jpg"
                let target = directory.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target.path) { continue }
                do {
                    try FileManager.default.moveItem(at: staging, to: target)
                    outcome.urls.append(target)
                    copied = true
                    break
                } catch {
                    let e = error as NSError
                    if e.domain == NSCocoaErrorDomain && e.code == NSFileWriteFileExistsError { continue }
                    break
                }
            }
            if !copied { outcome.failures += 1 }
        }
        return outcome
    }
}

@MainActor final class AppModel: ObservableObject {
    @Published var items: [CompressionItem] = []
    @Published var selectionID: UUID?
    @Published var quality: Double = 75
    @Published var maxDimension: Int = 0
    @Published var chroma444 = false
    @Published var preserveEXIF = false
    @Published var outputDirectory: URL?
    @Published var running = false
    @Published var importing = false
    @Published var exporting = false
    @Published var completed = 0
    @Published var noticeKey: String?
    @Published var noticeArgs: [String] = []

    let localizer: Localizer
    private var token: CancellationToken?
    private var task: Task<Void, Never>?
    private var lastSettings: (quality: Int, dimension: Int, chroma: Bool, exif: Bool)?
    private let sessionDirectory: URL
    private var pendingImports: [URL] = []
    private let directoryChooser: (() -> URL?)?

    init(localizer: Localizer, directoryChooser: (() -> URL?)? = nil) {
        self.localizer = localizer
        self.directoryChooser = directoryChooser
        self.sessionDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightJPEG-\(UUID().uuidString)", isDirectory: true)
    }

    var selectedItem: CompressionItem? { items.first { $0.id == selectionID } }
    var finishedItems: [CompressionItem] { items.filter { $0.state == .done && $0.result != nil } }
    var originalTotal: Int64 { finishedItems.reduce(0) { $0 + ($1.result?.originalBytes ?? 0) } }
    var outputTotal: Int64 { finishedItems.reduce(0) { $0 + ($1.result?.outputBytes ?? 0) } }
    var savedBytes: Int64 { originalTotal - outputTotal }
    var progress: Double { items.isEmpty ? 0 : Double(completed) / Double(items.count) }
    var hasResults: Bool { !finishedItems.isEmpty }
    var settingsChanged: Bool {
        guard let s = lastSettings, hasResults else { return false }
        return s.quality != Int(quality.rounded()) || s.dimension != maxDimension || s.chroma != chroma444 || s.exif != preserveEXIF
    }

    static func size(_ bytes: Int64, locale: Locale = .current) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = abs(Double(bytes))
        var index = 0
        while value >= 1000 && index < units.count - 1 { value /= 1000; index += 1 }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = index == 0 ? 0 : 1
        let text = formatter.string(from: NSNumber(value: bytes < 0 ? -value : value)) ?? "0"
        return text + " " + units[index]
    }

    func openFiles() {
        guard !running else { return }
        let panel = NSOpenPanel()
        panel.title = localizer.t("add")
        panel.prompt = localizer.t("add")
        panel.allowedContentTypes = [.jpeg, .png, .heic, .heif, .tiff, .webP, .bmp]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    func addFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        // Finder may send another open event while a batch is still loading/encoding.
        if running || importing { pendingImports.append(contentsOf: urls); return }
        importing = true
        noticeKey = nil
        let existing = Set(items.map { $0.url.resolvingSymlinksInPath().standardizedFileURL.path })
        let capacity = max(0, 1000 - items.count)
        Task {
            let imported = await Task.detached(priority: .userInitiated) {
                Self.collect(urls, excluding: existing, capacity: capacity)
            }.value
            items.append(contentsOf: imported.items)
            if selectionID == nil { selectionID = items.first?.id }
            importing = false
            if imported.limited { setNotice("status.limit") }
            else if imported.items.isEmpty { setNotice("status.empty") }
            drainImports()
        }
    }

    nonisolated private static func collect(_ urls: [URL], excluding existing: Set<String>, capacity: Int)
        -> (items: [CompressionItem], limited: Bool) {
        let extensions = Set(["jpg", "jpeg", "jpe", "png", "heic", "heif", "tif", "tiff", "webp", "bmp"])
        var found: [CompressionItem] = []
        var seen = existing
        var limited = false
        func include(_ candidate: URL) {
            guard !limited, candidate.isFileURL,
                  extensions.contains(candidate.pathExtension.lowercased()) else { return }
            let url = candidate.resolvingSymlinksInPath().standardizedFileURL
            guard !seen.contains(url.path) else { return }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return }
            guard found.count < capacity else { limited = true; return }
            seen.insert(url.path)
            let thumbnail: NSImage? = autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight] as? Int,
                      width > 0, height > 0, width <= 100_000_000 / height,
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 100,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil }
                return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            }
            found.append(CompressionItem(id: UUID(), url: url, originalBytes: Int64(values.fileSize ?? 0), thumbnail: thumbnail))
        }
        for url in urls where url.isFileURL {
            if limited { break }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                if let enumerator = FileManager.default.enumerator(at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let child as URL in enumerator { include(child); if limited { break } }
                }
            } else { include(url) }
        }
        return (found, limited)
    }

    private func drainImports() {
        guard !pendingImports.isEmpty, !running, !importing else { return }
        let next = pendingImports
        pendingImports.removeAll()
        addFiles(next)
    }

    func startCompression() {
        guard !running, !importing, !exporting, !items.isEmpty else { return }
        let chosen: URL?
        if let directoryChooser { chosen = directoryChooser() }
        else {
            let panel = NSOpenPanel()
            panel.title = localizer.t("output.choose")
            panel.prompt = localizer.t("output.start")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = outputDirectory
            chosen = panel.runModal() == .OK ? panel.url : nil
        }
        // Cancelling the chooser must not discard the current queue or results.
        guard let chosen else { return }
        startCompression(to: chosen)
    }

    func startCompression(to destination: URL) {
        guard !running, !importing, !exporting, !items.isEmpty else { return }
        guard destination.isFileURL,
              (try? destination.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            setNotice("error.save"); return
        }
        do { try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true) }
        catch { setNotice("error.write"); return }
        let settings = CompressionSettings(quality: Int(quality.rounded()), maxDimension: maxDimension,
                                           chroma444: chroma444, preserveEXIF: preserveEXIF)
        lastSettings = (settings.quality, settings.maxDimension, settings.chroma444, settings.preserveEXIF)
        outputDirectory = destination
        let cancellation = CancellationToken()
        token = cancellation
        running = true
        completed = 0
        noticeKey = nil
        for index in items.indices {
            if let old = items[index].result?.outputURL { try? FileManager.default.removeItem(at: old) }
            items[index].state = .queued
            items[index].result = nil
            items[index].savedURL = nil
            items[index].errorKey = nil
            items[index].errorDetail = nil
        }
        let jobs = items.map { (id: $0.id, url: $0.url) }
        let outputDirectory = sessionDirectory
        task = Task {
            var failures = 0
            for job in jobs {
                if cancellation.isCancelled { break }
                guard let index = items.firstIndex(where: { $0.id == job.id }) else { continue }
                items[index].state = .processing
                let result: Result<CompressionResult, Error> = await Task.detached(priority: .userInitiated) {
                    Result { try CompressionEngine.compress(input: job.url, outputDirectory: outputDirectory,
                                                             settings: settings, cancellation: cancellation) }
                }.value
                guard let current = items.firstIndex(where: { $0.id == job.id }) else { continue }
                switch result {
                case .success(let output):
                    items[current].result = output
                    let name = Exporter.outputName(for: job.url)
                    let saved = await Task.detached(priority: .userInitiated) {
                        Exporter.copy([(output.outputURL, name)], to: destination)
                    }.value
                    if let savedURL = saved.urls.first {
                        items[current].savedURL = savedURL
                        items[current].state = .done
                    } else {
                        items[current].state = .failed
                        items[current].errorKey = "error.save"
                        failures += 1
                    }
                    completed += 1
                case .failure(let error):
                    if cancellation.isCancelled {
                        items[current].state = .queued
                    } else {
                        items[current].state = .failed
                        items[current].errorKey = (error as? CompressionFailure)?.key ?? "error.encode"
                        items[current].errorDetail = (error as? CompressionFailure)?.detail
                        failures += 1
                        completed += 1
                    }
                }
            }
            running = false
            token = nil
            task = nil
            if cancellation.isCancelled { setNotice("status.cancelled") }
            else { setNotice("status.saved", String(finishedItems.count), String(failures)) }
            drainImports()
        }
    }

    func cancel() { token?.cancel() }

    func clear() {
        guard !running, !importing, !exporting else { return }
        for item in items { if let url = item.result?.outputURL { try? FileManager.default.removeItem(at: url) } }
        items.removeAll()
        selectionID = nil
        completed = 0
        noticeKey = nil
        lastSettings = nil
    }

    func removeSelected() {
        guard !running, !importing, !exporting, let id = selectionID else { return }
        if let url = selectedItem?.result?.outputURL { try? FileManager.default.removeItem(at: url) }
        items.removeAll { $0.id == id }
        selectionID = items.first?.id
        completed = items.filter { $0.state == .done || $0.state == .failed }.count
    }

    func exportAll() { export(finishedItems) }
    func exportSelected() { if let item = selectedItem, item.result != nil { export([item]) } }

    private func export(_ selected: [CompressionItem]) {
        guard !exporting, !running, !selected.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = localizer.t("export.choose")
        panel.prompt = localizer.t(selected.count == 1 ? "export.selected" : "export.all")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        exporting = true
        let entries: [(source: URL, name: String)] = selected.compactMap { item in
            guard let result = item.result else { return nil }
            return (result.outputURL, Exporter.outputName(for: item.url))
        }
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { Exporter.copy(entries, to: directory) }.value
            exporting = false
            if outcome.failures == 0 { setNotice("export.success", String(outcome.urls.count)) }
            else { setNotice("export.partial", String(outcome.urls.count), String(outcome.failures)) }
            if !outcome.urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(outcome.urls) }
        }
    }

    func revealSource() {
        guard let url = selectedItem?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealOutputFolder() {
        guard let outputDirectory else { return }
        NSWorkspace.shared.open(outputDirectory)
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !running else { return false }
        let valid = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        for provider in valid {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let value = item as? URL { url = value }
                else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let string = item as? String { url = URL(string: string) }
                else { url = nil }
                if let url, url.isFileURL { Task { @MainActor in self.addFiles([url]) } }
            }
        }
        return !valid.isEmpty
    }

    func setNotice(_ key: String, _ args: String...) {
        noticeArgs = args
        noticeKey = key
    }

    func cleanUp() {
        token?.cancel()
        try? FileManager.default.removeItem(at: sessionDirectory)
    }
}
