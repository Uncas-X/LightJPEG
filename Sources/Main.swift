import AppKit
import Combine
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var localizer: Localizer
    var defaults: UserDefaults = .standard
    var body: some View {
        ContentView(model: model, l: localizer)
            .defaultAppStorage(defaults)
            .environment(\.locale, localizer.locale)
            .environment(\.layoutDirection, localizer.isRTL ? .rightToLeft : .leftToRight)
            .tint(Color(red: 0.16, green: 0.48, blue: 0.37))
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var window: NSWindow!
    var hosting: NSHostingView<RootView>!
    let localizer: Localizer
    let model: AppModel
    private var observation: AnyCancellable?
    private var previewTimer: Timer?
    private let previewPath: String?
    private let appDefaults: UserDefaults
    private var previewOutputDirectory: URL?

    override init() {
        let arguments = CommandLine.arguments
        func option(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        previewPath = option("--render-preview")
        if previewPath != nil {
            let defaults = UserDefaults(suiteName: "LightJPEG.Preview")!
            defaults.removePersistentDomain(forName: "LightJPEG.Preview")
            defaults.set(arguments.contains("--actual-preview"), forKey: "LightJPEG.previewActualPixels")
            appDefaults = defaults
            localizer = Localizer(defaults: defaults)
        } else {
            appDefaults = .standard
            localizer = Localizer()
        }
        if let language = option("--language"), previewPath != nil { localizer.selection = language }
        model = AppModel(localizer: localizer)
        if previewPath != nil { model.preserveEXIF = arguments.contains("--preserve-exif") }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hosting = NSHostingView(rootView: RootView(model: model, localizer: localizer, defaults: appDefaults))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1140, height: 790),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.contentView = hosting
        window.title = localizer.t("app.name")
        window.minSize = NSSize(width: 940, height: 710)
        if previewPath != nil && CommandLine.arguments.contains("--compact") {
            window.setContentSize(NSSize(width: 940, height: 688))
        }
        window.isReleasedWhenClosed = false
        window.center()
        if previewPath == nil { window.setFrameAutosaveName("LightJPEG.MainWindow") }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        buildMenus()
        observation = localizer.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.buildMenus()
                self?.window?.title = self?.localizer.t("app.name") ?? "LightJPEG"
            }
        }

        if let previewPath {
            let arguments = CommandLine.arguments
            var inputs: [URL] = []
            for i in arguments.indices where arguments[i] == "--input" && i + 1 < arguments.count {
                inputs.append(URL(fileURLWithPath: arguments[i + 1]))
            }
            model.addFiles(inputs)
            let previewOutput = FileManager.default.temporaryDirectory.appendingPathComponent("LightJPEG-preview-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: previewOutput, withIntermediateDirectories: true)
            previewOutputDirectory = previewOutput
            let start = Date()
            var started = false
            var readyTime: Date?
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
              MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                if !self.model.importing && !started {
                    started = true
                    if !inputs.isEmpty { self.model.startCompression(to: previewOutput) }
                }
                if started && !self.model.running && !self.model.importing {
                    if readyTime == nil { readyTime = Date() }
                    if Date().timeIntervalSince(readyTime!) > 2 {
                        timer.invalidate()
                        self.renderPreview(to: previewPath)
                        NSApp.terminate(nil)
                    }
                }
                if Date().timeIntervalSince(start) > 90 {
                    timer.invalidate()
                    self.renderPreview(to: previewPath)
                    NSApp.terminate(nil)
                }
              }
            }
        }
    }

    private func renderPreview(to path: String) {
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) { model.addFiles(urls) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        model.cleanUp()
        if let previewOutputDirectory { try? FileManager.default.removeItem(at: previewOutputDirectory) }
    }

    private func item(_ key: String, action: Selector?, equivalent: String = "", modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let item = NSMenuItem(title: localizer.t(key), action: action, keyEquivalent: equivalent)
        item.keyEquivalentModifierMask = modifiers
        if action != nil { item.target = self }
        return item
    }

    private func buildMenus() {
        let main = NSMenu()
        func addMenu(_ title: String, _ entries: [NSMenuItem]) {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            entries.forEach { menu.addItem($0) }
            top.submenu = menu
            main.addItem(top)
        }
        addMenu(localizer.t("app.name"), [
            item("about", action: #selector(showAbout)),
            item("about.license", action: #selector(showLicenses)),
            .separator(),
            item("quit", action: #selector(quit), equivalent: "q")
        ])
        addMenu(localizer.t("menu.file"), [
            item("add", action: #selector(addImages), equivalent: "o"),
            .separator(),
            item("export.selected", action: #selector(exportImage), equivalent: "s"),
            item("output.reveal", action: #selector(revealOutput), equivalent: "r", modifiers: [.command, .shift]),
            .separator(),
            item("clear", action: #selector(clearImages)),
            item("menu.close", action: #selector(closeWindow), equivalent: "w")
        ])
        let editItems = [("menu.undo", "undo:", "z"), ("menu.redo", "redo:", "Z"),
                         ("menu.cut", "cut:", "x"), ("menu.copy", "copy:", "c"),
                         ("menu.paste", "paste:", "v"), ("menu.selectAll", "selectAll:", "a")].map { key, selector, shortcut in
            NSMenuItem(title: localizer.t(key), action: Selector(selector), keyEquivalent: shortcut)
        }
        addMenu(localizer.t("menu.edit"), editItems)
        addMenu(localizer.t("menu.window"), [
            item("menu.minimize", action: #selector(minimize), equivalent: "m"),
            item("menu.zoom", action: #selector(zoom))
        ])
        addMenu(localizer.t("help"), [item("help", action: #selector(showHelp))])
        NSApp.mainMenu = main
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(addImages): return !model.running && !model.importing
        case #selector(exportImage): return model.selectedItem?.result != nil && !model.running && !model.exporting
        case #selector(revealOutput): return model.outputDirectory != nil
        case #selector(clearImages): return !model.items.isEmpty && !model.running && !model.exporting && !model.importing
        default: return true
        }
    }

    @objc private func addImages() { model.openFiles() }
    @objc private func exportImage() { model.exportSelected() }
    @objc private func revealOutput() { model.revealOutputFolder() }
    @objc private func clearImages() { model.clear() }
    @objc private func closeWindow() { window.performClose(nil) }
    @objc private func minimize() { window.miniaturize(nil) }
    @objc private func zoom() { window.zoom(nil) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showLicenses() {
        if let folder = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(folder) }
    }
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = localizer.t("app.name") + " 1.1.1"
        alert.informativeText = localizer.t("about.description") + "\n\nMozJPEG 4.1.5\n\nThis software is based in part on the work of the Independent JPEG Group."
        alert.addButton(withTitle: localizer.t("ok"))
        alert.runModal()
    }
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = localizer.t("help")
        alert.informativeText = localizer.t("help.body")
        alert.addButton(withTitle: localizer.t("ok"))
        alert.runModal()
    }
}

@main struct LightJPEGApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
