[← Dil dizini](../../README.md) · [Son sürümü indir](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG, macOS 13 ve üzeri için yerel bir görüntü sıkıştırma uygulamasıdır. Tamamen çevrimdışı çalışır; görüntü yüklemez, çevrimiçi API kullanmaz, reklam veya telemetri içermez. MozJPEG uygulamaya dahildir; çalıştırmak için Homebrew, Node.js ya da Python gerekmez. Universal paket hem Intel hem Apple Silicon programlarını içerir.

## Kullanım

1. `LightJPEG.app` dosyasını açın. İsterseniz Uygulamalar klasörüne taşıyın.
2. Görüntü ekleyin veya dosya ve klasörleri pencereye sürükleyin. JPEG, PNG, HEIC/HEIF, TIFF, WebP ve BMP desteklenir. Alt klasörler taranır; aynı dosya yolu birden fazla kez eklenmez.
3. Kaliteyi seçin; varsayılan değer 75'tir. En uzun kenarı sınırlayabilir veya özgün boyutları koruyabilirsiniz. Küçük görüntüler büyütülmez. 4:4:4, yazı gibi renkli kenarlardaki ayrıntıyı daha iyi korur; varsayılan 4:2:0 genellikle daha küçük dosyalar üretir.
4. Gerekirse EXIF bilgilerini korumayı açın. Bu tek seçenek GPS'i de kapsar ve varsayılan olarak kapalıdır.
5. “Tümünü Sıkıştır” düğmesine basın, çıktı klasörünü seçin ve “Sıkıştır ve Kaydet” ile onaylayın. Her görüntü tamamlandığında otomatik olarak kaydedilir.
6. Karşılaştırmak için listedeki bir görüntüyü seçin. Çıktı klasörünü açma düğmesiyle kaydedilen dosyalara ulaşabilirsiniz.

JPEG sıkıştırması kayıplıdır. 75, kodlayıcının kalite ayarıdır; görüntü kalitesinin %75'ini koruma veya dosyayı %75 küçültme sözü değildir. Küçük ya da önceden sıkıştırılmış dosyalar büyüyebilir. Uygulama bu sonucu açıkça gösterir; sonucu özgün dosyayla değiştirmez.

## Otomatik kaydetme ve iptal

Çıktılar her zaman JPEG'dir. Dosya adına `_compressed` eklenir; aynı ad varsa numaralı yeni bir ad kullanılır. Özgün dosyaların ve mevcut çıktıların üzerine yazılmaz. Yeniden sıkıştırma da yeni dosyalar oluşturur.

Klasör seçimini iptal etmek işlemi başlatmaz ve önceki sonuçları silmez. Kaydedilmiş dosyalar görevi iptal ettiğinizde, listeyi temizlediğinizde veya uygulamadan çıktığınızda diskte kalır. Yavaş bir diske devam eden kopyalama, sıra durmadan önce mevcut dosya için tamamlanabilir.

Sıkıştırma başarılı olup kaydetme başarısız olursa sonuç geçerli oturumda korunur. Görüntüyü seçip Dosya menüsünden, liste öğesinin bağlam menüsünden veya `⌘S` ile başka bir klasöre kopya kaydedebilirsiniz. 1.1.1'de önizlemedeki dışa aktarma düğmesi kaldırılmıştır; normal kullanımda otomatik kaydetme yeterlidir. Henüz kurtarılmamış geçici sonuçlar liste temizlendiğinde, yeniden sıkıştırmada veya çıkışta silinebilir.

## Karşılaştırma ve tek görüntü istatistikleri

Önizlemenin altındaki özgün boyut, sonuç boyutu, tasarruf yüzdesi ve bayt miktarı **seçili görüntüye** aittir; toplu işlem toplamı değildir. Henüz sıkıştırılmamış görüntünün sonuç alanında `—` görünür. Tamamlanma bildirimi ayrıca toplu işlemdeki dosya sayısını gösterir.

- **“Görüntünün tamamı” (Fit):** görüntünün tamamını gösterir.
- **1:1:** tam çözünürlüklü veriyi kullanır; bir çıktı pikseli ekrandaki bir fiziksel piksele karşılık gelir. Retina ekranlarda da ölçek buna göre hesaplanır. Fare tekerleği veya izleme dörtgeniyle kaydırın ya da görüntüyü sürükleyerek gezinin. Ayırıcı çizgiyi sürüklemek karşılaştırma sınırını değiştirir.

Boyut küçültüldüğünde 1:1 ölçeği sonuç görüntüsünü temel alır; özgün görüntü karşılaştırma için aynı alana eşlenir. Sıkıştırmadan önce 1:1, özgün görüntüyü gösterir.

## EXIF, renk ve sınırlar

EXIF döndürme ve yansıtma bilgilerine göre yön düzeltilir. Saydam alanlar beyazla doldurulur; renkler sRGB'ye dönüştürülür ve ICC profili eklenir.

EXIF koruma kapalıyken EXIF ve GPS kaldırılır. Açıkken ImageIO'nun desteklediği standart EXIF/TIFF kamera alanları ve GPS birlikte korunur; çekim ayarları, tarih ve koordinatlar buna dahildir. GPS için ayrı bir seçenek yoktur. Yön değeri 1 yapılır; EXIF piksel boyutları döndürme ve küçültme sonrası çıktı boyutlarıyla güncellenir. Meta veri eklemek JPEG'i ikinci kez kayıplı olarak sıkıştırmaz.

Üreticiye özel MakerNote alanları, XMP/IPTC, eski küçük resimler ve dönüştürme sonrası geçersiz kalan nesne konumu alanları taşınmaz. Standart JPEG/ICC işaretleri korunur. Bu seçenek, bütün özgün meta verilerin bayt bayt kopyalanacağı anlamına gelmez.

Yalnızca ilk görüntü karesi işlenir; Live Photo, animasyon, yardımcı HDR görüntüleri ve çok sayfalı TIFF'in diğer sayfaları korunmaz. Bir sırada en fazla 1.000 görüntü bulunabilir. Özgün görüntü, küçültme istense bile en fazla 100 milyon piksel olabilir. JPEG çıktısının tek kenarı en fazla 65.500 pikseldir. Dosyalar sistemin ImageIO bileşeniyle okunur.

## Diller ve kısayollar

İlk açılışta macOS dil tercihleri izlenir. Sağ üstteki seçimle dili değiştirebilirsiniz; tercihiniz hatırlanır. Kullanılabilir diller:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

Arapça arayüz sağdan sola yerleşir; fotoğraflar ve karşılaştırma koordinatları ters çevrilmez.

| Kısayol | İşlem |
|---|---|
| `⌘O` | Görüntü ekle |
| `⌘Return` | Sıkıştırmayı başlat ve çıktı klasörünü seç |
| `Esc` | Çalışan görevi iptal et |
| `⌘S` | Seçili sonucun başka bir kopyasını kaydet |
| `⌘⇧R` | Çıktı klasörünü aç |
| `⌘Q` | Çık |

## Derleme ve testler

Xcode ve komut satırı araçlarının kurulu olduğu bir Mac gerekir. Uygulama AppKit, SwiftUI, ImageIO ve MozJPEG kullanır; Swift Package Manager bağımlılığı yoktur. Kaynak kodu alıp derleyin:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

Paket içindeki `Resources/bin/cjpeg` zaten Universal biçimindedir. CMake yalnızca kodlayıcıyı yeniden derlemek için gerekir; kodlayıcı yoksa `build.sh` bu derlemeyi otomatik başlatır. Açıkça yeniden derlemek için:

```sh
bash build-engine.sh
bash build.sh
```

Betik sabit MozJPEG sürümünün arşivini kullanır ve SHA-256 değerini doğrular. Arşiv `vendor/` altında varsa indirme gerekmez. JPEG kütüphanesi kodlayıcıya statik bağlanmıştır; bu taşınabilir derlemede SIMD kapalıdır. Çalışma anındaki dinamik bağımlılıklar yalnızca sistem kütüphaneleridir.

```sh
bash test.sh
```

Yerel önizleme testleri, oturum açılmış bir macOS masaüstü gerektirir. Masaüstü olmayan CI ortamında:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Sistem HEIC test görüntüsü oluşturamıyorsa ilgili durum açık bir mesajla atlanır. Ek doğrulama için mevcut bir HEIC, örneğin [libheif örneği](https://github.com/strukturag/libheif/blob/master/examples/example.heic), verilebilir:

```sh
LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
# Arayüz testleri olmadan:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE="/absolute/path/example.heic" bash test.sh
```

Örnek dosya yalnızca test içindir; uygulama bunu indirmez. `Sources/` uygulama kodunu, `Tests/` testleri, `Resources/bin/` kodlayıcıyı, `Resources/Licenses/` lisansları içerir. Derleme sonucu `build/LightJPEG.app` olur.

## Doğrulama kapsamı

Doğrulama raporu, yön, boyutlandırma, beyaz arka plan, sRGB, EXIF/GPS, özgün dosyanın değişmemesi, iptal, otomatik kaydetme, ad çakışmaları, uzun Unicode adları ve ara dosya temizliği testlerinin geçtiğini kaydeder. JPEG, PNG, TIFF ve mevcut HEIC kaynaklarında meta veri eklenmeden önce ve sonra JPEG'in kodlanmış gövdesi bayt bayt aynı bulunmuştur. 16 dil, dil tercihleri ve RTL ile yerel piksel karşılaştırması da test edilmiştir; önizleme testlerinde ölçek ve etkileşim için 40 doğrulama bulunur.

Test ortamı Intel iMac, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4'tür. Gerçek donanımda **yalnızca Intel sürümü çalıştırılmıştır**. Arm64 çapraz derlenip pakete alınmıştır; bu ortamda Apple Silicon cihaz testi yapılmamıştır. Mimari, sistem bağımlılığı ve imza kontrolleri yapılmıştır. Raporda 1.1 için Çince, Almanca ve Arapça arayüz incelemeleri; 1.0 için ayrıca İngilizce ve Hintçe incelemeleri vardır. Bu, bütün ekranların her dilde ve iki mimaride elle kontrol edildiği anlamına gelmez.

Uygulama yerel ad-hoc imzalıdır; Apple Developer ID ile imzalanmamış ve Apple noter onayına gönderilmemiştir. macOS açmak için izin isteyebilir.

## Değişiklikler

- **1.1.1:** önizleme dışa aktarma düğmesi kaldırıldı; isteğe bağlı kopya kaydetme menüde, bağlam menüsünde ve `⌘S` kısayolunda kaldı. Uygulama adı sürüm numarası olmadan `LightJPEG.app` oldu.
- **1.1.0:** sıkıştırmadan önce klasör seçimi ve otomatik kaydetme; seçili görüntünün istatistikleri; Fit ve kaydırılabilir fiziksel piksel 1:1 görünümü; EXIF ile GPS'i birlikte koruyan tek seçenek.

## Lisanslar ve kodlayıcının kaynağı

LightJPEG'in özgün kaynak kodu [MIT lisansı](../../LICENSE.txt) altındadır. Üçüncü taraf bileşenler [kendi özgün lisanslarına](../../Resources/Licenses/) tabidir. Bu belgenin çevirisi hukuki metinleri değiştirmez; İngilizce telif bildirimleri, koşullar ve garanti reddi metinleri aynen korunur.

Uygulama [MozJPEG 4.1.5, resmî `v4.1.5` etiketi](https://github.com/mozilla/mozjpeg/tree/v4.1.5), `6c9f0897afa1c2738d7222a0a9ab49e8b536a267` commit'ini içerir. Arşivin SHA-256 değeri:

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

Kaynak kaydı: [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Koşullar: [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md) ve [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg).

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG, açık kaynak MozJPEG kullanılarak bağımsız geliştirilmiştir.
