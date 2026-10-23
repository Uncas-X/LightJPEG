import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var l: Localizer
    @Environment(\.colorScheme) private var colorScheme
    @State private var dropIsTargeted = false

    private let accent = Color(red: 0.18, green: 0.53, blue: 0.38)
    private var surface: Color { Color(nsColor: .controlBackgroundColor) }
    private var background: Color {
        colorScheme == .dark ? Color(red: 0.115, green: 0.125, blue: 0.12) : Color(red: 0.965, green: 0.965, blue: 0.945)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            workspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            settings
            Divider()
            actionBar
        }
        .background(background)
        .tint(accent)
        .frame(minWidth: 900, minHeight: 650)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropIsTargeted, perform: model.handleDrop)
        .overlay {
            if dropIsTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent, style: StrokeStyle(lineWidth: 3, dash: [9, 5]))
                    .background(accent.opacity(0.07))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.t("app.name")).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(l.t("app.tagline")).font(.system(size: 11.5)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 16)
            Button(action: model.openFiles) {
                Label(l.t("add"), systemImage: "plus")
            }
            .controlSize(.large)
            .disabled(model.running || model.importing)
            Picker(l.t("language"), selection: $l.selection) {
                Text(l.t("language.system")).tag("system")
                Divider()
                ForEach(Localizer.languages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
            .labelsHidden()
            .frame(width: 210)
            .help(l.t("language"))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder private var workspace: some View {
        if model.items.isEmpty {
            emptyWorkspace
        } else {
            HStack(spacing: 0) {
                queuePane.frame(width: 278)
                Divider()
                previewPane
            }
        }
    }

    private var emptyWorkspace: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(accent.opacity(0.09))
                    .frame(width: 112, height: 100)
                    .rotationEffect(.degrees(-7))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .frame(width: 83, height: 75)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
                Image(systemName: "photo.badge.arrow.down")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(accent)
            }
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(l.t("empty.title"))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(l.t("empty.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            Button(action: model.openFiles) {
                Label(l.t("add"), systemImage: "plus")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.importing)
            if model.importing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(l.t("status.importing"))
                }.font(.caption).foregroundColor(.secondary)
            } else {
                Text(l.t("empty.formats"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }

    private var queuePane: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l.t("queue")).font(.system(size: 13, weight: .semibold))
                Text(number(model.items.count))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                Spacer()
                if model.importing { ProgressView().controlSize(.small) }
                Button(action: model.clear) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .help(l.t("clear"))
                    .accessibilityLabel(l.t("clear"))
                    .disabled(model.running || model.importing || model.exporting)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(model.items) { item in
                        queueRow(item)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.bottom, 10)
            }
            Divider()
            HStack {
                Text(l.t("queue.count", number(model.items.count)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: model.removeSelected) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help(l.t("remove"))
                .accessibilityLabel(l.t("remove"))
                .disabled(model.selectionID == nil || model.running || model.importing || model.exporting)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(surface.opacity(0.52))
    }

    private func queueRow(_ item: CompressionItem) -> some View {
        let selected = model.selectionID == item.id
        return Button {
            model.selectionID = item.id
        } label: {
            HStack(spacing: 10) {
                thumbnail(item)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 4) {
                        Text(AppModel.size(item.originalBytes, locale: l.locale))
                        if let result = item.result {
                            Image(systemName: l.isRTL ? "arrow.left" : "arrow.right").font(.system(size: 8))
                            Text(AppModel.size(result.outputBytes, locale: l.locale))
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    if item.state == .failed {
                        Text(l.t(item.errorKey ?? "error.encode"))
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                statusIcon(item)
            }
            .padding(10)
            .background(selected ? accent.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? accent.opacity(0.19) : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.url.lastPathComponent + ", " + stateText(item.state))
        .contextMenu {
            Button(l.t("export.selected")) {
                model.selectionID = item.id
                model.exportSelected()
            }
            .disabled(item.result == nil || model.running || model.exporting)
            Button(l.t("reveal")) {
                model.selectionID = item.id
                model.revealSource()
            }
            Divider()
            Button(l.t("remove")) {
                model.selectionID = item.id
                model.removeSelected()
            }
            .disabled(model.running || model.importing || model.exporting)
        }
    }

    private func thumbnail(_ item: CompressionItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.055))
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo").foregroundColor(.secondary)
            }
        }
        .frame(width: 43, height: 43)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityHidden(true)
    }

    @ViewBuilder private func statusIcon(_ item: CompressionItem) -> some View {
        switch item.state {
        case .processing:
            ProgressView().controlSize(.small).frame(width: 15)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(accent)
                .help(l.t("status.done"))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .help(l.t("status.failed"))
        case .queued:
            Image(systemName: "circle.dashed")
                .foregroundColor(.secondary.opacity(0.6))
                .help(l.t("status.queued"))
        }
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            if let item = model.selectedItem {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.url.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let result = item.result {
                            Text(l.t("dimensions", number(result.width), number(result.height)))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        } else {
                            Text(stateText(item.state))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 6)
                    Button(action: model.revealSource) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(l.t("reveal"))
                    .accessibilityLabel(l.t("reveal"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                ComparisonPreview(inputURL: item.url, outputURL: item.result?.outputURL,
                                  revision: previewRevision(item), l: l, accent: accent)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                if item.state == .failed {
                    Label(l.t(item.errorKey ?? "error.encode"), systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let result = item.result, result.outputBytes > result.originalBytes {
                    Label(l.t("status.larger"), systemImage: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.secondary)
                Text(l.t("preview.empty"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            Divider()
            resultSummary
        }
    }

    private var resultSummary: some View {
        let item = model.selectedItem
        let result = item?.result
        let originalBytes = result?.originalBytes ?? item?.originalBytes
        return HStack(spacing: 0) {
            summaryMetric("original", value: originalBytes.map { AppModel.size($0, locale: l.locale) } ?? "—", color: .primary)
            Rectangle().fill(Color.primary.opacity(0.09)).frame(width: 1, height: 30)
            summaryMetric("compressed", value: result.map { AppModel.size($0.outputBytes, locale: l.locale) } ?? "—", color: .primary)
            Rectangle().fill(Color.primary.opacity(0.09)).frame(width: 1, height: 30)
            summaryMetric("saved", value: result.map { savedText(for: $0) } ?? "—",
                          color: (result.map { $0.outputBytes <= $0.originalBytes } ?? true) ? accent : .orange)
        }
        .padding(.vertical, 12)
        .background(surface.opacity(0.35))
    }

    private func summaryMetric(_ key: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(l.t(key)).font(.system(size: 10.5)).foregroundColor(.secondary).lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private func savedText(for result: CompressionResult) -> String {
        let savedBytes = result.originalBytes - result.outputBytes
        let amount = AppModel.size(savedBytes, locale: l.locale)
        guard result.originalBytes > 0 else { return amount }
        let fraction = Double(savedBytes) / Double(result.originalBytes)
        let percentage = fraction.formatted(.percent.precision(.fractionLength(0)).locale(l.locale))
        return percentage + " · " + amount
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.settingsChanged {
                Label(l.t("status.changed"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else if let noticeKey = model.noticeKey {
                Text(notice(noticeKey))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            HStack(alignment: .top, spacing: 34) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.t("quality")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(number(Int(model.quality.rounded())))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(accent)
                    }
                    Slider(value: Binding(get: { model.quality }, set: { model.quality = $0.rounded() }), in: 1...100)
                        .accessibilityLabel(l.t("quality"))
                        .accessibilityValue(number(Int(model.quality.rounded())))
                    Text(l.t("quality.hint"))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text(l.t("resize"))
                            .font(.system(size: 12, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Picker(l.t("resize"), selection: $model.maxDimension) {
                            Text(l.t("resize.original")).tag(0)
                            ForEach([3840, 2560, 1920, 1280], id: \.self) { dimension in
                                Text(number(dimension)).tag(dimension)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 150, maxWidth: 210)
                    }
                    Toggle(l.t("chroma"), isOn: $model.chroma444)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11.5))
                        .help(l.t("chroma.hint"))
                    Toggle(l.t("metadata.exif"), isOn: $model.preserveEXIF)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11.5))
                        .help(l.t("metadata.hint"))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(model.running)
            Text(l.t("format.note"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 13)
        .background(surface.opacity(0.43))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if model.running {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.t("status.progress", number(model.completed), number(model.items.count)))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 180)
                        .accessibilityLabel(l.t("status.processing"))
                }
            } else if model.importing {
                ProgressView().controlSize(.small)
                Text(l.t("status.importing")).font(.system(size: 11)).foregroundColor(.secondary)
            } else {
                Label(l.t("privacy"), systemImage: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if model.exporting { ProgressView().controlSize(.small) }
            if let outputDirectory = model.outputDirectory {
                Button(action: model.revealOutputFolder) {
                    Label(l.t("output.reveal"), systemImage: "folder")
                }
                .controlSize(.large)
                .help(outputDirectory.path)
            }
            if model.running {
                Button(l.t("cancel"), action: model.cancel)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
            } else {
                Button(action: model.startCompression) {
                    Label(l.t(model.hasResults ? "recompress" : "compress"), systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.items.isEmpty || model.importing || model.exporting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 13)
    }

    private func stateText(_ state: ItemState) -> String {
        switch state {
        case .queued: return l.t("status.queued")
        case .processing: return l.t("status.processing")
        case .done: return l.t("status.done")
        case .failed: return l.t("status.failed")
        }
    }

    private func notice(_ key: String) -> String {
        var value = l.t(key)
        for (index, argument) in model.noticeArgs.enumerated() {
            value = value.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return value
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(l.locale).grouping(.never))
    }

    private func previewRevision(_ item: CompressionItem) -> String {
        "\(item.id)|\(item.result?.outputURL.path ?? "")|\(item.result?.outputBytes ?? 0)|\(item.result?.quality ?? 0)"
    }
}

private struct ComparisonPreview: View {
    let inputURL: URL
    let outputURL: URL?
    let revision: String
    @ObservedObject var l: Localizer
    let accent: Color
    @State private var original: CGImage?
    @State private var compressed: CGImage?
    @State private var isLoading = true
    @State private var divider: CGFloat = 0.5
    @AppStorage("LightJPEG.previewActualPixels") private var actualPixels = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(l.t("preview.mode"))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                Spacer()
                Picker(l.t("preview.mode"), selection: $actualPixels) {
                    Text(l.t("preview.fit")).tag(false)
                    Text(l.t("preview.actual")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.045))
                    if let original = original {
                        if actualPixels {
                            NativePixelComparison(original: original, compressed: compressed, revision: revision,
                                                  originalLabel: l.t("original"), compressedLabel: l.t("compressed"),
                                                  help: previewHint, divider: $divider)
                                .environment(\.layoutDirection, .leftToRight)
                                .accessibilityLabel(previewHint)
                                .accessibilityValue(Double(divider).formatted(.percent.precision(.fractionLength(0)).locale(l.locale)))
                                .accessibilityAdjustableAction { direction in
                                    guard compressed != nil else { return }
                                    switch direction {
                                    case .increment: divider = min(0.98, divider + 0.05)
                                    case .decrement: divider = max(0.02, divider - 0.05)
                                    @unknown default: break
                                    }
                                }
                        } else {
                            let available = CGSize(width: max(1, geometry.size.width - 20), height: max(1, geometry.size.height - 20))
                            let size = fitSize(image: original, available: available)
                            imageCanvas(original: original, size: size)
                                .frame(width: size.width, height: size.height)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    } else if isLoading {
                        VStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(l.t("preview.loading")).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.exclamationmark").font(.system(size: 26))
                            Text(l.t("preview.failed")).font(.system(size: 12))
                        }.foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack(spacing: 5) {
                Image(systemName: actualPixels ? "viewfinder" : compressed == nil ? "info.circle" : "arrow.left.and.right")
                Text(previewHint)
            }
            .font(.system(size: 10.5))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 14)
        }
        .task(id: revision + "|" + String(actualPixels)) {
            isLoading = true
            original = nil
            compressed = nil
            divider = 0.5
            let first = await PreviewLoader.load(inputURL, fullResolution: actualPixels)
            guard !Task.isCancelled else { return }
            let second: CGImage?
            if let outputURL = outputURL {
                second = await PreviewLoader.load(outputURL, fullResolution: actualPixels)
                guard !Task.isCancelled else { return }
            } else { second = nil }
            original = first
            compressed = second
            isLoading = false
        }
    }

    private var previewHint: String {
        if isLoading { return l.t("preview.loading") }
        if original == nil || (outputURL != nil && compressed == nil) { return l.t("preview.failed") }
        if actualPixels { return l.t(compressed == nil ? "preview.actual.original" : "preview.actual.hint") }
        return l.t(compressed == nil ? "preview.pending" : "preview.fit.hint")
    }

    private func imageCanvas(original: CGImage, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            image(original, size: size)
            if let compressed = compressed {
                image(compressed, size: size)
                    .mask {
                        Rectangle()
                            .frame(width: max(0, size.width * (1 - divider)), height: size.height)
                            .position(x: size.width * (1 + divider) / 2, y: size.height / 2)
                    }
                Rectangle()
                    .fill(.white)
                    .frame(width: 1.5, height: size.height)
                    .shadow(color: .black.opacity(0.35), radius: 2)
                    .position(x: size.width * divider, y: size.height / 2)
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 30, height: 36)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                .position(x: size.width * divider, y: size.height / 2)
                label(l.t("original"))
                    .position(x: min(64, size.width * 0.23), y: 20)
                label(l.t("compressed"))
                    .position(x: max(size.width - 64, size.width * 0.77), y: 20)
            } else {
                label(l.t("original"))
                    .position(x: min(64, size.width / 2), y: 20)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        // Photographs and physical splitter coordinates stay unchanged in RTL languages.
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            guard compressed != nil else { return }
            divider = min(0.98, max(0.02, value.location.x / max(size.width, 1)))
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l.t(compressed == nil ? "original" : "preview.drag"))
        .accessibilityValue(compressed == nil ? "" : Double(divider).formatted(.percent.precision(.fractionLength(0)).locale(l.locale)))
        .accessibilityAdjustableAction { direction in
            guard compressed != nil else { return }
            switch direction {
            case .increment: divider = min(0.98, divider + 0.05)
            case .decrement: divider = max(0.02, divider - 0.05)
            @unknown default: break
            }
        }
    }

    private func image(_ cgImage: CGImage, size: CGSize) -> some View {
        Image(decorative: cgImage, scale: 1)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.55), in: Capsule())
            .allowsHitTesting(false)
    }

    private func fitSize(image: CGImage, available: CGSize) -> CGSize {
        let ratio = CGFloat(image.width) / max(CGFloat(image.height), 1)
        if available.width / available.height > ratio {
            return CGSize(width: available.height * ratio, height: available.height)
        }
        return CGSize(width: available.width, height: available.width / ratio)
    }
}

enum PreviewLoader {
    private static let queue = DispatchQueue(label: "local.lightjpeg.preview", qos: .userInitiated)

    static func load(_ url: URL, fullResolution: Bool = false) async -> CGImage? {
        let cancellation = CancellationToken()
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                queue.async {
                    let image: CGImage? = autoreleasepool {
                        guard !cancellation.isCancelled else { return nil }
                        return decode(url, fullResolution: fullResolution, cancelled: { cancellation.isCancelled })
                    }
                    continuation.resume(returning: image)
                }
            }
        }, onCancel: { cancellation.cancel() })
    }

    /// Actual-size mode decodes the source raster; it never enlarges a thumbnail.
    /// Kept internal to allow pixel-dimension and EXIF-orientation regression tests.
    static func decode(_ url: URL, fullResolution: Bool, cancelled: () -> Bool = { false }) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, sourceOptions) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int64Value,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int64Value,
              width > 0, height > 0, width <= 100_000_000 / height, !cancelled() else { return nil }
        if fullResolution {
            let options = [kCGImageSourceShouldCache: true, kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, options), !cancelled() else { return nil }
            let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
            guard orientation > 1 && orientation <= 8 else { return image }
            return applyingOrientation(orientation, to: image)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func applyingOrientation(_ orientation: Int32, to image: CGImage) -> CGImage? {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let swapsAxes = orientation >= 5
        guard let context = CGContext(data: nil, width: swapsAxes ? image.height : image.width,
                                      height: swapsAxes ? image.width : image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let transform: CGAffineTransform
        switch orientation {
        case 2: transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
        case 3: transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case 4: transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case 5: transform = CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: height, ty: width)
        case 6: transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
        case 7: transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case 8: transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        default: transform = .identity
        }
        context.interpolationQuality = .none
        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

}
