[← Taaloverzicht](../../README.md) · [Nieuwste versie downloaden](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG is een native app voor het comprimeren van afbeeldingen op macOS 13 en nieuwer. Alles gebeurt lokaal: geen uploads, online API's, advertenties of telemetrie. MozJPEG is ingebouwd; voor gebruik zijn Homebrew, Node.js en Python niet nodig. Het universele pakket bevat programma's voor Intel en Apple Silicon.

## Aan de slag

1. Open `LightJPEG.app`. Je kunt de app naar de map Apps verplaatsen.
2. Voeg afbeeldingen toe of sleep bestanden en mappen naar het venster. JPEG, PNG, HEIC/HEIF, TIFF, WebP en BMP worden ondersteund. Ook submappen worden doorzocht; hetzelfde bestandspad wordt niet dubbel toegevoegd.
3. Kies de kwaliteit; standaard is dit 75. Stel eventueel een maximale lange zijde in of behoud de oorspronkelijke afmetingen. Kleine afbeeldingen worden niet vergroot. 4:4:4 bewaart meer detail langs gekleurde randen, bijvoorbeeld bij tekst; de standaard 4:2:0 levert meestal kleinere bestanden op.
4. Schakel indien gewenst het bewaren van EXIF in. Deze ene optie omvat ook GPS en staat standaard uit.
5. Klik op ‘Alles comprimeren’, kies een uitvoermap en bevestig met ‘Comprimeren en bewaren’. Elke afbeelding wordt automatisch opgeslagen zodra de verwerking klaar is.
6. Selecteer een afbeelding in de lijst om te vergelijken. Via de knop voor de uitvoermap vind je de opgeslagen bestanden.

JPEG-compressie is niet verliesvrij. 75 is een encoderinstelling, geen percentage behouden beeldkwaliteit en geen belofte van 75% ruimtebesparing. Een kleine of eerder geoptimaliseerde afbeelding kan groter worden. De app toont het werkelijke resultaat en vervangt dit niet stilzwijgend door het origineel.

## Automatisch opslaan en annuleren

De uitvoer is altijd JPEG. De bestandsnaam krijgt `_compressed`; bij een bestaande naam wordt een nummer toegevoegd. Originelen en bestaande bestanden worden nooit overschreven. Opnieuw comprimeren maakt nieuwe bestanden.

Annuleren in de mapkeuze start geen verwerking en wist eerdere resultaten niet. Opgeslagen bestanden blijven op schijf staan wanneer je de taak annuleert, de lijst wist of de app afsluit. Een lopende kopie naar een trage schijf kan eerst worden afgemaakt voordat de wachtrij stopt.

Als comprimeren lukt maar opslaan mislukt, blijft het resultaat in de huidige sessie beschikbaar. Selecteer het en sla via het menu Archief, het contextmenu van het lijstitem of `⌘S` een kopie op in een andere map. In 1.1.1 is de exportknop in de voorvertoning verwijderd; normaal gebruik verloopt volledig via automatisch opslaan. Herstel niet-opgeslagen tijdelijke resultaten vóór het wissen van de lijst, opnieuw comprimeren of afsluiten: daarbij kunnen ze verdwijnen.

## Vergelijken en statistieken

De oorspronkelijke grootte, resultaatgrootte, het besparingspercentage en het aantal bespaarde bytes onder de voorvertoning horen bij **de geselecteerde afbeelding**, niet bij de hele batch. Voor een nog niet verwerkte afbeelding staat bij het resultaat `—`. Het voltooiingsbericht vermeldt afzonderlijk hoeveel bestanden in de batch zijn verwerkt.

- **‘Hele afbeelding’ (Fit):** toont de volledige afbeelding in het venster.
- **1:1:** gebruikt de volledige resolutie. Eén pixel van het resultaat komt overeen met één fysieke schermpixel, ook op Retina-schermen. Gebruik het muiswiel of trackpad om te scrollen, of sleep de afbeelding om te verschuiven. Slepen aan de scheidingslijn verplaatst de vergelijkingsgrens.

Na verkleinen is 1:1 gebaseerd op de pixels van het resultaat; het origineel wordt op hetzelfde gebied afgebeeld als referentie. Vóór compressie toont 1:1 het origineel.

## EXIF, kleur en grenzen

De richting wordt gecorrigeerd volgens EXIF, inclusief rotaties en spiegelingen. Transparante delen krijgen een witte achtergrond. Kleuren worden omgezet naar sRGB en krijgen een ingesloten ICC-profiel.

Met EXIF-behoud uit worden EXIF en GPS verwijderd. Met de optie aan blijven de door ImageIO ondersteunde standaardvelden voor EXIF/TIFF-cameragegevens en GPS behouden, zoals opname-instellingen, datum en coördinaten. GPS heeft geen aparte schakelaar. De richting wordt op 1 gezet en EXIF-pixelafmetingen worden bijgewerkt na draaien en verkleinen. Het toevoegen van metadata veroorzaakt geen tweede JPEG-compressie met verlies.

Fabrikantspecifieke MakerNote-gegevens, XMP/IPTC, oude miniaturen en na de bewerking ongeldige velden voor objectposities worden niet overgenomen. Standaard JPEG/ICC-markeringen blijven aanwezig. De optie garandeert dus niet dat alle oorspronkelijke metadata byte voor byte wordt gekopieerd.

Alleen het eerste beeld wordt verwerkt; Live Photo, animatie, aanvullende HDR-beelden en overige TIFF-pagina's worden niet behouden. Een batch bevat maximaal 1.000 afbeeldingen. Een bronafbeelding mag maximaal 100 miljoen pixels hebben, ook als je een verkleinde uitvoer kiest. Een zijde van het JPEG-resultaat mag maximaal 65.500 pixels zijn. Het lezen van formaten gebeurt via ImageIO van macOS.

## Talen en sneltoetsen

Bij de eerste start volgt de app de taalvoorkeuren van macOS. Rechtsboven kun je een andere taal kiezen; deze keuze wordt onthouden. Er zijn 16 talen:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

De Arabische interface loopt van rechts naar links. Foto's en de coördinaten van de vergelijking worden niet gespiegeld.

| Sneltoets | Actie |
|---|---|
| `⌘O` | Afbeeldingen toevoegen |
| `⌘Return` | Compressie starten en uitvoermap kiezen |
| `Esc` | Lopende taak annuleren |
| `⌘S` | Een extra kopie van het geselecteerde resultaat opslaan |
| `⌘⇧R` | Uitvoermap openen |
| `⌘Q` | Afsluiten |

## Bouwen en testen

Je hebt een Mac met Xcode en de bijbehorende commandoregeltools nodig. De app gebruikt AppKit, SwiftUI, ImageIO en MozJPEG zonder Swift Package Manager-afhankelijkheden. Haal de broncode op en bouw de app:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

De meegeleverde `Resources/bin/cjpeg` is al universeel. CMake is alleen nodig om de encoder opnieuw te bouwen. Als de encoder ontbreekt, start `build.sh` die bouwstap automatisch. Expliciet opnieuw bouwen:

```sh
bash build-engine.sh
bash build.sh
```

Het script gebruikt een vastgezette MozJPEG-versie en controleert de SHA-256 van het archief. Met het archief in `vendor/` is downloaden niet nodig. De JPEG-bibliotheek is statisch aan de encoder gekoppeld; SIMD is voor deze draagbare bouw uitgeschakeld. Dynamische afhankelijkheden tijdens gebruik zijn uitsluitend systeembibliotheken.

```sh
bash test.sh
```

De native voorvertoningstests vereisen een ingelogde macOS-desktopsessie. Op een CI-machine zonder desktop:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Kan het systeem geen HEIC-testbestand aanmaken, dan wordt dat onderdeel expliciet als overgeslagen gemeld. Je kunt voor extra controle een bestaand bestand opgeven, bijvoorbeeld het [libheif-voorbeeld](https://github.com/strukturag/libheif/blob/master/examples/example.heic):

```sh
LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
# Zonder interfacetests:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
```

Dit bestand is alleen voor tests; de app downloadt het niet. `Sources/` bevat de appcode, `Tests/` de tests, `Resources/bin/` de encoder en `Resources/Licenses/` de licenties. Het bouwresultaat is `build/LightJPEG.app`.

## Wat is gecontroleerd?

Het validatierapport beschrijft geslaagde tests voor richting, schalen, witte transparantie, sRGB, EXIF/GPS, ongewijzigde originelen, annuleren, automatisch opslaan, naamconflicten, lange Unicode-namen en opruimen van tijdelijke uitvoer. Voor JPEG-, PNG-, TIFF- en bestaande HEIC-bronnen bleef de volledige gecodeerde JPEG-inhoud vóór en na de metadatawijziging byte voor byte gelijk. Ook 16 talen, taalvoorkeuren, RTL en native pixelvergelijking zijn getest; de voorvertoningstests bevatten 40 controles voor schaal en bediening.

Testomgeving: Intel iMac, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4. **Alleen de Intel-versie is op echte hardware uitgevoerd.** Arm64 is via kruiscompilatie gebouwd en opgenomen; in deze omgeving is geen Apple Silicon-machine getest. Architecturen, systeemafhankelijkheden en handtekeningen zijn gecontroleerd. Het rapport vermeldt visuele controles van Chinees, Duits en Arabisch in 1.1, en ook Engels en Hindi in 1.0. Dit is geen claim dat elk scherm in alle talen op beide architecturen handmatig is nagekeken.

De app heeft een lokale ad-hoc-handtekening, geen Apple Developer ID-handtekening, en is niet door Apple genotariseerd. macOS kan om toestemming vragen om de app te openen.

Eén meting: de [Picdiet-demonstratiefoto](https://www.picdiet.com/img/photographer.jpg) van 984.065 bytes en 1920 × 1280 pixels werd met kwaliteit 75 ongeveer 155 KB, zo'n 84% kleiner. Dit is één voorbeeld, geen gegarandeerde verhouding; de foto wordt niet meegeleverd.

## Wijzigingen

- **1.1.1:** exportknop uit de voorvertoning verwijderd. Een extra kopie opslaan blijft mogelijk via menu, contextmenu en `⌘S`. De app heet `LightJPEG.app`, zonder versienummer in de bestandsnaam.
- **1.1.0:** uitvoermap kiezen vóór compressie en automatisch opslaan; statistieken per geselecteerde afbeelding; Fit en fysieke 1:1-pixelweergave met verschuiven; één optie voor EXIF inclusief GPS.

## Licenties en herkomst

De oorspronkelijke LightJPEG-code valt onder [MIT](../../LICENSE.txt). Onderdelen van derden vallen onder [hun eigen originele licenties](../../Resources/Licenses/). Deze vertaling wijzigt de juridische teksten niet; Engelstalige copyrightvermeldingen, voorwaarden en garantiebeperkingen blijven ongewijzigd.

De app bevat [MozJPEG 4.1.5, officiële tag `v4.1.5`](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 van het bronarchief:

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

Zie [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt) voor de herkomst, en [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md) en [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) voor de voorwaarden.

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG is onafhankelijk gebouwd met de opensource-encoder MozJPEG; de interface en gebundelde scripts van Picdiet zijn niet gekopieerd.
