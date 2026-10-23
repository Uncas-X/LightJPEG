[Alle Sprachen](../../README.md) · [Aktuelle Version herunterladen](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG ist eine native Bildkomprimierung für macOS auf Basis von SwiftUI, AppKit, ImageIO und MozJPEG. Die gesamte Verarbeitung erfolgt auf dem Mac, ohne Uploads, Werbung, Telemetrie oder Online-APIs.

Voraussetzung ist **macOS 13 oder neuer**. Die Universal-App enthält Intel- (`x86_64`) und Apple-Silicon-Binärdateien (`arm64`). Lade die Veröffentlichung herunter, entpacke **LightJPEG.app** und öffne die App oder verschiebe sie in den Programme-Ordner. Der App-Dateiname enthält keine Versionsnummer. Homebrew, Node.js, Python und ein separat installierter Encoder sind nicht erforderlich.

Die App ist **ad hoc signiert**, jedoch weder mit einer Apple Developer ID signiert noch von Apple notarisiert.

## Erste Schritte

1. Füge Bilder über die entsprechende Schaltfläche hinzu, ziehe Dateien ins Fenster oder füge einen Ordner hinzu. Unterstützte Bilder in Unterordnern werden ebenfalls eingelesen.
2. Wähle die Qualität; der Standardwert ist **75**. Optional lässt sich die maximale Bildkante begrenzen. Die Einstellung für die Originalgröße erhält die Pixelmaße. Eine Verkleinerung behält das Seitenverhältnis bei und vergrößert Bilder niemals.
3. Aktiviere bei Bedarf **4:4:4**, um Farbkanten und Text besser zu erhalten. Die Standardeinstellung 4:2:0 ergibt meist kleinere Dateien.
4. Entscheide, ob du **EXIF-Informationen behalten** möchtest. Diese einzelne Option umfasst auch GPS und ist standardmäßig ausgeschaltet.
5. Klicke auf **Alle komprimieren**, wähle einen Ausgabeordner und bestätige mit **Komprimieren und speichern**. Anschließend wird jedes erfolgreiche Ergebnis automatisch gespeichert. Ein zusätzlicher Export ist nicht nötig.
6. Wähle ein Bild für den Vergleich aus. Die Schaltfläche zum Anzeigen des Ausgabeordners öffnet diesen im Finder.

Die Größen und Einsparungen unter der Vorschau beziehen sich auf **das ausgewählte Bild**, nicht auf den gesamten Stapel. Ohne fertiges Ergebnis steht dort `—`. Die Abschlussmeldung nennt dagegen die gespeicherten und fehlgeschlagenen Bilder des gesamten Stapels.

## Speichern, Abbrechen und Fehler

Ergebnisse werden als JPEG mit dem Namenszusatz `_compressed` gespeichert. Vorhandene Dateien und Ordner werden nie überschrieben; bei gleichen Namen wird eine Nummer ergänzt. Originale bleiben unverändert, auch wenn der Quellordner als Ausgabeordner verwendet wird.

Jedes fertige Ergebnis wird sofort gespeichert. Abbrechen, Leeren der Liste oder Beenden der App löscht keine bereits gespeicherten Dateien. Wenn die Ordnerauswahl abgebrochen wird, startet keine Komprimierung und frühere Ergebnisse bleiben erhalten. Eine erneute Komprimierung fragt erneut nach einem Ordner und verwendet neue Namen, ohne ältere Dateien zu verändern.

Schlägt das Speichern fehl, bleibt das komprimierte Ergebnis während der laufenden Sitzung verfügbar. Über den Bildexport im Menü „Ablage“ beziehungsweise im Kontextmenü des Bildes lässt es sich an einem anderen Ort speichern. **Command+S** öffnet dieselbe optionale Aktion. In Version 1.1.1 entfällt die zusätzliche Export-Schaltfläche in der Vorschauleiste.

## Vergleich und echte Bildpixel

- **Ganzes Bild** zeigt das ganze Bild mit einer auf 1.600 Pixel begrenzten Vorschau. Ziehe die Trennlinie, um Original und Ergebnis zu vergleichen.
- **1:1 Pixel** dekodiert die Bilder in voller Auflösung. Ein **Pixel des Ausgabebildes** entspricht einem **physischen Displaypixel**, auch auf Retina-Displays. Die kleine Vorschau wird dafür nicht hochskaliert.
- Mit Mausrad oder Trackpad kannst du scrollen. Ziehe das Bild außerhalb der Trennlinie, um es zu verschieben; die Trennlinie bleibt für den Vergleich verschiebbar.
- Nach einer Größenreduzierung ist das Pixelraster des Ergebnisses maßgeblich. Das Original wird auf dieselben Ausgabeabmessungen ausgerichtet, damit beide Seiten denselben Bereich zeigen; es dient dabei als skalierte Referenz. Vor der Komprimierung verwendet 1:1 die Pixel des Originals.

In einer Oberfläche von rechts nach links bleiben die Bildkoordinaten unverändert. Fotos werden nicht gespiegelt.

## Formate, Qualität und Metadaten

Eingabeformate: **JPEG, PNG, HEIC/HEIF, TIFF, WebP und BMP**, dekodiert durch macOS ImageIO. Die Ausgabe ist immer **JPEG**. Verarbeitet wird nur das erste Bild; Animationen, Live Photos, HDR-Zusatzbilder und weitere Seiten einer TIFF-Datei bleiben nicht erhalten.

JPEG-Komprimierung ist verlustbehaftet. Qualität 75 bedeutet weder „75 % der ursprünglichen Bildqualität“ noch eine garantierte Verkleinerung um 75 %. Kleine oder bereits optimierte Bilder können größer werden; die App zeigt dies an. Gegebenenfalls hilft eine niedrigere Qualität.

Transparente Bereiche erhalten einen weißen Hintergrund. Farben werden nach sRGB konvertiert und ein ICC-Profil wird eingebettet. EXIF-Drehungen und -Spiegelungen werden auf die Bilddaten angewandt. Grenzen: **1.000 Bilder pro Stapel**, **100 Millionen Quellpixel** und **65.500 Pixel je JPEG-Ausgabekante**. Zu große Quellen werden auch dann abgelehnt, wenn eine Verkleinerung eingestellt ist.

**EXIF-Informationen behalten** ist eine einzelne, standardmäßig ausgeschaltete Option:

- Aus: EXIF- und GPS-Metadaten werden entfernt.
- Ein: Unterstützte standardisierte EXIF/TIFF-Kamerafelder und GPS werden gemeinsam übernommen. Die Orientierung wird normalisiert; EXIF-Pixelmaße werden an das Ergebnis angepasst.

Das Einfügen von Metadaten kodiert die JPEG-Bilddaten nicht erneut. Herstellerspezifische MakerNote-Felder, XMP/IPTC-Daten und alte Vorschaubilder werden nicht kopiert. Standardmäßige JPEG/ICC-Farbmarkierungen bleiben in beiden Modi erhalten. Bei aktivierter Option können Standortdaten enthalten sein.

## Sprachen und Tastenkürzel

Beim ersten Start folgt die Sprache den macOS-Einstellungen. Über das Sprachmenü lässt sie sich jederzeit ändern; die Auswahl wird gespeichert:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

Arabisch verwendet eine Anordnung von rechts nach links, ohne die Bildkoordinaten zu ändern.

| Tastenkürzel | Aktion |
| --- | --- |
| Command+O | Bilder hinzufügen |
| Command+Return | Ausgabeordner wählen und Komprimierung starten |
| Escape | Laufende Komprimierung abbrechen |
| Command+S | Ausgewähltes Ergebnis optional woanders speichern |
| Command+Umschalt+R | Ausgabeordner anzeigen |
| Command+Q | Beenden |

## Erstellen und testen

Auf einem Mac mit installiertem Xcode:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

Das Skript erstellt beide Architekturen und `build/LightJPEG.app`, signiert die App ad hoc und prüft die Signaturen. Es verwendet `Resources/bin/cjpeg`. Fehlt der Encoder, wird er neu erstellt; hierfür wird zusätzlich **CMake** benötigt.

Encoder und App ausdrücklich neu erstellen:

```sh
bash build-engine.sh
bash build.sh
```

Das Encoder-Skript prüft den SHA-256-Wert des festgelegten Quellarchivs. Ein fehlendes Archiv wird heruntergeladen; mit vorhandenem Archiv ist der Neuaufbau offline möglich. Die App selbst arbeitet immer offline. Die JPEG-Bibliothek ist statisch eingebunden; SIMD, PNG-Eingabe im Encoder, TurboJPEG-API und gemeinsam genutzte Bibliotheken sind deaktiviert. ImageIO übernimmt die Eingabeformate der App. Homebrew-Bibliotheken werden zur Laufzeit nicht benötigt.

Alle Tests in einer angemeldeten macOS-Desktopsitzung ausführen:

```sh
bash test.sh
```

Die nativen Vorschautests erzeugen ein unsichtbares AppKit-Fenster und benötigen eine Desktopsitzung. Für CI ohne grafische Sitzung:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Kann das System kein HEIC-Testbild erzeugen, lässt sich eine vorhandene Datei verwenden, etwa `example.heic` aus libheif:

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Beide Optionen für CI ohne grafische Sitzung:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Ohne funktionsfähigen HEIC-Systemencoder oder optionale Testdatei wird dieser Fall als übersprungen gemeldet, nicht als erfolgreich geprüft. Das Ursprungsprojekt ist [libheif](https://github.com/strukturag/libheif).

## Dokumentierte Prüfung und Grenzen

Der Prüfbericht vom 23. Oktober 2026 erfasst Komprimierung, automatisches Speichern, Namenskonflikte, Metadaten, Sprachen und Pixelvorschau. Verwendet wurde ein **Intel-iMac mit macOS 15.7.9 und Xcode 26.3 / Swift 6.2.4**. Intel wurde auf echter Hardware ausgeführt. Apple Silicon wurde über Kreuz kompiliert und in die Universal-App aufgenommen, aber **in dieser Umgebung nicht auf ARM-Hardware getestet**. Die Universal-Architekturen, ausschließlich systemeigenen Laufzeitabhängigkeiten und Ad-hoc-Signaturen wurden geprüft.

Die dokumentierten Tests bestanden für alle acht EXIF-Orientierungen, proportionale Verkleinerung ohne Vergrößerung, weißen Transparenzhintergrund, sRGB-Profil, Metadatenoptionen, unveränderte Originale, Abbruch, fehlgeschlagenes Speichern und Exporte ohne Überschreiben. HEIC-Metadaten wurden mit der libheif-Testdatei geprüft. Sprachtests deckten **16 Sprachen × 94 Schlüssel**, Platzhalter, Sprachauswahl und arabisches RTL ab. Die **40 Prüfungen** der nativen Vorschau umfassten vollständiges Dekodieren, 1x- und simulierte Retina-Pixel, Größenabgleich, echte Mausereignisse und Scrollen.

Layouts der Versionen 1.1 wurden auf Chinesisch, Deutsch und Arabisch überprüft, auch bei 940 Punkt Fensterbreite, in beiden Ansichtsmodi und mit Statistik zum ausgewählten Bild. Version 1.0 wurde zusätzlich auf Englisch und Hindi angesehen. Dies ist keine Behauptung, jede Sprache oder Mac-Konfiguration visuell geprüft zu haben.

## Änderungen

**1.1.1:** zusätzliche Export-Schaltfläche in der Vorschau entfernt; optionales Speichern über Menü und Kontextmenü bleibt verfügbar; stabiler App-Dateiname `LightJPEG.app`.

**1.1.0:** Ausgabeordner vor der Komprimierung wählen und Ergebnisse einzeln automatisch speichern; echter physischer Pixelvergleich bei 1:1 mit Verschieben; eine EXIF-Option einschließlich GPS; Statistik zum ausgewählten Bild.

## Lizenz und Herkunft des Encoders

Der originale LightJPEG-Code steht unter der [MIT-Lizenz](../../LICENSE.txt). Für Drittanbieterkomponenten gelten deren eigene Bedingungen. Maßgebliche Originaltexte liegen unter [Resources/Licenses](../../Resources/Licenses), insbesondere [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) und [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Diese Anleitung ersetzt die Originaltexte nicht.

Der mitgelieferte Encoder verwendet unveränderten Quellcode von [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), Commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 des [Quellarchivs](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5):

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG ist eine unabhängige Implementierung auf Basis von MozJPEG.
