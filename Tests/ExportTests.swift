import Foundation

private struct ExportTestError: Error { let message: String }

@main
struct ExportTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ExportTestError(message: message) }
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("LightJPEG-export-tests-\(UUID().uuidString)")
        let a = root.appendingPathComponent("A")
        let b = root.appendingPathComponent("B")
        let output = root.appendingPathComponent("Exports")
        for directory in [a, b, output] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer { try? fm.removeItem(at: root) }
        let sourceA = a.appendingPathComponent("photo.jpg")
        let sourceB = b.appendingPathComponent("photo.jpg")
        let dataA = Data("encoded result A".utf8)
        let dataB = Data("encoded result B".utf8)
        try dataA.write(to: sourceA)
        try dataB.write(to: sourceB)
        let existing = output.appendingPathComponent("photo.jpg")
        let sentinel = Data("existing user file, never overwrite".utf8)
        try sentinel.write(to: existing)
        try fm.createDirectory(at: output.appendingPathComponent("photo-2.jpg"), withIntermediateDirectories: true)

        let outcome = Exporter.copy([(sourceA, "photo"), (sourceB, "photo")], to: output)
        try require(outcome.failures == 0 && outcome.urls.count == 2, "Same-name exports failed")
        try require(outcome.urls[0].lastPathComponent == "photo-3.jpg", "Existing directory not skipped")
        try require(outcome.urls[1].lastPathComponent == "photo-4.jpg", "Duplicate name not disambiguated")
        try require((try? Data(contentsOf: existing)) == sentinel, "Existing user file was modified")
        try require((try? Data(contentsOf: outcome.urls[0])) == dataA, "Source A contents lost")
        try require((try? Data(contentsOf: outcome.urls[1])) == dataB, "Source B contents lost")
        try require((try? Data(contentsOf: sourceA)) == dataA && (try? Data(contentsOf: sourceB)) == dataB,
                    "Original result sources changed")
        print("PASS existing-file and directory collisions, duplicate basenames, source immutability")

        let inPlace = Exporter.copy([(sourceA, "photo")], to: a)
        try require(inPlace.failures == 0 && inPlace.urls.count == 1, "Same-folder export failed")
        try require(inPlace.urls[0].lastPathComponent == "photo-2.jpg", "Same-folder export overwrote source")
        try require((try? Data(contentsOf: sourceA)) == dataA, "Same-folder source modified")
        print("PASS export into source folder without replacing the source")

        let unicodeName = "照片🙂_" + String(repeating: "🙂", count: 61)
        let unicode = Exporter.copy([(sourceA, unicodeName), (sourceB, unicodeName)], to: output)
        try require(unicode.failures == 0 && unicode.urls.count == 2, "Long Chinese/emoji names failed")
        try require(Set(unicode.urls).count == 2, "Unicode names collided")
        for url in unicode.urls {
            try require(url.lastPathComponent.utf8.count <= 255, "NAME_MAX overflow")
            try require(url.lastPathComponent.hasPrefix("照片🙂_"), "Unicode prefix corrupted")
        }
        print("PASS Chinese, emoji, and UTF-8 filename budget")

        let missingDirectory = root.appendingPathComponent("not-created")
        let failedDirectory = Exporter.copy([(sourceA, "photo")], to: missingDirectory)
        try require(failedDirectory.failures == 1 && failedDirectory.urls.isEmpty, "Missing output directory not reported")
        let fileDirectory = Exporter.copy([(sourceA, "photo")], to: existing)
        try require(fileDirectory.failures == 1 && fileDirectory.urls.isEmpty, "File used as directory not reported")
        let missingSource = Exporter.copy([(root.appendingPathComponent("missing.jpg"), "new")], to: output)
        try require(missingSource.failures == 1 && missingSource.urls.isEmpty, "Missing source not reported")
        try require((try? Data(contentsOf: existing)) == sentinel, "Failure path modified existing file")
        print("PASS missing directory, non-directory destination, and missing source failures")
        let remaining = try fm.contentsOfDirectory(atPath: output.path)
        try require(!remaining.contains { $0.hasPrefix(".lightjpeg-") }, "Atomic export leaked staging files")
        print("PASS atomic final-file publication and staging cleanup")
        print("All export integration tests passed.")
    }
}
