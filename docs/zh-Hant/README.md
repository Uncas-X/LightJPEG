# LightJPEG 1.1.1

[語言索引](../../README.md) · [下載最新版本](https://github.com/Uncas-X/LightJPEG/releases/latest)

LightJPEG 是原生 macOS 離線圖片壓縮工具，內建 MozJPEG 4.1.5，圖片無須上傳。應用程式檔名為 `LightJPEG.app`，執行時不需安裝其他相依套件。支援 macOS 13 以上版本，Universal 程式同時包含 Intel 與 Apple Silicon 架構。已在 Intel Mac、macOS 15.7.9 上實機驗證；arm64 目前僅完成交叉編譯，尚未實機驗證。發行版本採用 ad hoc 簽署，尚未通過 Apple 公證。

介面與說明文件提供以下語言：简体中文、English、繁體中文、日本語、한국어、Français、Deutsch、Español、Italiano、Português (Brasil)、Русский、العربية、हिन्दी、Türkçe、Nederlands、Polski。介面預設跟隨系統，也可手動切換並記住選擇；阿拉伯語採用由右至左的版面配置。

## 開始使用

1. 按一下「加入圖片」，或拖入圖片、檔案夾。支援 JPEG、PNG、HEIC/HEIF、TIFF、WebP 和 BMP，統一輸出為 JPEG。
2. 選擇畫質、尺寸與色彩選項。預設畫質為 75，保留原始尺寸；可限制最長邊以縮小圖片，不會放大原圖。4:4:4 適合文字和彩色邊緣，但檔案可能變大。JPEG 是有損壓縮，75 是編碼品質參數，不代表保留 75% 畫質，也不保證固定壓縮率。
3. 「保留 EXIF 資訊」預設關閉；開啟後同時保留 GPS 位置，沒有獨立的 GPS 開關。按一下「全部壓縮」，選擇輸出檔案夾，再按「壓縮並儲存」，每張圖片完成後立即自動儲存。取消檔案夾選擇會保留先前結果。

檔名使用原名稱加 `_compressed`，遇到同名檔案時加入唯一編號，不會覆寫原圖或現有檔案。停止壓縮、清除列表或結束應用程式，都不會刪除已儲存的圖片。預覽標題列已移除輸出按鈕；選單和圖片的右鍵選單仍可另存，壓縮成功但自動儲存失敗的結果也可透過此方式重新儲存。大小與節省空間的統計僅對應目前選取的圖片。

## 比較、格式與限制

「符合視窗」顯示完整圖片；「1:1 像素」讀取完整解析度，讓一個輸出像素對應一個螢幕實體像素，正確處理 Retina 縮放。可捲動或拖移圖片以平移，拖移分隔線比較前後效果。若壓縮時縮小了尺寸，原圖會對齊輸出尺寸，比較同一區域。

透明區域會填為白色，色彩轉換為 sRGB 並嵌入 ICC 描述檔，圖片方向會標準化。開啟 EXIF 保留時，儲存標準 Exif、ExifAux、TIFF 和 GPS 欄位，並校正方向與尺寸；寫入中繼資料不會再次進行有損編碼。不保留 MakerNote、XMP/IPTC、舊縮圖、動畫、Live Photo 配對內容或 HDR 輔助資料；多頁或多影格檔案只處理第一個影格。

每批最多 1,000 張圖片，來源圖片最多 100 MP（1 億像素），輸出單邊最多 65,500 像素。壓縮後的檔案可能更大，可嘗試降低畫質。

| 快速鍵 | 操作 |
| --- | --- |
| `⌘O` | 加入圖片 |
| `⌘Return` | 全部壓縮（選擇儲存位置） |
| `Esc` | 取消目前的壓縮 |
| `⌘S` | 將選取的結果另存 |
| `⌘⇧R` | 開啟輸出檔案夾 |
| `⌘Q` | 結束 |

## 建置與驗證

安裝 Xcode 及其命令列工具，在儲存庫根目錄執行：

```sh
bash build.sh
```

產生 `build/LightJPEG.app`。如需重新建置內建編碼器，還需要 CMake：

```sh
bash build-engine.sh
```

編碼器固定使用 MozJPEG `v4.1.5`。儲存庫附有 `vendor/mozjpeg-v4.1.5.tar.gz`，備妥上述建置工具後可離線重新建置；封存檔的 SHA-256 為：

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

完整測試需要已登入的 macOS 桌面工作階段；無桌面環境可略過原生互動測試。`LIGHTJPEG_HEIC_FIXTURE` 可指定現有 HEIC 檔案作為測試素材。

```sh
bash test.sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
LIGHTJPEG_HEIC_FIXTURE=/path/to/sample.heic bash test.sh
```

驗證涵蓋八種圖片方向、縮放、四種格式的中繼資料保留與無二次有損編碼、安全另存、自動儲存、取消及儲存失敗後的復原；本地化驗證 16 × 94 個文案鍵與 33 個語言地區案例；原生像素比較包含 40 項互動斷言，並檢查中文、德文、阿拉伯語介面及雙圖佇列中的單圖統計。

## 版本與授權

- **1.1.1**：移除預覽標題列的輸出按鈕；應用程式名稱不再帶版本號。
- **1.1.0**：加入逐張自動儲存、1:1 像素比較、包含 GPS 的單一 EXIF 開關，以及選取圖片的獨立統計。

LightJPEG 原創程式碼採用 MIT 授權。第三方授權及法律聲明原文保留在 [`Resources/Licenses`](../../Resources/Licenses/)。本專案獨立使用 MozJPEG 實作壓縮。編碼器官方原始碼：[Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5)。
