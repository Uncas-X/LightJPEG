[All languages](../../README.md) · [Download the latest release](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG is a native macOS image compressor built with SwiftUI, AppKit, ImageIO and MozJPEG. It processes images entirely on your Mac, without uploads, ads, telemetry or online APIs.

Requires **macOS 13 or later**. The Universal app contains Intel (`x86_64`) and Apple Silicon (`arm64`) binaries. To use it, download the release, extract **LightJPEG.app**, and open it or move it to Applications. The app name does not include a version number. No Homebrew, Node.js, Python or separate encoder installation is required.

The distributed app is **ad-hoc signed**, not signed with an Apple Developer ID and not Apple-notarized.

## Getting started

1. Add images with **Add Images**, drag files into the window, or add a folder. Folder imports include supported images in subfolders.
2. Set quality, initially **75**, and optionally limit the maximum dimension. **Keep original size** preserves pixel dimensions; resizing maintains the aspect ratio and never enlarges an image.
3. Optionally enable **Preserve color detail (4:4:4)** for text or colored edges. The default 4:2:0 setting usually makes smaller files.
4. Decide whether to enable **Keep EXIF information**. This single option includes GPS and is off by default.
5. Click **Compress All**, choose an output folder, and confirm with **Compress and Save**. Compression then begins, and each successful image is saved automatically. There is no second required export step.
6. Select an image to inspect it. **Show Output Folder** opens the destination in Finder.

The size and savings figures below the preview describe **the selected image**, not the whole batch. Result figures show `—` until a result exists. The completion message still reports the batch's saved and failed counts.

## Saving, cancellation and failures

Output files are JPEGs with `_compressed` added to the name. Existing files and folders are never overwritten; collisions receive a numbered suffix. Originals remain unchanged, including when the output folder is also the input folder.

Each completed result is saved immediately. Cancelling compression, clearing the queue or quitting does not remove files already saved. Cancelling the folder picker does not start compression or discard earlier results. Compressing again asks for a folder again and preserves previous files under unique names.

If saving fails, the compressed result remains available in the current session. Choose **Export Image** from the File menu or the image's context menu to save it elsewhere. This optional recovery action is also available with **Command+S**. Version 1.1.1 removes the redundant export button from the preview toolbar.

## Comparison and actual pixels

- **Fit to Window** shows the whole image with a preview bounded to 1,600 pixels. Drag the divider to compare the original and compressed result.
- **1:1 Pixels** decodes the full-resolution images. One **output image pixel** occupies one **physical display pixel**, including on Retina displays. It does not enlarge the Fit thumbnail.
- Scroll with a mouse or trackpad, or drag the image away from the divider, to pan. Drag the divider to continue comparing.
- If the output was resized, the output pixel grid defines 1:1. The original is aligned to the output dimensions so both sides show the same region; the original side is a scaled reference in this case. Before compression, 1:1 uses the original's pixels.

The comparison's image coordinates remain unchanged in right-to-left interfaces; photographs are not mirrored.

## Formats, quality and metadata

Inputs: **JPEG, PNG, HEIC/HEIF, TIFF, WebP and BMP**, decoded through macOS ImageIO. Output is always **JPEG**. The app processes the first image frame only; it does not preserve animation, Live Photos, HDR auxiliary images or multipage TIFF content.

JPEG compression is lossy. Quality 75 does not mean “75% of the original quality” or guarantee a 75% reduction. Very small or already optimized images can grow; the app reports that honestly. Try a lower quality if appropriate.

Transparent areas become white. Color is converted to sRGB with an embedded ICC profile, and EXIF rotation/reflection is applied to the image. Limits are **1,000 images per batch**, **100 million source pixels**, and **65,500 pixels per JPEG output dimension**. Oversized sources are rejected even when downscaling is requested.

**Keep EXIF information** is one checkbox, off by default:

- Off: EXIF and GPS metadata are removed.
- On: supported standard EXIF/TIFF camera fields and GPS are retained together. Orientation is normalized and EXIF pixel dimensions are updated to match the output.

Metadata insertion does not re-encode the JPEG image data. Proprietary MakerNote fields, XMP/IPTC data and old thumbnails are not copied. Standard JPEG/ICC color markers remain in either mode. Enabling this option can retain location information.

## Languages and shortcuts

The first launch follows macOS language preferences. The language menu lets you choose and remembers your choice:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

Arabic uses right-to-left layout, while image coordinates stay unchanged.

| Shortcut | Action |
| --- | --- |
| Command+O | Add images |
| Command+Return | Start compression and choose the output folder |
| Escape | Cancel running compression |
| Command+S | Optionally save the selected result to another location |
| Command+Shift+R | Show the output folder |
| Command+Q | Quit |

## Build and test

Build on a Mac with Xcode installed. Run these commands from a terminal:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

`build.sh` builds both architectures, creates `build/LightJPEG.app`, and applies and verifies ad-hoc signatures. It uses the bundled `Resources/bin/cjpeg`. If the encoder is absent, the script rebuilds it; that step also requires **CMake**.

To explicitly rebuild the encoder and then the app:

```sh
bash build-engine.sh
bash build.sh
```

The encoder script checks the fixed source archive's SHA-256. It downloads the archive if absent; an already available archive allows an offline rebuild. Runtime compression always stays offline. The portable encoder links the JPEG library statically, with SIMD, PNG input support, the TurboJPEG API and shared libraries disabled. Apple's ImageIO handles the app's input formats; no Homebrew dynamic libraries are required.

Run all tests in a logged-in macOS desktop session:

```sh
bash test.sh
```

The native preview tests create a hidden AppKit window and need a desktop session. Headless CI can skip that suite:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

If the system cannot create a HEIC test image, supply an existing fixture, such as upstream libheif's `example.heic`:

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Combine the options for headless CI:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Without a usable system HEIC encoder or this optional fixture, the HEIC fixture case reports a skip; it is not counted as a successful HEIC verification. See [libheif](https://github.com/strukturag/libheif) for the upstream project.

## Recorded validation and limitations

The validation record, dated 2026-10-23, covers compression, automatic saving, export collisions, metadata, localization and pixel comparison. The host was an **Intel iMac, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4**. Intel was executed on hardware. Apple Silicon was cross-compiled and included in the Universal app, but **was not tested on ARM hardware in this environment**. Universal architectures, system-only runtime dependencies and ad-hoc signatures were checked.

Recorded tests passed for all eight EXIF orientations, resizing without enlargement, white transparency, sRGB ICC, metadata removal/retention, unchanged originals, cancellation, failed saves and non-overwriting exports. HEIC retention was verified with the libheif fixture. Localization checks covered **16 locales × 94 keys**, placeholders, language resolution and Arabic RTL. Native preview tests passed **40 assertions**, including full-resolution decoding, 1x and simulated Retina pixel drawing, resize alignment, mouse dragging and scrolling.

Runtime layouts in the 1.1 series were reviewed in Chinese, German and Arabic, including a 940-point-wide window, Fit and 1:1 modes, and per-image statistics. Earlier 1.0 checks also covered English and Hindi. This does not claim visual or hardware testing of every language and Mac configuration.

One public demonstration image, `photographer.jpg` from Picdiet, decreased from 984,065 bytes at 1920 × 1280 to approximately 155 KB at quality 75, about 84% smaller. This is a single measurement, not a guaranteed reduction; the photo is not bundled.

## Changes

**1.1.1:** removes the preview's separate export button, keeps optional menu/context-menu saving, and uses the stable application filename `LightJPEG.app`.

**1.1.0:** adds output-folder selection before compression and automatic per-image saving, true physical-pixel 1:1 comparison with panning, a single EXIF option including GPS, and statistics for the selected image.

## License and encoder provenance

Original LightJPEG code uses the [MIT License](../../LICENSE.txt). Third-party components retain their own terms. Read the original legal texts in [Resources/Licenses](../../Resources/Licenses), especially [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) and [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). This guide does not replace those texts.

The bundled encoder uses unmodified [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. The [source archive](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5) has SHA-256:

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG is an independent MozJPEG-based implementation. It does not copy Picdiet's website interface or bundled scripts.
