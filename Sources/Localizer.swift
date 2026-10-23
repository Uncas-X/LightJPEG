import Foundation
import Combine

/// All application copy is bundled locally; selecting a language never needs a network request.
@MainActor
final class Localizer: ObservableObject {
    static let languages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"), ("en", "English"), ("zh-Hant", "繁體中文"),
        ("ja", "日本語"), ("ko", "한국어"), ("fr", "Français"),
        ("de", "Deutsch"), ("es", "Español"), ("it", "Italiano"),
        ("pt-BR", "Português (Brasil)"), ("ru", "Русский"), ("ar", "العربية"),
        ("hi", "हिन्दी"), ("tr", "Türkçe"), ("nl", "Nederlands"), ("pl", "Polski")
    ]
    static let preferenceKey = "LightJPEG.language"

    @Published var selection: String {
        didSet {
            guard oldValue != selection else { return }
            defaults.set(selection, forKey: Self.preferenceKey)
            updateResolvedCode()
        }
    }
    @Published private(set) var resolvedCode: String
    var locale: Locale { Locale(identifier: resolvedCode) }
    var isRTL: Bool { resolvedCode == "ar" }

    private let defaults: UserDefaults
    private let preferredLanguagesOverride: [String]?
    private var localeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, preferredLanguages: [String]? = nil) {
        self.defaults = defaults
        self.preferredLanguagesOverride = preferredLanguages
        let stored = defaults.string(forKey: Self.preferenceKey) ?? "system"
        let choice = stored == "system" || Self.languages.contains(where: { $0.code == stored }) ? stored : "system"
        self.selection = choice
        self.resolvedCode = choice == "system"
            ? Self.resolve(preferredLanguages: preferredLanguages ?? Locale.preferredLanguages) : choice
        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateResolvedCode() }
        }
    }

    deinit {
        if let localeObserver { NotificationCenter.default.removeObserver(localeObserver) }
    }

    private func updateResolvedCode() {
        resolvedCode = selection == "system"
            ? Self.resolve(preferredLanguages: preferredLanguagesOverride ?? Locale.preferredLanguages)
            : (Self.languages.contains(where: { $0.code == selection }) ? selection : "en")
    }

    /// Walk the complete system preference list before falling back to English.
    /// Explicit Chinese script subtags take precedence over region subtags.
    static func resolve(preferredLanguages: [String]) -> String {
        for preference in preferredLanguages {
            let parts = preference.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
            guard let language = parts.first else { continue }
            if language == "zh" {
                if parts.contains("hant") { return "zh-Hant" }
                if parts.contains("hans") { return "zh-Hans" }
                return parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? "zh-Hant" : "zh-Hans"
            }
            if language == "pt" { return "pt-BR" }
            if let supported = languages.first(where: { $0.code.lowercased() == language }) {
                return supported.code
            }
        }
        return "en"
    }

    func t(_ key: String, _ args: String...) -> String {
        format(key, arguments: args)
    }

    func format(_ key: String, arguments: [String]) -> String {
        // Missing keys stay visibly identifiable during development instead of silently using English.
        var value = Self.translations[resolvedCode]?[key] ?? "⟦\(key)⟧"
        for (index, argument) in arguments.enumerated() {
            value = value.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return value
    }

    static let translations: [String: [String: String]] = {
        let englishLines = englishCatalog.split(separator: "\n", omittingEmptySubsequences: false)
        let entries = englishLines.map { line -> (String, String) in
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            precondition(pair.count == 2, "Invalid English localization entry")
            return (String(pair[0]), String(pair[1]))
        }
        precondition(Set(entries.map { $0.0 }).count == entries.count, "Duplicate localization key")
        var result = ["en": Dictionary(uniqueKeysWithValues: entries)]
        for (code, table) in localizedTables {
            let values = table.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            precondition(values.count == entries.count, "Localization count mismatch for \(code): \(values.count) vs \(entries.count)")
            result[code] = Dictionary(uniqueKeysWithValues: zip(entries.map { $0.0 }, values))
        }
        return result
    }()

    /// The build checks both completeness and formatting arguments for every language.
    static func validate() -> [String] {
        var issues: [String] = []
        let expected = Set(translations["en"]!.keys)
        if Set(translations.keys) != Set(languages.map { $0.code }) { issues.append("Language catalog mismatch") }
        for (code, table) in translations {
            if Set(table.keys) != expected { issues.append("Key catalog mismatch: \(code)") }
            for key in expected {
                guard let value = table[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    issues.append("Missing translation: \(code)/\(key)"); continue
                }
                if placeholders(value) != placeholders(translations["en"]![key]!) {
                    issues.append("Placeholder mismatch: \(code)/\(key)")
                }
            }
        }
        return issues.sorted()
    }

    static func placeholders(_ value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: "\\{[0-9]+\\}")
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }.sorted()
    }

    private static let englishCatalog = """
app.name=LightJPEG
app.tagline=Smaller photos. All on your Mac.
language=Language
language.system=Follow System
add=Add Images
clear=Clear All
remove=Remove
queue=Images
queue.count=Images: {0}
empty.title=Make room for more.
empty.subtitle=Drop images here to compress them on your Mac.
empty.formats=JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
privacy=100% offline · Your originals stay untouched
quality=Quality
quality.hint=Higher quality keeps more detail and creates larger files.
resize=Maximum dimension
resize.original=Keep original size
chroma=Preserve color detail (4:4:4)
chroma.hint=Useful for text and colored edges. Files may be larger.
format.note=JPEG output · Transparent areas become white · Metadata follows your settings
compress=Compress All
recompress=Compress Again
cancel=Cancel
export.all=Export All
export.selected=Export Image
export.choose=Choose an export folder
export.success=Exported: {0}. Originals were not changed.
export.partial=Exported {0} images; {1} could not be saved.
original=Original
compressed=Compressed
saved=Space saved
preview=Preview
preview.empty=Select an image to preview
preview.pending=Compress to compare the result
preview.loading=Loading preview…
preview.failed=Preview unavailable
preview.drag=Drag the divider to compare
preview.fit=Fit to Window
preview.actual=1:1 Pixels
status.queued=Ready
status.processing=Compressing…
status.done=Saved
status.failed=Failed
status.progress={0} of {1}
status.importing=Adding images…
status.cancelled=Stopped. Completed images have already been saved.
status.finished=Saved: {0}; failed: {1}.
status.changed=Settings changed. Compress again to apply them.
status.larger=The result is larger. Try a lower quality setting.
status.empty=No supported images were found.
status.limit=Added up to 1,000 images. Add the rest in another batch.
reveal=Show Original in Finder
size.change={0}% smaller
size.increase={0}% larger
dimensions={0} × {1}
error.read=This file could not be read.
error.decode=This image format is unsupported or the file is damaged.
error.large=This image is too large to process safely.
error.encode=Compression failed.
error.encoder=The bundled MozJPEG encoder is missing or could not run.
error.cancelled=Compression cancelled.
error.write=The file could not be saved.
error.title=Something went wrong
ok=OK
about=About LightJPEG
about.description=Local image compression powered by MozJPEG.
about.license=Open Source Licenses
help=Help
help.body=Add images, choose quality and metadata options, then click Compress All and choose an output folder. Each finished image is saved automatically. JPEG compression is lossy; originals are never overwritten. Transparency becomes white. EXIF information, including GPS location, is kept only when Keep EXIF information is enabled. Orientation and dimensions are updated when needed, and displayed color is normalized. Use Fit to Window for the whole image or 1:1 Pixels to inspect detail by scrolling or panning. This app works offline.
quit=Quit LightJPEG
menu.file=File
menu.edit=Edit
menu.window=Window
menu.close=Close Window
menu.minimize=Minimize
menu.zoom=Zoom
menu.undo=Undo
menu.redo=Redo
menu.cut=Cut
menu.copy=Copy
menu.paste=Paste
menu.selectAll=Select All
metadata.exif=Keep EXIF information
metadata.hint=Includes GPS location; orientation and dimensions are updated when needed.
output.folder=Output folder
output.reveal=Show Output Folder
output.choose=Choose a folder to save compressed images
output.start=Compress and Save
status.saved=Saved: {0}; failed: {1}.
error.save=The compressed image could not be saved.
preview.mode=Comparison view
preview.actual.hint=Output pixels at 1:1; the original is aligned to the output size. Drag the image or scroll to pan; drag the divider to compare.
preview.actual.original=Original pixels at 1:1. Drag the image or scroll to pan.
preview.fit.hint=Fit the whole image to the window; drag the divider to compare.
"""

    // Each table follows englishCatalog order. Counts and placeholders are checked above and in tests.
    private static let localizedTables: [String: String] = [
        "zh-Hans": """
轻图 · LightJPEG
照片更小，轻松留在 Mac。
语言
跟随系统
添加图片
全部清空
移除
图片
{0} 张图片
腾出空间，留住更多。
将图片拖到此处，在 Mac 本地压缩。
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
完全离线 · 原图保持不变
画质
画质越高，保留的细节越多，文件也越大。
最长边
保留原始尺寸
保留色彩细节（4:4:4）
适合文字和彩色边缘，文件可能更大。
保存为 JPEG · 透明区域变为白色 · 元数据按设置保留
压缩全部
重新压缩
取消
导出全部
导出图片
选择导出文件夹
已导出 {0} 张图片，原图未改动。
已导出 {0} 张图片；{1} 张无法保存。
原图
压缩后
节省空间
预览
选择图片以预览
压缩后即可对比效果
正在加载预览…
无法预览
拖动分隔线对比
适合窗口（完整图）
1:1 像素
待压缩
正在压缩…
已保存
失败
{0} / {1}
正在添加图片…
已停止，完成的图片已自动保存。
已保存 {0} 张；失败 {1} 张。
设置已更改，请重新压缩以应用。
压缩后的文件更大，请尝试降低画质。
未找到支持的图片。
最多已添加 1,000 张图片，请将其余图片分批处理。
在访达中显示原图
缩小 {0}%
增大 {0}%
{0} × {1}
无法读取此文件。
不支持此图片格式，或文件已损坏。
此图片过大，无法安全处理。
压缩失败。
内置 MozJPEG 编码器缺失或无法运行。
压缩已取消。
无法保存文件。
出现问题
好
关于 LightJPEG
使用 MozJPEG 在本地压缩图片。
开源许可
帮助
添加图片，选择画质与元数据选项，点击“压缩全部”并选择输出文件夹。每张图片压缩完成后会自动保存。JPEG 压缩是有损压缩，原图永远不会被覆盖。透明区域会变为白色。开启“保留 EXIF 信息”后，将同时保留 EXIF 信息和 GPS 位置。图片方向与尺寸会按需更新，显示色彩会统一处理。“适合窗口”显示完整图片，“1:1 像素”可通过滚动或平移查看细节。本应用完全离线运行。
退出 LightJPEG
文件
编辑
窗口
关闭窗口
最小化
缩放
撤销
重做
剪切
拷贝
粘贴
全选
保留 EXIF 信息
包含 GPS 位置；图片方向与尺寸会按需更新。
输出文件夹
显示输出文件夹
选择压缩图片的保存文件夹
压缩并保存
已保存 {0} 张；失败 {1} 张。
无法保存压缩后的图片。
对比视图
按输出像素 1:1 显示；原图对齐输出尺寸。拖动图片或滚动平移，拖动分隔线对比。
按原图像素 1:1 显示。拖动图片或滚动平移。
全图适合窗口；拖动分隔线对比。
""",
        "zh-Hant": """
輕圖 · LightJPEG
相片更小，輕鬆留在 Mac。
語言
跟隨系統
加入圖片
全部清除
移除
圖片
{0} 張圖片
騰出空間，留住更多。
將圖片拖到這裡，在 Mac 本機壓縮。
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
完全離線 · 原圖保持不變
畫質
畫質越高，保留的細節越多，檔案也越大。
最長邊
保留原始尺寸
保留色彩細節（4:4:4）
適合文字和彩色邊緣，檔案可能更大。
儲存為 JPEG · 透明區域變為白色 · 中繼資料依設定保留
全部壓縮
重新壓縮
取消
全部輸出
輸出圖片
選擇輸出檔案夾
已輸出 {0} 張圖片，原圖未更動。
已輸出 {0} 張圖片；{1} 張無法儲存。
原圖
壓縮後
節省空間
預覽
選取圖片以預覽
壓縮後即可比較效果
正在載入預覽…
無法預覽
拖移分隔線以比較
符合視窗（完整圖片）
1:1 像素
待壓縮
正在壓縮…
已儲存
失敗
{0} / {1}
正在加入圖片…
已停止，完成的圖片已自動儲存。
已儲存 {0} 張；失敗 {1} 張。
設定已更改，請重新壓縮以套用。
壓縮後的檔案更大，請嘗試降低畫質。
找不到支援的圖片。
最多已加入 1,000 張圖片，請將其餘圖片分批處理。
在 Finder 中顯示原圖
縮小 {0}%
增大 {0}%
{0} × {1}
無法讀取此檔案。
不支援此圖片格式，或檔案已損毀。
此圖片過大，無法安全處理。
壓縮失敗。
內建 MozJPEG 編碼器遺失或無法執行。
已取消壓縮。
無法儲存檔案。
發生問題
好
關於 LightJPEG
使用 MozJPEG 在本機壓縮圖片。
開放原始碼授權
輔助說明
加入圖片，選擇畫質與中繼資料選項，按一下「全部壓縮」並選擇輸出檔案夾。每張圖片壓縮完成後會自動儲存。JPEG 壓縮是有損壓縮，原圖永遠不會被覆寫。透明區域會變為白色。開啟「保留 EXIF 資訊」後，將同時保留 EXIF 資訊和 GPS 位置。圖片方向與尺寸會視需要更新，顯示色彩會統一處理。「符合視窗」顯示完整圖片，「1:1 像素」可透過捲動或平移查看細節。本應用程式完全離線執行。
結束 LightJPEG
檔案
編輯
視窗
關閉視窗
縮到最小
縮放
還原
重做
剪下
拷貝
貼上
全選
保留 EXIF 資訊
包含 GPS 位置；圖片方向與尺寸會視需要更新。
輸出檔案夾
顯示輸出檔案夾
選擇壓縮圖片的儲存檔案夾
壓縮並儲存
已儲存 {0} 張；失敗 {1} 張。
無法儲存壓縮後的圖片。
比較檢視
以輸出像素 1:1 顯示；原圖對齊輸出尺寸。拖移圖片或捲動以平移，拖移分隔線以比較。
以原圖像素 1:1 顯示。拖移圖片或捲動以平移。
完整圖片符合視窗；拖移分隔線以比較。
""",
        "ja": """
LightJPEG
写真を軽く。すべて Mac の中で。
言語
システムに合わせる
画像を追加
すべてクリア
削除
画像
{0} 枚の画像
空き容量を、もっと。
ここに画像をドロップして、Mac 上で圧縮できます。
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
完全オフライン · 元の画像は変更しません
画質
画質を高くすると細部が保たれますが、ファイルサイズも大きくなります。
長辺の上限
元のサイズを維持
色の細部を保持（4:4:4）
文字や色の境界に適しています。ファイルサイズが大きくなる場合があります。
JPEG で保存 · 透明部分は白色に変換 · メタデータは設定に従って保持
すべて圧縮
再圧縮
キャンセル
すべて書き出す
画像を書き出す
書き出し先のフォルダを選択
{0} 枚の画像を書き出しました。元の画像は変更していません。
{0} 枚の画像を書き出しました。{1} 枚は保存できませんでした。
元の画像
圧縮後
節約した容量
プレビュー
画像を選択してプレビュー
圧縮すると結果を比較できます
プレビューを読み込み中…
プレビューを表示できません
仕切り線をドラッグして比較
全体を表示
1:1 ピクセル
準備完了
圧縮中…
保存済み
失敗
{0} / {1}
画像を追加中…
停止しました。完了した画像は保存済みです。
{0} 枚を保存しました。{1} 枚が失敗しました。
設定が変更されました。適用するには再圧縮してください。
圧縮後のファイルが大きくなりました。画質を下げてみてください。
対応する画像が見つかりませんでした。
上限の 1,000 枚まで追加しました。残りは別のバッチで追加してください。
元の画像を Finder に表示
{0}% 縮小
{0}% 増加
{0} × {1}
このファイルを読み込めませんでした。
対応していない画像形式か、ファイルが破損しています。
画像が大きすぎるため、安全に処理できません。
圧縮に失敗しました。
同梱の MozJPEG エンコーダが見つからないか、実行できませんでした。
圧縮をキャンセルしました。
ファイルを保存できませんでした。
問題が発生しました
OK
LightJPEG について
MozJPEG によるローカル画像圧縮。
オープンソースライセンス
ヘルプ
画像を追加し、画質とメタデータの設定を選び、「すべて圧縮」をクリックして保存先フォルダを選択します。各画像は圧縮が完了すると自動的に保存されます。JPEG は非可逆圧縮です。元の画像は上書きされません。透明部分は白色になります。「EXIF 情報を保持」を有効にすると、GPS 位置情報を含む EXIF 情報が保持されます。画像の向きと寸法は必要に応じて更新され、表示色は統一されます。「全体を表示」では画像全体を、「1:1 ピクセル」ではスクロールやパンで細部を確認できます。このアプリはオフラインで動作します。
LightJPEG を終了
ファイル
編集
ウインドウ
ウインドウを閉じる
しまう
拡大／縮小
取り消す
やり直す
カット
コピー
ペースト
すべてを選択
EXIF 情報を保持
GPS 位置情報を含みます。画像の向きと寸法は必要に応じて更新されます。
保存先フォルダ
保存先フォルダを表示
圧縮した画像の保存先フォルダを選択
圧縮して保存
{0} 枚を保存しました。{1} 枚が失敗しました。
圧縮した画像を保存できませんでした。
比較表示
出力画像のピクセルを 1:1 で表示し、元の画像を出力サイズに合わせます。画像のドラッグやスクロールで移動し、仕切り線のドラッグで比較できます。
元の画像のピクセルを 1:1 で表示します。画像のドラッグやスクロールで移動できます。
画像全体をウインドウに合わせて表示します。仕切り線をドラッグして比較できます。
""",
        "ko": """
LightJPEG
사진은 더 작게. 모든 작업은 Mac 안에서.
언어
시스템 설정 따르기
이미지 추가
모두 지우기
제거
이미지
이미지 {0}개
더 많은 여유 공간을 만드세요.
이미지를 여기에 놓으면 Mac에서 압축합니다.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
완전한 오프라인 작업 · 원본 유지
품질
품질이 높을수록 세부 표현이 잘 유지되지만 파일 크기도 커집니다.
긴 변의 최대 길이
원본 크기 유지
색상 세부 표현 유지(4:4:4)
텍스트와 색상 경계에 유용합니다. 파일 크기가 커질 수 있습니다.
JPEG로 저장 · 투명 영역은 흰색으로 변환 · 메타데이터는 설정에 따라 유지
모두 압축
다시 압축
취소
모두 내보내기
이미지 내보내기
내보낼 폴더 선택
이미지 {0}개를 내보냈습니다. 원본은 변경되지 않았습니다.
이미지 {0}개를 내보냈습니다. {1}개는 저장하지 못했습니다.
원본
압축 후
절약한 공간
미리보기
미리 볼 이미지를 선택하세요
압축 후 결과를 비교할 수 있습니다
미리보기 불러오는 중…
미리보기를 표시할 수 없음
구분선을 드래그하여 비교
전체 이미지 맞춤
1:1 픽셀
준비됨
압축 중…
저장됨
실패
{0} / {1}
이미지 추가 중…
중지했습니다. 완료된 이미지는 이미 저장되었습니다.
{0}개 저장, {1}개 실패.
설정이 변경되었습니다. 적용하려면 다시 압축하세요.
결과 파일이 더 큽니다. 품질을 낮춰 보세요.
지원하는 이미지를 찾을 수 없습니다.
최대 1,000개의 이미지를 추가했습니다. 나머지는 다음 작업에 추가하세요.
Finder에서 원본 보기
{0}% 작아짐
{0}% 커짐
{0} × {1}
이 파일을 읽을 수 없습니다.
지원하지 않는 이미지 형식이거나 파일이 손상되었습니다.
이미지가 너무 커서 안전하게 처리할 수 없습니다.
압축에 실패했습니다.
내장 MozJPEG 인코더가 없거나 실행할 수 없습니다.
압축이 취소되었습니다.
파일을 저장할 수 없습니다.
문제가 발생했습니다
확인
LightJPEG에 관하여
MozJPEG를 사용한 로컬 이미지 압축.
오픈 소스 라이선스
도움말
이미지를 추가하고 품질과 메타데이터 옵션을 선택한 다음 '모두 압축'을 클릭하여 저장 폴더를 선택하세요. 각 이미지는 압축이 완료되면 자동으로 저장됩니다. JPEG 압축은 손실 압축이며 원본 파일은 덮어쓰지 않습니다. 투명 영역은 흰색으로 변환됩니다. EXIF 정보 유지를 켜면 GPS 위치를 포함한 EXIF 정보가 보존됩니다. 이미지 방향과 크기는 필요에 따라 갱신되며 표시 색상은 표준화됩니다. '전체 이미지 맞춤'으로 전체 이미지를 보거나 '1:1 픽셀'에서 스크롤 또는 이동하여 세부 내용을 확인하세요. 이 앱은 오프라인으로 작동합니다.
LightJPEG 종료
파일
편집
윈도우
윈도우 닫기
최소화
확대/축소
실행 취소
실행 복귀
오려두기
복사하기
붙여넣기
모두 선택
EXIF 정보 유지
GPS 위치가 포함됩니다. 이미지 방향과 크기는 필요에 따라 갱신됩니다.
저장 폴더
저장 폴더 보기
압축한 이미지를 저장할 폴더 선택
압축 및 저장
{0}개 저장, {1}개 실패.
압축한 이미지를 저장할 수 없습니다.
비교 보기
출력 픽셀을 1:1로 표시하고 원본은 출력 크기에 맞춥니다. 이미지를 드래그하거나 스크롤하여 이동하고 구분선을 드래그하여 비교하세요.
원본 픽셀을 1:1로 표시합니다. 이미지를 드래그하거나 스크롤하여 이동하세요.
전체 이미지를 화면에 맞춥니다. 구분선을 드래그하여 비교하세요.
""",
        "fr": """
LightJPEG
Des photos plus légères. Tout sur votre Mac.
Langue
Suivre le système
Ajouter des images
Tout effacer
Retirer
Images
Images : {0}
Faites de la place.
Déposez vos images ici pour les compresser sur votre Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
100 % hors ligne · Vos originaux restent intacts
Qualité
Une qualité plus élevée conserve davantage de détails, mais produit des fichiers plus volumineux.
Dimension maximale
Conserver la taille d’origine
Préserver les détails des couleurs (4:4:4)
Utile pour le texte et les contours colorés. Les fichiers peuvent être plus volumineux.
Sortie JPEG · Transparence remplacée par du blanc · Métadonnées selon vos réglages
Tout compresser
Compresser à nouveau
Annuler
Tout exporter
Exporter l’image
Choisir un dossier d’exportation
Images exportées : {0}. Les originaux n’ont pas été modifiés.
{0} images exportées ; {1} n’ont pas pu être enregistrées.
Original
Compressé
Espace économisé
Aperçu
Sélectionnez une image pour l’aperçu
Compressez pour comparer le résultat
Chargement de l’aperçu…
Aperçu indisponible
Faites glisser le séparateur pour comparer
Image entière
Pixels 1:1
Prêt
Compression…
Enregistré
Échec
{0} sur {1}
Ajout des images…
Arrêté. Les images terminées ont déjà été enregistrées.
Enregistrements : {0} ; échecs : {1}.
Les réglages ont changé. Relancez la compression pour les appliquer.
Le résultat est plus volumineux. Essayez une qualité inférieure.
Aucune image compatible n’a été trouvée.
La limite de 1 000 images a été atteinte. Ajoutez les autres dans un nouveau lot.
Afficher l’original dans le Finder
{0} % plus petit
{0} % plus grand
{0} × {1}
Impossible de lire ce fichier.
Ce format d’image n’est pas pris en charge ou le fichier est endommagé.
Cette image est trop grande pour être traitée en toute sécurité.
La compression a échoué.
L’encodeur MozJPEG intégré est absent ou ne peut pas être exécuté.
Compression annulée.
Impossible d’enregistrer le fichier.
Une erreur s’est produite
OK
À propos de LightJPEG
Compression locale d’images avec MozJPEG.
Licences open source
Aide
Ajoutez des images, choisissez la qualité et les options de métadonnées, puis cliquez sur Tout compresser et choisissez un dossier de sortie. Chaque image terminée est enregistrée automatiquement. La compression JPEG est avec perte ; les originaux ne sont jamais écrasés. La transparence devient blanche. Les informations EXIF, y compris la position GPS, sont conservées uniquement si l’option Conserver les informations EXIF est activée. L’orientation et les dimensions sont actualisées si nécessaire, et les couleurs affichées sont normalisées. Utilisez Image entière pour voir toute l’image ou Pixels 1:1 pour examiner les détails en faisant défiler ou déplacer l’image. Cette application fonctionne hors ligne.
Quitter LightJPEG
Fichier
Édition
Fenêtre
Fermer la fenêtre
Placer dans le Dock
Réduire/agrandir
Annuler
Rétablir
Couper
Copier
Coller
Tout sélectionner
Conserver les informations EXIF
Inclut la position GPS ; l’orientation et les dimensions sont actualisées si nécessaire.
Dossier de sortie
Afficher le dossier de sortie
Choisir un dossier pour enregistrer les images compressées
Compresser et enregistrer
Enregistrements : {0} ; échecs : {1}.
Impossible d’enregistrer l’image compressée.
Vue comparative
Pixels de sortie à l’échelle 1:1 ; l’original est aligné sur les dimensions de sortie. Faites glisser l’image ou défiler pour la déplacer, et faites glisser le séparateur pour comparer.
Pixels d’origine à l’échelle 1:1. Faites glisser l’image ou défiler pour la déplacer.
Adapte l’image entière à la fenêtre ; faites glisser le séparateur pour comparer.
""",
        "de": """
LightJPEG
Kleinere Fotos. Alles auf deinem Mac.
Sprache
Systemsprache verwenden
Bilder hinzufügen
Alle entfernen
Entfernen
Bilder
Bilder: {0}
Platz für mehr schaffen.
Ziehe Bilder hierher, um sie auf deinem Mac zu komprimieren.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
Vollständig offline · Deine Originale bleiben unverändert
Qualität
Eine höhere Qualität erhält mehr Details, erzeugt aber größere Dateien.
Maximale Kantenlänge
Originalgröße beibehalten
Farbdetails erhalten (4:4:4)
Hilfreich für Text und farbige Kanten. Die Dateien können größer werden.
JPEG-Ausgabe · Transparente Bereiche werden weiß · Metadaten gemäß Einstellungen
Alle komprimieren
Erneut komprimieren
Abbrechen
Alle exportieren
Bild exportieren
Exportordner auswählen
Exportiert: {0}. Die Originale wurden nicht verändert.
{0} Bilder exportiert; {1} konnten nicht gespeichert werden.
Original
Komprimiert
Gesparter Speicher
Vorschau
Bild für die Vorschau auswählen
Zum Vergleichen zuerst komprimieren
Vorschau wird geladen…
Vorschau nicht verfügbar
Trennlinie zum Vergleichen ziehen
Ganzes Bild
1:1 Pixel
Bereit
Wird komprimiert…
Gespeichert
Fehlgeschlagen
{0} von {1}
Bilder werden hinzugefügt…
Gestoppt. Fertige Bilder wurden bereits gespeichert.
Gespeichert: {0}; fehlgeschlagen: {1}.
Die Einstellungen wurden geändert. Erneut komprimieren, um sie anzuwenden.
Das Ergebnis ist größer. Versuche eine niedrigere Qualität.
Keine unterstützten Bilder gefunden.
Das Limit von 1.000 Bildern wurde erreicht. Füge die übrigen Bilder in einem neuen Durchlauf hinzu.
Original im Finder anzeigen
{0} % kleiner
{0} % größer
{0} × {1}
Diese Datei konnte nicht gelesen werden.
Dieses Bildformat wird nicht unterstützt oder die Datei ist beschädigt.
Dieses Bild ist zu groß, um sicher verarbeitet zu werden.
Die Komprimierung ist fehlgeschlagen.
Der mitgelieferte MozJPEG-Encoder fehlt oder konnte nicht ausgeführt werden.
Komprimierung abgebrochen.
Die Datei konnte nicht gespeichert werden.
Ein Fehler ist aufgetreten
OK
Über LightJPEG
Lokale Bildkomprimierung mit MozJPEG.
Open-Source-Lizenzen
Hilfe
Füge Bilder hinzu, wähle Qualität und Metadatenoptionen, klicke auf Alle komprimieren und wähle einen Ausgabeordner. Jedes fertige Bild wird automatisch gespeichert. Die JPEG-Komprimierung ist verlustbehaftet; Originale werden nie überschrieben. Transparente Bereiche werden weiß. EXIF-Informationen einschließlich GPS-Positionen bleiben nur erhalten, wenn EXIF-Informationen behalten aktiviert ist. Ausrichtung und Abmessungen werden bei Bedarf aktualisiert und dargestellte Farben vereinheitlicht. Ganzes Bild zeigt das vollständige Bild. Unter 1:1 Pixel kannst du durch Scrollen oder Verschieben Details prüfen. Diese App funktioniert offline.
LightJPEG beenden
Ablage
Bearbeiten
Fenster
Fenster schließen
Im Dock ablegen
Zoomen
Widerrufen
Wiederholen
Ausschneiden
Kopieren
Einsetzen
Alles auswählen
EXIF-Informationen behalten
Enthält die GPS-Position; Ausrichtung und Abmessungen werden bei Bedarf aktualisiert.
Ausgabeordner
Ausgabeordner anzeigen
Ordner zum Speichern komprimierter Bilder auswählen
Komprimieren und speichern
Gespeichert: {0}; fehlgeschlagen: {1}.
Das komprimierte Bild konnte nicht gespeichert werden.
Vergleichsansicht
Ausgabepixel im Maßstab 1:1; das Original wird an die Ausgabegröße angepasst. Ziehe das Bild oder scrolle zum Verschieben; ziehe die Trennlinie zum Vergleichen.
Originalpixel im Maßstab 1:1. Ziehe das Bild oder scrolle zum Verschieben.
Passt das ganze Bild ins Fenster ein; ziehe die Trennlinie zum Vergleichen.
""",
        "es": """
LightJPEG
Fotos más ligeras. Todo en tu Mac.
Idioma
Seguir el sistema
Añadir imágenes
Vaciar todo
Quitar
Imágenes
Imágenes: {0}
Haz espacio para más.
Arrastra imágenes aquí para comprimirlas en tu Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
100 % sin conexión · Tus originales permanecen intactos
Calidad
Una calidad más alta conserva más detalles y genera archivos más grandes.
Dimensión máxima
Mantener el tamaño original
Conservar detalles de color (4:4:4)
Útil para texto y bordes de color. Los archivos pueden ser más grandes.
Salida JPEG · La transparencia se vuelve blanca · Metadatos según tus ajustes
Comprimir todo
Comprimir de nuevo
Cancelar
Exportar todo
Exportar imagen
Elegir una carpeta de exportación
Exportadas: {0}. Los originales no se modificaron.
Se exportaron {0} imágenes; no se pudieron guardar {1}.
Original
Comprimida
Espacio ahorrado
Vista previa
Selecciona una imagen para previsualizarla
Comprime para comparar el resultado
Cargando vista previa…
Vista previa no disponible
Arrastra el separador para comparar
Imagen completa
Píxeles 1:1
Lista
Comprimiendo…
Guardada
Error
{0} de {1}
Añadiendo imágenes…
Detenido. Las imágenes completadas ya se han guardado.
Guardadas: {0}; fallidas: {1}.
Los ajustes han cambiado. Vuelve a comprimir para aplicarlos.
El resultado es más grande. Prueba con una calidad inferior.
No se encontraron imágenes compatibles.
Se alcanzó el límite de 1000 imágenes. Añade las restantes en otro lote.
Mostrar original en el Finder
{0} % más pequeña
{0} % más grande
{0} × {1}
No se pudo leer este archivo.
El formato de imagen no es compatible o el archivo está dañado.
Esta imagen es demasiado grande para procesarla de forma segura.
La compresión falló.
El codificador MozJPEG incluido no se encuentra o no pudo ejecutarse.
Compresión cancelada.
No se pudo guardar el archivo.
Se ha producido un error
Aceptar
Acerca de LightJPEG
Compresión local de imágenes con MozJPEG.
Licencias de código abierto
Ayuda
Añade imágenes, elige la calidad y las opciones de metadatos, pulsa Comprimir todo y elige una carpeta de salida. Cada imagen terminada se guarda automáticamente. La compresión JPEG tiene pérdida; los originales nunca se sobrescriben. La transparencia se vuelve blanca. La información EXIF, incluida la ubicación GPS, se conserva solo cuando se activa Conservar información EXIF. La orientación y las dimensiones se actualizan cuando es necesario y el color mostrado se normaliza. Usa Imagen completa para ver toda la imagen o Píxeles 1:1 para examinar los detalles desplazándote por ella. Esta app funciona sin conexión.
Salir de LightJPEG
Archivo
Edición
Ventana
Cerrar ventana
Minimizar
Zoom
Deshacer
Rehacer
Cortar
Copiar
Pegar
Seleccionar todo
Conservar información EXIF
Incluye la ubicación GPS; la orientación y las dimensiones se actualizan cuando es necesario.
Carpeta de salida
Mostrar carpeta de salida
Elegir una carpeta para guardar las imágenes comprimidas
Comprimir y guardar
Guardadas: {0}; fallidas: {1}.
No se pudo guardar la imagen comprimida.
Vista comparativa
Píxeles de salida a escala 1:1; el original se ajusta al tamaño de salida. Arrastra la imagen o desplázate para moverla; arrastra el separador para comparar.
Píxeles originales a escala 1:1. Arrastra la imagen o desplázate para moverla.
Ajusta la imagen completa a la ventana; arrastra el separador para comparar.
""",
        "it": """
LightJPEG
Foto più leggere. Tutto sul tuo Mac.
Lingua
Segui il sistema
Aggiungi immagini
Svuota tutto
Rimuovi
Immagini
Immagini: {0}
Fai spazio a nuove immagini.
Trascina qui le immagini per comprimerle sul tuo Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
100% offline · Gli originali restano intatti
Qualità
Una qualità più alta mantiene più dettagli e produce file più grandi.
Dimensione massima
Mantieni le dimensioni originali
Mantieni i dettagli dei colori (4:4:4)
Utile per testo e bordi colorati. I file potrebbero essere più grandi.
Uscita JPEG · Le aree trasparenti diventano bianche · Metadati secondo le impostazioni
Comprimi tutto
Comprimi di nuovo
Annulla
Esporta tutto
Esporta immagine
Scegli una cartella di esportazione
Esportate: {0}. Gli originali non sono stati modificati.
{0} immagini esportate; impossibile salvarne {1}.
Originale
Compressa
Spazio risparmiato
Anteprima
Seleziona un’immagine per l’anteprima
Comprimi per confrontare il risultato
Caricamento dell’anteprima…
Anteprima non disponibile
Trascina il divisore per confrontare
Immagine intera
Pixel 1:1
Pronta
Compressione…
Salvata
Non riuscita
{0} di {1}
Aggiunta delle immagini…
Operazione interrotta. Le immagini completate sono già state salvate.
Salvate: {0}; non riuscite: {1}.
Le impostazioni sono cambiate. Comprimi di nuovo per applicarle.
Il risultato è più grande. Prova una qualità inferiore.
Nessuna immagine supportata trovata.
Raggiunto il limite di 1.000 immagini. Aggiungi le altre in un nuovo gruppo.
Mostra originale nel Finder
{0}% più piccola
{0}% più grande
{0} × {1}
Impossibile leggere questo file.
Il formato dell’immagine non è supportato o il file è danneggiato.
Questa immagine è troppo grande per essere elaborata in sicurezza.
Compressione non riuscita.
Il codificatore MozJPEG incluso è assente o non può essere eseguito.
Compressione annullata.
Impossibile salvare il file.
Si è verificato un errore
OK
Informazioni su LightJPEG
Compressione locale delle immagini con MozJPEG.
Licenze open source
Aiuto
Aggiungi le immagini, scegli la qualità e le opzioni dei metadati, fai clic su Comprimi tutto e scegli una cartella di destinazione. Ogni immagine completata viene salvata automaticamente. La compressione JPEG comporta una perdita di dati; gli originali non vengono mai sovrascritti. La trasparenza diventa bianca. Le informazioni EXIF, inclusa la posizione GPS, vengono conservate solo se l’opzione Conserva le informazioni EXIF è attivata. L’orientamento e le dimensioni vengono aggiornati quando necessario e i colori visualizzati vengono normalizzati. Usa Immagine intera per vedere tutta l’immagine oppure Pixel 1:1 per esaminare i dettagli scorrendo o spostando l’immagine. L’app funziona offline.
Esci da LightJPEG
File
Modifica
Finestra
Chiudi finestra
Contrai
Ridimensiona
Annulla
Ripristina
Taglia
Copia
Incolla
Seleziona tutto
Conserva le informazioni EXIF
Include la posizione GPS; l’orientamento e le dimensioni vengono aggiornati quando necessario.
Cartella di destinazione
Mostra cartella di destinazione
Scegli una cartella per salvare le immagini compresse
Comprimi e salva
Salvate: {0}; non riuscite: {1}.
Impossibile salvare l’immagine compressa.
Vista di confronto
Pixel di uscita in scala 1:1; l’originale viene adattato alle dimensioni di uscita. Trascina l’immagine o scorri per spostarla; trascina il divisore per confrontare.
Pixel originali in scala 1:1. Trascina l’immagine o scorri per spostarla.
Adatta l’immagine intera alla finestra; trascina il divisore per confrontare.
""",
        "pt-BR": """
LightJPEG
Fotos mais leves. Tudo no seu Mac.
Idioma
Seguir o sistema
Adicionar imagens
Limpar tudo
Remover
Imagens
Imagens: {0}
Abra espaço para mais.
Arraste imagens para cá para comprimi-las no seu Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
100% offline · Seus originais permanecem intactos
Qualidade
Uma qualidade maior preserva mais detalhes e gera arquivos maiores.
Dimensão máxima
Manter o tamanho original
Preservar detalhes de cor (4:4:4)
Útil para textos e bordas coloridas. Os arquivos podem ficar maiores.
Saída JPEG · Áreas transparentes ficam brancas · Metadados conforme os ajustes
Comprimir tudo
Comprimir novamente
Cancelar
Exportar tudo
Exportar imagem
Escolher uma pasta de exportação
Exportadas: {0}. Os originais não foram alterados.
{0} imagens exportadas; não foi possível salvar {1}.
Original
Comprimida
Espaço economizado
Prévia
Selecione uma imagem para visualizar
Comprima para comparar o resultado
Carregando prévia…
Prévia indisponível
Arraste o divisor para comparar
Imagem inteira
Pixels 1:1
Pronta
Comprimindo…
Salva
Falhou
{0} de {1}
Adicionando imagens…
Interrompido. As imagens concluídas já foram salvas.
Salvas: {0}; falhas: {1}.
Os ajustes mudaram. Comprima novamente para aplicá-los.
O resultado ficou maior. Tente uma qualidade menor.
Nenhuma imagem compatível foi encontrada.
O limite de 1.000 imagens foi atingido. Adicione as restantes em outro lote.
Mostrar original no Finder
{0}% menor
{0}% maior
{0} × {1}
Não foi possível ler este arquivo.
O formato de imagem não é compatível ou o arquivo está danificado.
Esta imagem é grande demais para ser processada com segurança.
A compressão falhou.
O codificador MozJPEG incluído está ausente ou não pôde ser executado.
Compressão cancelada.
Não foi possível salvar o arquivo.
Ocorreu um erro
OK
Sobre o LightJPEG
Compressão local de imagens com MozJPEG.
Licenças de código aberto
Ajuda
Adicione imagens, escolha a qualidade e as opções de metadados, clique em Comprimir tudo e escolha uma pasta de saída. Cada imagem concluída é salva automaticamente. A compressão JPEG tem perdas; os originais nunca são sobrescritos. A transparência fica branca. As informações EXIF, incluindo a localização GPS, só são mantidas quando Manter informações EXIF está ativado. A orientação e as dimensões são atualizadas quando necessário e as cores exibidas são normalizadas. Use Imagem inteira para ver toda a imagem ou Pixels 1:1 para inspecionar detalhes rolando ou movendo a imagem. Este app funciona offline.
Encerrar LightJPEG
Arquivo
Editar
Janela
Fechar janela
Minimizar
Zoom
Desfazer
Refazer
Recortar
Copiar
Colar
Selecionar tudo
Manter informações EXIF
Inclui a localização GPS; a orientação e as dimensões são atualizadas quando necessário.
Pasta de saída
Mostrar pasta de saída
Escolher uma pasta para salvar as imagens comprimidas
Comprimir e salvar
Salvas: {0}; falhas: {1}.
Não foi possível salvar a imagem comprimida.
Visualização comparativa
Pixels de saída em escala 1:1; o original é ajustado às dimensões de saída. Arraste a imagem ou role para movê-la; arraste o divisor para comparar.
Pixels originais em escala 1:1. Arraste a imagem ou role para movê-la.
Ajusta a imagem inteira à janela; arraste o divisor para comparar.
""",
        "ru": """
LightJPEG
Меньше размер фото. Всё на вашем Mac.
Язык
Как в системе
Добавить изображения
Очистить всё
Удалить
Изображения
Изображений: {0}
Освободите место для большего.
Перетащите изображения сюда, чтобы сжать их на вашем Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
Полностью офлайн · Оригиналы остаются без изменений
Качество
Высокое качество сохраняет больше деталей, но увеличивает размер файлов.
Максимальная сторона
Сохранить исходный размер
Сохранить цветовые детали (4:4:4)
Полезно для текста и цветных контуров. Размер файлов может увеличиться.
Сохранение в JPEG · Прозрачность заменяется белым · Метаданные согласно настройкам
Сжать всё
Сжать заново
Отменить
Экспортировать всё
Экспортировать изображение
Выберите папку для экспорта
Экспортировано изображений: {0}. Оригиналы не изменены.
Экспортировано изображений: {0}; не удалось сохранить: {1}.
Оригинал
После сжатия
Освобождено места
Просмотр
Выберите изображение для просмотра
Сожмите изображение, чтобы сравнить результат
Загрузка предпросмотра…
Предпросмотр недоступен
Перетащите разделитель для сравнения
Изображение целиком
Пиксели 1:1
Готово к сжатию
Сжатие…
Сохранено
Ошибка
{0} из {1}
Добавление изображений…
Остановлено. Обработанные изображения уже сохранены.
Сохранено: {0}; с ошибками: {1}.
Настройки изменены. Повторите сжатие, чтобы применить их.
Результат больше оригинала. Попробуйте снизить качество.
Поддерживаемые изображения не найдены.
Достигнут предел в 1 000 изображений. Обработайте остальные отдельной партией.
Показать оригинал в Finder
Меньше на {0} %
Больше на {0} %
{0} × {1}
Не удалось прочитать этот файл.
Формат изображения не поддерживается или файл повреждён.
Изображение слишком большое для безопасной обработки.
Не удалось сжать изображение.
Встроенный кодировщик MozJPEG отсутствует или не запускается.
Сжатие отменено.
Не удалось сохранить файл.
Произошла ошибка
ОК
О программе LightJPEG
Локальное сжатие изображений с помощью MozJPEG.
Лицензии открытого ПО
Справка
Добавьте изображения, выберите качество и параметры метаданных, нажмите «Сжать всё» и выберите папку для сохранения. Каждое готовое изображение сохраняется автоматически. JPEG использует сжатие с потерями; оригиналы никогда не перезаписываются. Прозрачность заменяется белым цветом. Данные EXIF, включая координаты GPS, сохраняются только при включении параметра «Сохранять данные EXIF». Ориентация и размеры обновляются при необходимости, а отображаемые цвета приводятся к стандартному виду. Режим «Изображение целиком» показывает весь снимок, а «Пиксели 1:1» позволяет рассмотреть детали с помощью прокрутки или перемещения изображения. Приложение работает офлайн.
Завершить LightJPEG
Файл
Правка
Окно
Закрыть окно
Свернуть
Масштаб
Отменить
Повторить
Вырезать
Скопировать
Вставить
Выбрать всё
Сохранять данные EXIF
Включает координаты GPS; ориентация и размеры обновляются при необходимости.
Папка сохранения
Показать папку сохранения
Выберите папку для сохранения сжатых изображений
Сжать и сохранить
Сохранено: {0}; с ошибками: {1}.
Не удалось сохранить сжатое изображение.
Режим сравнения
Пиксели результата в масштабе 1:1; оригинал подгоняется под размер результата. Перетаскивайте или прокручивайте изображение для перемещения, а разделитель — для сравнения.
Исходные пиксели в масштабе 1:1. Перетаскивайте или прокручивайте изображение для перемещения.
Изображение целиком вписывается в окно; перетаскивайте разделитель для сравнения.
""",
        "ar": """
LightJPEG
صور أصغر حجمًا. كل ذلك على جهاز Mac.
اللغة
اتباع لغة النظام
إضافة صور
مسح الكل
إزالة
الصور
عدد الصور: {0}
وفّر مساحة للمزيد.
أفلت الصور هنا لضغطها على جهاز Mac.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
دون اتصال تمامًا · تبقى الصور الأصلية كما هي
الجودة
تحافظ الجودة الأعلى على تفاصيل أكثر، لكنها تنتج ملفات أكبر.
الحد الأقصى لطول الضلع
الاحتفاظ بالأبعاد الأصلية
الحفاظ على تفاصيل الألوان (4:4:4)
مفيد للنصوص والحواف الملونة. قد تصبح الملفات أكبر.
حفظ بصيغة JPEG · تتحول المناطق الشفافة إلى الأبيض · البيانات الوصفية حسب إعداداتك
ضغط الكل
الضغط مجددًا
إلغاء
تصدير الكل
تصدير الصورة
اختيار مجلد للتصدير
الصور المصدّرة: {0}. لم تتغير الصور الأصلية.
تم تصدير {0} من الصور؛ تعذّر حفظ {1} منها.
الأصلية
بعد الضغط
المساحة الموفّرة
معاينة
اختر صورة لمعاينتها
اضغط الصورة لمقارنة النتيجة
جارٍ تحميل المعاينة…
المعاينة غير متاحة
اسحب الفاصل للمقارنة
الصورة كاملة
بكسلات 1:1
جاهزة
جارٍ الضغط…
تم الحفظ
فشل
{0} من {1}
جارٍ إضافة الصور…
تم الإيقاف. تم حفظ الصور المكتملة بالفعل.
تم الحفظ: {0}؛ فشل: {1}.
تغيّرت الإعدادات. أعد الضغط لتطبيقها.
حجم النتيجة أكبر. جرّب خفض الجودة.
لم يتم العثور على صور مدعومة.
تم بلوغ الحد الأقصى البالغ 1,000 صورة. أضف بقية الصور في دفعة أخرى.
إظهار الأصلية في Finder
أصغر بنسبة {0}٪
أكبر بنسبة {0}٪
{0} × {1}
تعذّرت قراءة هذا الملف.
تنسيق الصورة غير مدعوم أو الملف تالف.
هذه الصورة أكبر من أن تتم معالجتها بأمان.
فشل الضغط.
برنامج ترميز MozJPEG المضمّن مفقود أو تعذّر تشغيله.
تم إلغاء الضغط.
تعذّر حفظ الملف.
حدث خطأ
موافق
حول LightJPEG
ضغط الصور محليًا باستخدام MozJPEG.
تراخيص المصادر المفتوحة
مساعدة
أضف الصور واختر الجودة وخيارات البيانات الوصفية، ثم انقر على «ضغط الكل» واختر مجلد الإخراج. تُحفظ كل صورة تلقائيًا عند اكتمال ضغطها. ضغط JPEG فاقد لبعض التفاصيل؛ لا تُستبدل الصور الأصلية أبدًا. تتحول المناطق الشفافة إلى الأبيض. تُحفظ معلومات EXIF، بما فيها موقع GPS، فقط عند تفعيل «الاحتفاظ بمعلومات EXIF». يُحدّث الاتجاه والأبعاد عند الحاجة، وتُوحّد ألوان العرض. استخدم «الصورة كاملة» لرؤية الصورة بأكملها، أو «بكسلات 1:1» لفحص التفاصيل بالتمرير أو تحريك الصورة. يعمل هذا التطبيق دون اتصال.
إنهاء LightJPEG
ملف
تحرير
نافذة
إغلاق النافذة
تصغير
تكبير/تصغير
تراجع
إعادة
قص
نسخ
لصق
تحديد الكل
الاحتفاظ بمعلومات EXIF
يتضمن موقع GPS؛ يُحدّث الاتجاه والأبعاد عند الحاجة.
مجلد الإخراج
إظهار مجلد الإخراج
اختيار مجلد لحفظ الصور المضغوطة
ضغط وحفظ
تم الحفظ: {0}؛ فشل: {1}.
تعذّر حفظ الصورة المضغوطة.
عرض المقارنة
بكسلات الإخراج بمقياس 1:1؛ تُضبط الصورة الأصلية لتطابق أبعاد الإخراج. اسحب الصورة أو مرّر لتحريكها، واسحب الفاصل للمقارنة.
البكسلات الأصلية بمقياس 1:1. اسحب الصورة أو مرّر لتحريكها.
ملاءمة الصورة كاملة للنافذة؛ اسحب الفاصل للمقارنة.
""",
        "hi": """
LightJPEG
छोटी फ़ोटो। सारा काम आपके Mac पर।
भाषा
सिस्टम की भाषा अपनाएँ
इमेज जोड़ें
सभी हटाएँ
हटाएँ
इमेज
इमेज: {0}
और जगह बनाएँ।
अपने Mac पर इमेज कंप्रेस करने के लिए उन्हें यहाँ छोड़ें।
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
पूरी तरह ऑफ़लाइन · मूल फ़ाइलें अपरिवर्तित रहती हैं
गुणवत्ता
बेहतर गुणवत्ता में अधिक बारीकियाँ सुरक्षित रहती हैं, लेकिन फ़ाइलें बड़ी होती हैं।
सबसे लंबी भुजा की सीमा
मूल माप बनाए रखें
रंगों की बारीकियाँ बनाए रखें (4:4:4)
टेक्स्ट और रंगीन किनारों के लिए उपयोगी। फ़ाइलें बड़ी हो सकती हैं।
JPEG में सहेजें · पारदर्शी हिस्से सफ़ेद होंगे · मेटाडेटा आपकी सेटिंग के अनुसार
सभी कंप्रेस करें
फिर से कंप्रेस करें
रद्द करें
सभी निर्यात करें
इमेज निर्यात करें
निर्यात के लिए फ़ोल्डर चुनें
निर्यात की गई इमेज: {0}। मूल फ़ाइलें नहीं बदली गईं।
{0} इमेज निर्यात की गईं; {1} सहेजी नहीं जा सकीं।
मूल
कंप्रेस की गई
बचाई गई जगह
प्रीव्यू
प्रीव्यू के लिए इमेज चुनें
परिणाम की तुलना करने के लिए कंप्रेस करें
प्रीव्यू लोड हो रहा है…
प्रीव्यू उपलब्ध नहीं है
तुलना करने के लिए विभाजक खींचें
पूरी इमेज
1:1 पिक्सेल
तैयार
कंप्रेस हो रहा है…
सहेजी गई
विफल
{1} में से {0}
इमेज जोड़ी जा रही हैं…
रोक दिया गया। पूरी हो चुकी इमेज पहले ही सहेज दी गई हैं।
सहेजी गईं: {0}; विफल: {1}।
सेटिंग बदल गई हैं। उन्हें लागू करने के लिए फिर से कंप्रेस करें।
परिणाम की फ़ाइल बड़ी है। गुणवत्ता कम करके देखें।
कोई समर्थित इमेज नहीं मिली।
1,000 इमेज की सीमा तक जोड़ दी गई हैं। बाकी इमेज अगले बैच में जोड़ें।
मूल फ़ाइल Finder में दिखाएँ
{0}% छोटा
{0}% बड़ा
{0} × {1}
यह फ़ाइल पढ़ी नहीं जा सकी।
यह इमेज फ़ॉर्मैट समर्थित नहीं है या फ़ाइल खराब है।
यह इमेज सुरक्षित रूप से प्रोसेस करने के लिए बहुत बड़ी है।
कंप्रेशन विफल रहा।
ऐप में शामिल MozJPEG एन्कोडर मौजूद नहीं है या चल नहीं सका।
कंप्रेशन रद्द कर दिया गया।
फ़ाइल सहेजी नहीं जा सकी।
कोई समस्या हुई
ठीक है
LightJPEG के बारे में
MozJPEG के साथ स्थानीय इमेज कंप्रेशन।
ओपन सोर्स लाइसेंस
सहायता
इमेज जोड़ें, गुणवत्ता और मेटाडेटा विकल्प चुनें, फिर 'सभी कंप्रेस करें' पर क्लिक करके आउटपुट फ़ोल्डर चुनें। हर इमेज कंप्रेस होने पर अपने आप सहेज दी जाती है। JPEG कंप्रेशन में कुछ बारीकियाँ खो जाती हैं; मूल फ़ाइलें कभी ओवरराइट नहीं होतीं। पारदर्शी हिस्से सफ़ेद हो जाते हैं। GPS स्थान सहित EXIF जानकारी केवल तभी रखी जाती है जब EXIF जानकारी रखें चालू हो। दिशा और माप ज़रूरत के अनुसार अपडेट होते हैं और दिखाई देने वाले रंग मानकीकृत किए जाते हैं। 'पूरी इमेज' में पूरी तस्वीर देखें या '1:1 पिक्सेल' में स्क्रोल करके या इमेज खिसकाकर बारीकियाँ जाँचें। यह ऐप ऑफ़लाइन काम करता है।
LightJPEG बंद करें
फ़ाइल
संपादन
विंडो
विंडो बंद करें
छोटा करें
ज़ूम
पूर्ववत करें
फिर से करें
काटें
कॉपी करें
पेस्ट करें
सभी चुनें
EXIF जानकारी रखें
इसमें GPS स्थान शामिल है; दिशा और माप ज़रूरत के अनुसार अपडेट होते हैं।
आउटपुट फ़ोल्डर
आउटपुट फ़ोल्डर दिखाएँ
कंप्रेस की गई इमेज सहेजने के लिए फ़ोल्डर चुनें
कंप्रेस करें और सहेजें
सहेजी गईं: {0}; विफल: {1}।
कंप्रेस की गई इमेज सहेजी नहीं जा सकी।
तुलना दृश्य
आउटपुट पिक्सेल 1:1 में दिखते हैं; मूल इमेज आउटपुट के माप से मेल खाती है। इमेज खिसकाने के लिए ड्रैग या स्क्रोल करें और तुलना के लिए विभाजक खींचें।
मूल पिक्सेल 1:1 में दिखते हैं। इमेज खिसकाने के लिए ड्रैग या स्क्रोल करें।
पूरी इमेज विंडो में फ़िट होती है; तुलना के लिए विभाजक खींचें।
""",
        "tr": """
LightJPEG
Daha küçük fotoğraflar. Her şey Mac’inizde.
Dil
Sistem dilini kullan
Görsel Ekle
Tümünü Temizle
Kaldır
Görseller
Görseller: {0}
Daha fazlasına yer açın.
Görselleri Mac’inizde sıkıştırmak için buraya bırakın.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
Tamamen çevrimdışı · Orijinalleriniz değişmeden kalır
Kalite
Daha yüksek kalite, daha fazla ayrıntıyı korur ancak daha büyük dosyalar oluşturur.
En uzun kenar sınırı
Orijinal boyutları koru
Renk ayrıntılarını koru (4:4:4)
Metinler ve renkli kenarlar için kullanışlıdır. Dosyalar daha büyük olabilir.
JPEG çıktısı · Saydam alanlar beyaz olur · Üst veriler ayarlarınıza göre korunur
Tümünü Sıkıştır
Yeniden Sıkıştır
İptal
Tümünü Dışa Aktar
Görseli Dışa Aktar
Dışa aktarma klasörü seçin
Dışa aktarılan: {0}. Orijinaller değiştirilmedi.
{0} görsel dışa aktarıldı; {1} görsel kaydedilemedi.
Orijinal
Sıkıştırılmış
Kazanılan alan
Önizleme
Önizlemek için bir görsel seçin
Sonucu karşılaştırmak için sıkıştırın
Önizleme yükleniyor…
Önizleme kullanılamıyor
Karşılaştırmak için ayırıcıyı sürükleyin
Görüntünün tamamı
1:1 Pikseller
Hazır
Sıkıştırılıyor…
Kaydedildi
Başarısız
{0} / {1}
Görseller ekleniyor…
Durduruldu. Tamamlanan görseller zaten kaydedildi.
Kaydedilen: {0}; başarısız: {1}.
Ayarlar değişti. Uygulamak için yeniden sıkıştırın.
Sonuç daha büyük. Daha düşük bir kalite ayarı deneyin.
Desteklenen görsel bulunamadı.
1.000 görsel sınırına ulaşıldı. Kalanları ayrı bir grupta ekleyin.
Orijinali Finder’da Göster
%{0} daha küçük
%{0} daha büyük
{0} × {1}
Bu dosya okunamadı.
Bu görsel biçimi desteklenmiyor veya dosya bozuk.
Bu görsel güvenle işlenemeyecek kadar büyük.
Sıkıştırma başarısız oldu.
Dahili MozJPEG kodlayıcısı eksik veya çalıştırılamadı.
Sıkıştırma iptal edildi.
Dosya kaydedilemedi.
Bir hata oluştu
Tamam
LightJPEG Hakkında
MozJPEG ile yerel görsel sıkıştırma.
Açık Kaynak Lisansları
Yardım
Görselleri ekleyin, kaliteyi ve üst veri seçeneklerini belirleyin, Tümünü Sıkıştır’a tıklayıp çıktı klasörünü seçin. Her görsel tamamlandığında otomatik olarak kaydedilir. JPEG sıkıştırması kayıplıdır; orijinal dosyaların üzerine asla yazılmaz. Saydam alanlar beyaz olur. GPS konumu dahil EXIF bilgileri, yalnızca EXIF bilgilerini koru seçeneği etkinleştirildiğinde korunur. Yön ve boyutlar gerektiğinde güncellenir, görüntülenen renkler standartlaştırılır. Görüntünün tamamı ile tüm görseli görebilir, 1:1 Pikseller ile kaydırarak veya görseli taşıyarak ayrıntıları inceleyebilirsiniz. Bu uygulama çevrimdışı çalışır.
LightJPEG’den Çık
Dosya
Düzen
Pencere
Pencereyi Kapat
Simge Durumuna Küçült
Büyüt
Geri Al
Yinele
Kes
Kopyala
Yapıştır
Tümünü Seç
EXIF bilgilerini koru
GPS konumunu içerir; yön ve boyutlar gerektiğinde güncellenir.
Çıktı klasörü
Çıktı Klasörünü Göster
Sıkıştırılmış görsellerin kaydedileceği klasörü seçin
Sıkıştır ve Kaydet
Kaydedilen: {0}; başarısız: {1}.
Sıkıştırılmış görsel kaydedilemedi.
Karşılaştırma görünümü
Çıktı pikselleri 1:1 ölçeğinde gösterilir; orijinal, çıktı boyutuna hizalanır. Kaydırmak için görseli sürükleyin veya kaydırma yapın; karşılaştırmak için ayırıcıyı sürükleyin.
Orijinal pikseller 1:1 ölçeğinde gösterilir. Görseli taşımak için sürükleyin veya kaydırma yapın.
Görselin tamamını pencereye sığdırır; karşılaştırmak için ayırıcıyı sürükleyin.
""",
        "nl": """
LightJPEG
Kleinere foto’s. Alles op je Mac.
Taal
Systeemtaal volgen
Afbeeldingen toevoegen
Alles wissen
Verwijderen
Afbeeldingen
Afbeeldingen: {0}
Maak ruimte voor meer.
Sleep afbeeldingen hierheen om ze op je Mac te comprimeren.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
Volledig offline · Je originelen blijven ongewijzigd
Kwaliteit
Een hogere kwaliteit behoudt meer details, maar maakt grotere bestanden.
Maximale afmeting
Oorspronkelijke afmetingen behouden
Kleurdetails behouden (4:4:4)
Handig voor tekst en gekleurde randen. Bestanden kunnen groter worden.
JPEG-uitvoer · Transparante delen worden wit · Metagegevens volgens je instellingen
Alles comprimeren
Opnieuw comprimeren
Annuleren
Alles exporteren
Afbeelding exporteren
Kies een exportmap
Geëxporteerd: {0}. De originelen zijn niet gewijzigd.
{0} afbeeldingen geëxporteerd; {1} konden niet worden bewaard.
Origineel
Gecomprimeerd
Bespaarde ruimte
Voorvertoning
Selecteer een afbeelding voor de voorvertoning
Comprimeer om het resultaat te vergelijken
Voorvertoning laden…
Voorvertoning niet beschikbaar
Sleep de scheidingslijn om te vergelijken
Hele afbeelding
1:1 pixels
Gereed
Comprimeren…
Bewaard
Mislukt
{0} van {1}
Afbeeldingen toevoegen…
Gestopt. Voltooide afbeeldingen zijn al bewaard.
Bewaard: {0}; mislukt: {1}.
De instellingen zijn gewijzigd. Comprimeer opnieuw om ze toe te passen.
Het resultaat is groter. Probeer een lagere kwaliteit.
Geen ondersteunde afbeeldingen gevonden.
De limiet van 1.000 afbeeldingen is bereikt. Voeg de rest in een nieuwe groep toe.
Toon origineel in Finder
{0}% kleiner
{0}% groter
{0} × {1}
Dit bestand kon niet worden gelezen.
Deze afbeeldingsstructuur wordt niet ondersteund of het bestand is beschadigd.
Deze afbeelding is te groot om veilig te verwerken.
Comprimeren is mislukt.
De meegeleverde MozJPEG-encoder ontbreekt of kon niet worden uitgevoerd.
Comprimeren geannuleerd.
Het bestand kon niet worden bewaard.
Er is een fout opgetreden
OK
Over LightJPEG
Lokale beeldcompressie met MozJPEG.
Opensourcelicenties
Help
Voeg afbeeldingen toe, kies de kwaliteit en opties voor metagegevens, klik op Alles comprimeren en kies een uitvoermap. Elke voltooide afbeelding wordt automatisch bewaard. JPEG-compressie geeft kwaliteitsverlies; originelen worden nooit overschreven. Transparante delen worden wit. EXIF-informatie, inclusief de GPS-locatie, blijft alleen behouden als EXIF-informatie behouden is ingeschakeld. De richting en afmetingen worden zo nodig bijgewerkt en weergegeven kleuren worden gestandaardiseerd. Gebruik Hele afbeelding voor het volledige beeld of 1:1 pixels om details te bekijken door te scrollen of de afbeelding te verschuiven. Deze app werkt offline.
Stop LightJPEG
Archief
Wijzig
Venster
Sluit venster
Minimaliseer
Zoom
Herstel
Opnieuw
Knip
Kopieer
Plak
Selecteer alles
EXIF-informatie behouden
Inclusief GPS-locatie; de richting en afmetingen worden zo nodig bijgewerkt.
Uitvoermap
Toon uitvoermap
Kies een map om gecomprimeerde afbeeldingen te bewaren
Comprimeren en bewaren
Bewaard: {0}; mislukt: {1}.
De gecomprimeerde afbeelding kon niet worden bewaard.
Vergelijkingsweergave
Uitvoerpixels op schaal 1:1; het origineel wordt aangepast aan de uitvoergrootte. Sleep de afbeelding of scrol om te verschuiven; sleep de scheidingslijn om te vergelijken.
Oorspronkelijke pixels op schaal 1:1. Sleep de afbeelding of scrol om te verschuiven.
Past de hele afbeelding in het venster; sleep de scheidingslijn om te vergelijken.
""",
        "pl": """
LightJPEG
Mniejsze zdjęcia. Wszystko na Twoim Macu.
Język
Język systemu
Dodaj obrazy
Wyczyść wszystko
Usuń
Obrazy
Liczba obrazów: {0}
Zrób miejsce na więcej.
Upuść tutaj obrazy, aby skompresować je na Macu.
JPEG · PNG · HEIC · TIFF · WebP · BMP → JPEG
Całkowicie offline · Oryginały pozostają bez zmian
Jakość
Wyższa jakość zachowuje więcej szczegółów, ale tworzy większe pliki.
Maksymalna długość boku
Zachowaj oryginalne wymiary
Zachowaj szczegóły kolorów (4:4:4)
Przydatne dla tekstu i kolorowych krawędzi. Pliki mogą być większe.
Zapis JPEG · Przezroczystość zmienia się w biel · Metadane zgodnie z ustawieniami
Kompresuj wszystko
Kompresuj ponownie
Anuluj
Eksportuj wszystko
Eksportuj obraz
Wybierz folder eksportu
Wyeksportowano: {0}. Oryginały nie zostały zmienione.
Wyeksportowano obrazy: {0}; nie udało się zapisać: {1}.
Oryginał
Po kompresji
Oszczędzone miejsce
Podgląd
Wybierz obraz do podglądu
Skompresuj, aby porównać wynik
Wczytywanie podglądu…
Podgląd niedostępny
Przeciągnij linię podziału, aby porównać
Cały obraz
Piksele 1:1
Gotowy
Kompresowanie…
Zapisano
Błąd
{0} z {1}
Dodawanie obrazów…
Zatrzymano. Ukończone obrazy zostały już zapisane.
Zapisano: {0}; niepowodzenia: {1}.
Ustawienia się zmieniły. Skompresuj ponownie, aby je zastosować.
Wynik jest większy. Spróbuj ustawić niższą jakość.
Nie znaleziono obsługiwanych obrazów.
Osiągnięto limit 1000 obrazów. Dodaj pozostałe w kolejnej partii.
Pokaż oryginał w Finderze
O {0}% mniejszy
O {0}% większy
{0} × {1}
Nie udało się odczytać tego pliku.
Format obrazu jest nieobsługiwany lub plik jest uszkodzony.
Ten obraz jest zbyt duży, aby można go było bezpiecznie przetworzyć.
Kompresja nie powiodła się.
Dołączony koder MozJPEG jest niedostępny lub nie można go uruchomić.
Kompresja anulowana.
Nie udało się zapisać pliku.
Wystąpił błąd
OK
LightJPEG — informacje
Lokalna kompresja obrazów przy użyciu MozJPEG.
Licencje otwartego oprogramowania
Pomoc
Dodaj obrazy, wybierz jakość i opcje metadanych, kliknij Kompresuj wszystko, a następnie wybierz folder wyjściowy. Każdy ukończony obraz jest zapisywany automatycznie. Kompresja JPEG jest stratna; oryginały nigdy nie są nadpisywane. Przezroczystość zmienia się w biel. Informacje EXIF, w tym położenie GPS, są zachowywane tylko po włączeniu opcji Zachowaj informacje EXIF. Orientacja i wymiary są aktualizowane w razie potrzeby, a wyświetlane kolory są ujednolicane. Użyj trybu Cały obraz, aby zobaczyć całą fotografię, lub Piksele 1:1, aby sprawdzić szczegóły przez przewijanie lub przesuwanie obrazu. Ta aplikacja działa offline.
Zakończ LightJPEG
Plik
Edycja
Okno
Zamknij okno
Minimalizuj
Skaluj
Cofnij
Przywróć
Wytnij
Kopiuj
Wklej
Zaznacz wszystko
Zachowaj informacje EXIF
Obejmuje położenie GPS; orientacja i wymiary są aktualizowane w razie potrzeby.
Folder wyjściowy
Pokaż folder wyjściowy
Wybierz folder do zapisu skompresowanych obrazów
Kompresuj i zapisz
Zapisano: {0}; niepowodzenia: {1}.
Nie udało się zapisać skompresowanego obrazu.
Widok porównania
Piksele wyniku w skali 1:1; oryginał jest dopasowany do wymiarów wyniku. Przeciągaj lub przewijaj obraz, aby go przesuwać; przeciągaj linię podziału, aby porównywać.
Oryginalne piksele w skali 1:1. Przeciągaj lub przewijaj obraz, aby go przesuwać.
Dopasowuje cały obraz do okna; przeciągaj linię podziału, aby porównywać.
"""
    ]
}
