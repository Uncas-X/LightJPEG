[← Spis języków](../../README.md) · [Pobierz najnowszą wersję](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG to natywna aplikacja do kompresji obrazów w macOS 13 lub nowszym. Działa całkowicie lokalnie: nie wysyła zdjęć, nie korzysta z internetowych API, nie zawiera reklam ani telemetrii. MozJPEG jest dołączony do aplikacji; uruchomienie nie wymaga Homebrew, Node.js ani Pythona. Pakiet Universal zawiera programy dla procesorów Intel i Apple Silicon.

## Pierwsze kroki

1. Otwórz `LightJPEG.app`. Możesz przenieść aplikację do folderu Aplikacje.
2. Dodaj obrazy albo przeciągnij pliki i foldery do okna. Obsługiwane formaty to JPEG, PNG, HEIC/HEIF, TIFF, WebP i BMP. Przeszukiwane są również podfoldery; powtarzające się ścieżki plików są pomijane.
3. Wybierz jakość — domyślnie 75. Możesz ograniczyć dłuższy bok lub zachować oryginalne wymiary. Małe obrazy nie są powiększane. Tryb 4:4:4 lepiej zachowuje szczegóły kolorowych krawędzi, np. tekstu; domyślny 4:2:0 zwykle daje mniejsze pliki.
4. W razie potrzeby włącz zachowywanie EXIF. Ten jeden przełącznik obejmuje także GPS i jest domyślnie wyłączony.
5. Kliknij „Kompresuj wszystko”, wybierz folder wyjściowy i potwierdź przyciskiem „Kompresuj i zapisz”. Każdy wynik zapisuje się automatycznie po zakończeniu przetwarzania.
6. Wybierz obraz na liście, aby porównać wersje. Przycisk otwarcia folderu wyjściowego prowadzi do zapisanych plików.

Kompresja JPEG jest stratna. 75 to parametr kodera, a nie „75% zachowanej jakości” ani obietnica zmniejszenia pliku o 75%. Mały lub wcześniej zoptymalizowany obraz może zajmować więcej miejsca. Aplikacja pokazuje rzeczywisty wynik, zamiast zastępować go kopią oryginału.

## Automatyczny zapis i anulowanie

Wyniki zawsze mają format JPEG. Do nazwy dodawane jest `_compressed`, a przy kolizji — numer. Oryginały i istniejące pliki nie są nadpisywane. Ponowna kompresja tworzy nowe pliki.

Anulowanie wyboru folderu nie rozpoczyna przetwarzania i nie usuwa poprzednich wyników. Zapisane pliki pozostają na dysku po anulowaniu zadania, wyczyszczeniu listy i zamknięciu aplikacji. Trwające kopiowanie bieżącego wyniku na wolny dysk może się zakończyć, zanim kolejka zostanie zatrzymana.

Jeśli kompresja się udała, ale zapis nie, wynik pozostaje dostępny w bieżącej sesji. Wybierz go i zapisz kopię w innym folderze przez menu Plik, menu kontekstowe pozycji na liście lub `⌘S`. W wersji 1.1.1 usunięto przycisk eksportu z podglądu; do zwykłej pracy wystarcza zapis automatyczny. Niezapisane wyniki tymczasowe odzyskaj przed wyczyszczeniem listy, ponowną kompresją lub wyjściem — mogą wtedy zostać usunięte.

## Porównanie i statystyki

Rozmiar oryginału, rozmiar wyniku, procent oszczędności i liczba zaoszczędzonych bajtów pod podglądem dotyczą **wybranego obrazu**, a nie całej partii. Przed kompresją w polu wyniku pojawia się `—`. Komunikat zakończenia osobno podaje liczbę plików przetworzonych w partii.

- **„Cały obraz” (Fit):** pokazuje cały obraz w oknie.
- **1:1:** używa pełnej rozdzielczości; jeden piksel wyniku odpowiada jednemu fizycznemu pikselowi ekranu, także Retina. Przewijaj kółkiem myszy lub gładzikiem albo przeciągaj obraz, aby go przesuwać. Przeciąganie linii podziału zmienia granicę porównania.

Po zmniejszeniu obrazu skala 1:1 odnosi się do pikseli wyniku, a oryginał jest dopasowany do tego samego obszaru jako odniesienie. Przed kompresją tryb 1:1 pokazuje oryginał.

## EXIF, kolor i ograniczenia

Orientacja jest korygowana na podstawie EXIF, z uwzględnieniem obrotów i odbić. Przezroczyste obszary otrzymują białe tło. Kolory są przeliczane do sRGB, a profil ICC jest osadzany w pliku.

Przy wyłączonym zachowywaniu EXIF usuwane są EXIF i GPS. Po włączeniu pozostają obsługiwane przez ImageIO standardowe pola aparatu EXIF/TIFF oraz GPS, np. parametry zdjęcia, data i współrzędne. GPS nie ma osobnego przełącznika. Orientacja jest ustawiana na 1, a wymiary pikselowe w EXIF aktualizowane po obrocie i zmianie rozmiaru. Dodanie metadanych nie powoduje ponownej stratnej kompresji JPEG.

Nie są kopiowane prywatne pola producenta MakerNote, XMP/IPTC, stare miniatury ani pola położenia obiektów, które po przekształceniu są nieaktualne. Standardowe znaczniki JPEG/ICC pozostają. Opcja nie oznacza zachowania wszystkich pierwotnych metadanych bajt po bajcie.

Przetwarzany jest tylko pierwszy obraz lub kadr. Live Photo, animacje, pomocnicze obrazy HDR i pozostałe strony TIFF nie są zachowywane. Limit partii to 1000 obrazów. Oryginał może mieć najwyżej 100 milionów pikseli, także przy żądaniu pomniejszenia; bok wynikowego JPEG — najwyżej 65 500 pikseli. Pliki odczytuje systemowy ImageIO.

## Języki i skróty

Przy pierwszym uruchomieniu aplikacja korzysta z preferencji językowych macOS. Język można zmienić w prawym górnym rogu; wybór jest zapamiętywany. Dostępnych jest 16 języków:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

Interfejs arabski jest ułożony od prawej do lewej. Zdjęcia i współrzędne porównania nie są odbijane lustrzanie.

| Skrót | Działanie |
|---|---|
| `⌘O` | Dodaj obrazy |
| `⌘Return` | Rozpocznij kompresję i wybierz folder |
| `Esc` | Anuluj bieżące zadanie |
| `⌘S` | Zapisz dodatkową kopię wybranego wyniku |
| `⌘⇧R` | Otwórz folder wyjściowy |
| `⌘Q` | Zakończ |

## Budowanie i testy

Wymagany jest Mac z Xcode i jego narzędziami wiersza poleceń. Aplikacja korzysta z AppKit, SwiftUI, ImageIO i MozJPEG, bez zależności Swift Package Manager. Pobierz źródła i zbuduj aplikację:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

Dołączony `Resources/bin/cjpeg` jest już plikiem Universal. CMake jest potrzebny tylko do ponownego zbudowania kodera. Gdy kodera brakuje, `build.sh` uruchamia jego budowanie automatycznie. Aby zrobić to jawnie:

```sh
bash build-engine.sh
bash build.sh
```

Skrypt używa ustalonej wersji archiwum MozJPEG i sprawdza SHA-256. Jeśli archiwum jest w `vendor/`, nie trzeba go pobierać. Biblioteka JPEG jest połączona z koderem statycznie; SIMD wyłączono w tej przenośnej kompilacji. Podczas pracy jedyne zależności dynamiczne to biblioteki systemowe.

```sh
bash test.sh
```

Natywne testy podglądu wymagają zalogowanej sesji pulpitu macOS. Dla CI bez pulpitu:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Jeżeli system nie może utworzyć próbki HEIC, test wyraźnie informuje o pominięciu tego przypadku. Można przekazać istniejący plik, np. [próbkę libheif](https://github.com/strukturag/libheif/blob/master/examples/example.heic), aby wykonać dodatkową weryfikację:

```sh
LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
# Bez testów interfejsu:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
```

Próbka służy wyłącznie testom; aplikacja jej nie pobiera. `Sources/` zawiera kod aplikacji, `Tests/` testy, `Resources/bin/` koder, a `Resources/Licenses/` licencje. Wynikiem budowania jest `build/LightJPEG.app`.

## Zakres weryfikacji

Raport weryfikacji dokumentuje udane testy orientacji, skalowania, białego tła, sRGB, EXIF/GPS, niezmienności oryginałów, anulowania, automatycznego zapisu, konfliktów nazw, długich nazw Unicode i usuwania plików pośrednich. Dla źródeł JPEG, PNG, TIFF i istniejącego HEIC potwierdzono identyczność całej zakodowanej części JPEG przed dodaniem metadanych i po nim. Sprawdzono też 16 języków, preferencje języka, RTL i natywne porównanie pikseli; testy podglądu obejmują 40 asercji skali i interakcji.

Środowisko testów: Intel iMac, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4. Na rzeczywistym sprzęcie uruchomiono **wyłącznie wersję Intel**. Arm64 zbudowano przez kompilację krzyżową i dołączono do pakietu; w tym środowisku nie testowano urządzenia Apple Silicon. Sprawdzono architektury, zależności systemowe i podpisy. Raport opisuje wizualne kontrole chińskiego, niemieckiego i arabskiego interfejsu 1.1 oraz angielskiego i hindi w 1.0. Nie oznacza to ręcznej kontroli wszystkich ekranów we wszystkich językach na obu architekturach.

Aplikacja ma lokalny podpis ad-hoc, nie podpis Apple Developer ID, i nie została notaryzowana przez Apple. macOS może poprosić o zgodę na otwarcie.

Przykładowy pomiar: [zdjęcie demonstracyjne Picdiet](https://www.picdiet.com/img/photographer.jpg), 984 065 bajtów i 1920 × 1280 pikseli, przy jakości 75 zajęło około 155 KB — około 84% mniej. To wynik jednej próbki, nie gwarantowany współczynnik. Zdjęcie nie jest dołączone do aplikacji.

## Historia zmian

- **1.1.1:** usunięto przycisk eksportu z podglądu; opcjonalny zapis kopii pozostaje w menu, menu kontekstowym i pod `⌘S`. Nazwa aplikacji to `LightJPEG.app`, bez numeru wersji.
- **1.1.0:** wybór folderu przed kompresją i automatyczny zapis; statystyki wybranego obrazu; Fit oraz przesuwany podgląd 1:1 oparty na fizycznych pikselach; jeden przełącznik zachowywania EXIF wraz z GPS.

## Licencje i pochodzenie kodera

Oryginalny kod LightJPEG jest objęty [licencją MIT](../../LICENSE.txt). Komponenty zewnętrzne podlegają [własnym oryginalnym licencjom](../../Resources/Licenses/). Tłumaczenie dokumentacji nie zmienia tekstów prawnych; angielskie informacje o prawach autorskich, warunki i wyłączenia gwarancji pozostają niezmienione.

Aplikacja zawiera [MozJPEG 4.1.5, oficjalny tag `v4.1.5`](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 archiwum źródeł:

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

Pochodzenie opisano w [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Warunki znajdują się w [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md) i [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg).

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG powstał niezależnie z użyciem otwartego MozJPEG; nie skopiowano interfejsu ani spakowanych skryptów witryny Picdiet.
