# 轻图 · LightJPEG

**简体中文** · [English](docs/en/README.md) · [繁體中文](docs/zh-Hant/README.md) · [日本語](docs/ja/README.md) · [한국어](docs/ko/README.md) · [Français](docs/fr/README.md) · [Deutsch](docs/de/README.md) · [Español](docs/es/README.md) · [Italiano](docs/it/README.md) · [Português (Brasil)](docs/pt-BR/README.md) · [Русский](docs/ru/README.md) · [العربية](docs/ar/README.md) · [हिन्दी](docs/hi/README.md) · [Türkçe](docs/tr/README.md) · [Nederlands](docs/nl/README.md) · [Polski](docs/pl/README.md)

[下载 App](https://github.com/Uncas-X/LightJPEG/releases/latest/download/LightJPEG-macOS.zip) · [下载文档](https://github.com/Uncas-X/LightJPEG/releases/latest/download/LightJPEG-Documentation.zip) · [发布记录](https://github.com/Uncas-X/LightJPEG/releases)

LightJPEG 是原生 macOS 离线图片压缩工具，内置 MozJPEG 4.1.5，图片无需上传。应用文件名为 `LightJPEG.app`，运行时无需安装其他依赖。支持 macOS 13 及以上，Universal 程序同时包含 Intel 和 Apple Silicon 架构。已在 Intel Mac、macOS 15.7.9 上实机验证；arm64 目前仅完成交叉编译，尚未实机验证。分发包采用 ad hoc 签名，尚未通过 Apple 公证。

界面默认跟随系统语言，也可在右上角切换并记住选择；阿拉伯语采用从右到左布局。

## 开始使用

1. 点击“添加图片”，或拖入图片、文件夹。支持 JPEG、PNG、HEIC/HEIF、TIFF、WebP 和 BMP，输出统一为 JPEG。
2. 选择画质、尺寸和色彩选项。默认画质为 75、保留原尺寸；可限制最长边缩小图片，不会放大原图。4:4:4 适合文字和彩色边缘，但可能增加体积。JPEG 是有损压缩，75 是编码质量参数，不代表保留 75% 画质，也不保证固定压缩率。
3. “保留 EXIF 信息”默认关闭；开启后同时保留 GPS 位置，没有独立 GPS 开关。点击“压缩全部”，选择输出文件夹并点击“压缩并保存”，每张图片完成后立即自动保存。取消文件夹选择会保留上次结果。

文件名使用原名称加 `_compressed`，发生重名时追加唯一编号；不会覆盖原图或已有文件。停止压缩、清空列表或退出应用，都不会删除已保存的图片。预览标题栏已移除导出按钮；菜单和图片右键菜单仍可另存，自动保存失败但压缩成功的结果也可通过这里恢复保存。查看大小与节省空间时，统计仅对应当前选中的图片。

## 对比、格式与限制

“适合窗口”显示完整图片；“1:1 像素”读取完整分辨率，让一个输出像素对应一个屏幕物理像素，正确处理 Retina 缩放。可滚动或拖动图片平移，拖动分隔线比较前后效果。如果压缩时缩小了尺寸，原图会对齐输出尺寸进行同一区域对比。

透明区域铺为白色，颜色转换为 sRGB 并嵌入 ICC 配置，图片方向归一化。开启 EXIF 保留时，保存标准 Exif、ExifAux、TIFF 和 GPS 字段，并校正方向与尺寸；写入元数据不会再次进行有损编码。不保留 MakerNote、XMP/IPTC、旧缩略图、动画、Live Photo 配对内容或 HDR 辅助数据；多页或多帧文件只处理第一帧。

每批最多 1,000 张图片，源图最多 100 MP（1 亿像素），输出单边最多 65,500 像素。压缩结果可能比原文件更大，可尝试降低画质。

| 快捷键 | 操作 |
| --- | --- |
| `⌘O` | 添加图片 |
| `⌘Return` | 压缩全部（选择保存位置） |
| `Esc` | 取消当前压缩 |
| `⌘S` | 将所选结果另存 |
| `⌘⇧R` | 打开输出文件夹 |
| `⌘Q` | 退出 |

## 构建与验证

安装 Xcode 及其命令行工具，在仓库根目录运行：

```sh
bash build.sh
```

生成 `build/LightJPEG.app`。如需重建内置编码器，还需 CMake：

```sh
bash build-engine.sh
```

编码器固定使用 MozJPEG `v4.1.5`。仓库附带 `vendor/mozjpeg-v4.1.5.tar.gz`，具备上述构建工具后可离线重建；归档 SHA-256 为：

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

完整测试需要已登录的 macOS 桌面会话；无桌面环境可跳过原生交互测试。`LIGHTJPEG_HEIC_FIXTURE` 可指定已有 HEIC 文件作为测试素材。

```sh
bash test.sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
LIGHTJPEG_HEIC_FIXTURE=/path/to/sample.heic bash test.sh
```

验证覆盖八种图片方向、缩放、四种格式的元数据保留与无二次有损编码、安全另存、自动保存、取消和保存失败后的恢复；本地化验证覆盖文案、语言地区匹配与界面方向；原生像素对比包含 40 项交互断言，并检查中文、德文、阿拉伯语界面及双图队列中的单图统计。

## 版本与许可

- **1.1.1**：移除预览标题栏的导出按钮；应用名称不再带版本号。
- **1.1.0**：加入逐张自动保存、1:1 像素对比、包含 GPS 的单一 EXIF 开关，以及所选图片的独立统计。

LightJPEG 原创代码采用 MIT 许可证。第三方许可证及法律声明原文保留在 [`Resources/Licenses`](Resources/Licenses/)。本项目使用 MozJPEG 实现压缩。编码器官方源码：[Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5)。
