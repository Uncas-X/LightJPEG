import Foundation

/// Run with: swiftc -swift-version 5 -parse-as-library Sources/Localizer.swift Tests/LocalizationTests.swift -o /tmp/lightjpeg-localization-tests
@main
struct LocalizationTests {
    @MainActor
    static func main() throws {
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
        }

        expect(Localizer.languages.count == 16, "Exactly 16 supported languages are required")
        expect(Set(Localizer.languages.map { $0.code }).count == 16, "Language codes must be unique")
        let issues = Localizer.validate()
        expect(issues.isEmpty, issues.joined(separator: "\n"))

        let catalogPath = CommandLine.arguments.dropFirst().first ?? "Sources/LocalizationKeys.txt"
        let catalog = try String(contentsOfFile: catalogPath, encoding: .utf8)
        let pairs = catalog.split(separator: "\n").map { line -> (String, String) in
            let values = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(values[0]), String(values[1]))
        }
        let expectedEnglish = Dictionary(uniqueKeysWithValues: pairs)
        expect(Localizer.translations["en"] == expectedEnglish, "Embedded English must match the shared key catalog")
        for language in Localizer.languages {
            expect(Set(Localizer.translations[language.code]!.keys) == Set(expectedEnglish.keys), "Incomplete keys for \(language.code)")
        }
        let workflowKeys: Set<String> = [
            "metadata.exif", "metadata.hint", "output.folder", "output.reveal",
            "output.choose", "output.start", "status.saved", "error.save", "preview.mode",
            "preview.actual.hint", "preview.actual.original", "preview.fit.hint"
        ]
        expect(workflowKeys.isSubset(of: Set(expectedEnglish.keys)), "Automatic save and comparison UI keys must be present")
        expect(expectedEnglish["metadata.gps"] == nil, "GPS belongs to the single EXIF option")

        // Verify literal lookups in the live UI, its menu helpers, model notices, and engine errors.
        // This catches newly added call sites whose keys were omitted from the translation catalog.
        let sourcesURL = URL(fileURLWithPath: catalogPath).deletingLastPathComponent()
        let sourceFiles = try FileManager.default.contentsOfDirectory(at: sourcesURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "Localizer.swift" }
        var usedKeys: Set<String> = []
        let literal = try NSRegularExpression(pattern: #""([^"\\]*(?:\\.[^"\\]*)*)""#)
        let lookup = try NSRegularExpression(pattern: #"\b(?:l|localizer)\.(?:t|format)\s*\(([^\n)]*)"#)
        let helper = try NSRegularExpression(pattern: #"\b(?:item|summaryMetric|setNotice)\s*\(\s*"([^"]+)""#)
        let failure = try NSRegularExpression(pattern: #"CompressionFailure\s*\(\s*key:\s*"([^"]+)""#)
        let namespaces = Set(expectedEnglish.keys.compactMap { $0.contains(".") ? $0.split(separator: ".").first.map(String.init) : nil })
        func captures(_ expression: NSRegularExpression, in source: String) -> [String] {
            expression.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap {
                Range($0.range(at: 1), in: source).map { String(source[$0]) }
            }
        }
        for file in sourceFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for argument in captures(lookup, in: source) { usedKeys.formUnion(captures(literal, in: argument)) }
            usedKeys.formUnion(captures(helper, in: source))
            usedKeys.formUnion(captures(failure, in: source))
            // Indirect menu tuple entries are passed via a variable to localizer.t(key).
            for value in captures(literal, in: source) {
                if value.contains("."), let namespace = value.split(separator: ".").first,
                   namespaces.contains(String(namespace)) { usedKeys.insert(value) }
            }
        }
        expect(usedKeys.count >= 60, "Static localization scanner should cover the application's UI")
        expect(usedKeys.isSubset(of: Set(expectedEnglish.keys)),
               "UI uses untranslated keys: \(usedKeys.subtracting(expectedEnglish.keys).sorted())")

        let resolutionCases: [([String], String)] = [
            ([], "en"), (["unknown"], "en"), ([""], "en"),
            (["zh"], "zh-Hans"), (["zh-CN"], "zh-Hans"), (["zh-SG"], "zh-Hans"),
            (["zh-TW"], "zh-Hant"), (["zh-HK"], "zh-Hant"), (["zh-MO"], "zh-Hant"),
            (["zh_HK"], "zh-Hant"), (["ZH-hant-us"], "zh-Hant"),
            (["zh-Hant-CN"], "zh-Hant"), (["zh-Hans-TW"], "zh-Hans"),
            (["pt"], "pt-BR"), (["pt-PT"], "pt-BR"), (["pt_BR"], "pt-BR"),
            (["en-GB"], "en"), (["ja-JP"], "ja"), (["ko-KR"], "ko"),
            (["fr-CA"], "fr"), (["de-AT"], "de"), (["es-419"], "es"),
            (["it-CH"], "it"), (["ru-RU"], "ru"), (["ar-EG"], "ar"),
            (["hi-IN"], "hi"), (["tr-TR"], "tr"), (["nl-BE"], "nl"), (["pl-PL"], "pl"),
            (["sv-SE", "fi-FI", "fr-CA", "en-US"], "fr"),
            (["fr-CA", "zh-CN"], "fr"), (["zh-TW", "zh-CN"], "zh-Hant"),
            (["he-IL", "de-DE"], "de")
        ]
        for (preferences, expected) in resolutionCases {
            expect(Localizer.resolve(preferredLanguages: preferences) == expected,
                   "Wrong resolution for \(preferences): expected \(expected)")
        }

        let suiteName = "LightJPEG.LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let localizer = Localizer(defaults: defaults, preferredLanguages: ["zh-HK", "en-US"])
        expect(localizer.selection == "system", "Initial selection must follow the system")
        expect(localizer.resolvedCode == "zh-Hant", "System language should resolve to Traditional Chinese")
        expect(localizer.locale.identifier == "zh-Hant", "Locale must match resolved language")
        expect(!localizer.isRTL, "Chinese must use LTR")
        expect(localizer.t("queue.count", "7") == "7 張圖片", "Arguments should be substituted")

        localizer.selection = "ar"
        expect(localizer.resolvedCode == "ar" && localizer.isRTL, "Arabic must update locale and RTL immediately")
        expect(defaults.string(forKey: Localizer.preferenceKey) == "ar", "Language selection must persist")
        let restored = Localizer(defaults: defaults, preferredLanguages: ["en-US"])
        expect(restored.selection == "ar" && restored.resolvedCode == "ar", "Stored manual language must override the system")

        localizer.selection = "hi"
        expect(localizer.t("status.progress", "2", "7") == "7 में से 2", "Placeholder order must follow the translation")
        expect(!localizer.isRTL, "Switching away from Arabic must restore LTR")

        for language in Localizer.languages {
            localizer.selection = language.code
            expect(localizer.locale.identifier == language.code, "Wrong locale after manual selection")
            for (key, value) in Localizer.translations[language.code]! {
                expect(localizer.t(key) == value, "Wrong language lookup for \(language.code)/\(key)")
            }
            let message = localizer.format("export.partial", arguments: ["12", "3"])
            expect(!message.contains("{0}") && !message.contains("{1}"), "Unsubstituted export arguments")
            let savedMessage = localizer.format("status.saved", arguments: ["1", "0"])
            expect(!savedMessage.contains("{0}") && !savedMessage.contains("{1}"), "Unsubstituted automatic-save counts")
            expect(localizer.t("preview.actual").contains("1:1"), "Actual-pixel view must identify its scale")
            expect(localizer.t("metadata.hint").contains("GPS"), "The EXIF option must disclose that it includes GPS")
            expect(localizer.t("help.body").contains("EXIF") && localizer.t("help.body").contains("GPS"), "Help must explain EXIF and GPS retention")
        }

        localizer.selection = "system"
        expect(localizer.resolvedCode == "zh-Hant", "System mode must restore system language")
        expect(defaults.string(forKey: Localizer.preferenceKey) == "system", "System selection must persist")
        expect(localizer.t("missing.test.key") == "⟦missing.test.key⟧", "Missing keys should be visible, not silently fall back")
        defaults.set("unsupported", forKey: Localizer.preferenceKey)
        let repaired = Localizer(defaults: defaults, preferredLanguages: ["nl-NL"])
        expect(repaired.selection == "system" && repaired.resolvedCode == "nl", "An obsolete stored language must use system mode")

        print("Localization PASS: \(Localizer.languages.count) languages × \(expectedEnglish.count) keys; \(usedKeys.count) static UI/menu/model/engine keys, placeholders, \(resolutionCases.count) locale cases, persistence, switching, and RTL verified.")
    }
}
