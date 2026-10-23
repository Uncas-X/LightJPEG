[Tutte le lingue](../../README.md) · [Scarica l’ultima versione](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG è un’app nativa per comprimere immagini su macOS, realizzata con SwiftUI, AppKit, ImageIO e MozJPEG. L’elaborazione avviene interamente sul Mac, senza caricamenti, pubblicità, telemetria o API online.

Richiede **macOS 13 o successivo**. L’app Universal include gli eseguibili Intel (`x86_64`) e Apple Silicon (`arm64`). Scarica la versione pubblicata, estrai **LightJPEG.app**, quindi aprila o spostala in Applicazioni. Il nome dell’app non contiene un numero di versione. Non occorre installare Homebrew, Node.js, Python o un codificatore separato.

L’app è **firmata ad hoc**, ma non con un Developer ID Apple e non è autenticata tramite notarizzazione Apple.

## Primi passi

1. Aggiungi immagini con il pulsante dedicato, trascina i file nella finestra oppure aggiungi una cartella. Vengono cercate immagini compatibili anche nelle sottocartelle.
2. Imposta la qualità, inizialmente **75**, ed eventualmente una dimensione massima. Mantenere le dimensioni originali conserva le misure in pixel. Il ridimensionamento mantiene le proporzioni e non ingrandisce mai un’immagine.
3. Attiva eventualmente **4:4:4** per conservare meglio testo e bordi colorati. L’impostazione predefinita 4:2:0 produce generalmente file più piccoli.
4. Scegli se attivare **Conserva le informazioni EXIF**. È un’unica opzione, comprende anche il GPS ed è disattivata per impostazione predefinita.
5. Premi **Comprimi tutto**, scegli la cartella di destinazione e conferma con **Comprimi e salva**. Ogni risultato viene poi salvato automaticamente, senza un secondo passaggio di esportazione obbligatorio.
6. Seleziona un’immagine per confrontarla. **Mostra cartella di destinazione** apre la destinazione nel Finder.

Dimensioni e risparmio sotto l’anteprima si riferiscono **all’immagine selezionata**, non all’intero gruppo. I valori del risultato mostrano `—` finché non è disponibile una versione compressa. Il messaggio finale conta invece i salvataggi e gli errori dell’intero gruppo.

## Salvataggio, annullamento ed errori

I risultati sono JPEG con `_compressed` aggiunto al nome. File e cartelle esistenti non vengono mai sovrascritti: in caso di conflitto si aggiunge un numero. Gli originali rimangono invariati anche scegliendo la cartella sorgente come destinazione.

Ogni risultato completato viene salvato subito. Annullare la compressione, svuotare l’elenco o chiudere l’app non elimina i file già salvati. Annullare la scelta della cartella non avvia la compressione e conserva i risultati precedenti. Una nuova compressione richiede nuovamente una cartella e usa nuovi nomi, senza modificare i file già salvati.

Se il salvataggio non riesce, il risultato compresso resta disponibile durante la sessione. Usa **Esporta immagine** dal menu File o dal menu contestuale dell’immagine per salvarlo altrove. **Comando+S** apre la stessa azione facoltativa. La versione 1.1.1 elimina il pulsante di esportazione ridondante dalla barra dell’anteprima.

## Confronto e pixel reali

- **Immagine intera** mostra tutta l’immagine con un’anteprima limitata a 1.600 pixel. Trascina il divisore per confrontare originale e risultato.
- **Pixel 1:1** decodifica le immagini a piena risoluzione. Un **pixel dell’immagine di uscita** occupa un **pixel fisico dello schermo**, anche su Retina. Non ingrandisce la miniatura dell’anteprima adattata.
- Usa la rotella o il trackpad per scorrere, oppure trascina l’immagine lontano dal divisore per spostarla. Il divisore rimane trascinabile per il confronto.
- Se l’immagine è stata ridotta, il riferimento 1:1 è la griglia di pixel del risultato. L’originale viene allineato alle dimensioni di uscita per mostrare la stessa zona e funge quindi da riferimento ridimensionato. Prima della compressione, 1:1 usa i pixel dell’originale.

Le coordinate delle foto non cambiano nelle interfacce da destra a sinistra; le immagini non vengono specchiate.

## Formati, qualità e metadati

Formati in ingresso: **JPEG, PNG, HEIC/HEIF, TIFF, WebP e BMP**, decodificati da ImageIO di macOS. Il risultato è sempre **JPEG**. Si elabora solo la prima immagine: animazioni, Live Photo, immagini ausiliarie HDR e ulteriori pagine TIFF non vengono conservate.

La compressione JPEG comporta una perdita di informazioni. Qualità 75 non significa «conservare il 75% della qualità» né garantisce una riduzione del 75%. Immagini piccole o già ottimizzate possono aumentare di dimensioni; l’app lo segnala. Una qualità più bassa può aiutare.

Le aree trasparenti diventano bianche. I colori vengono convertiti in sRGB con un profilo ICC incorporato; rotazioni e riflessioni EXIF vengono applicate. Limiti: **1.000 immagini per gruppo**, **100 milioni di pixel nella sorgente** e **65.500 pixel per dimensione del JPEG risultante**. Le sorgenti troppo grandi vengono rifiutate anche se si richiede di ridurle.

**Conserva le informazioni EXIF** è una sola casella, disattivata per impostazione predefinita:

- Disattivata: rimuove EXIF e GPS.
- Attivata: conserva insieme i campi standard EXIF/TIFF della fotocamera supportati e i dati GPS. L’orientamento viene normalizzato e le dimensioni EXIF vengono aggiornate secondo il risultato.

L’inserimento dei metadati non ricodifica i dati JPEG dell’immagine. Non si copiano MakerNote proprietari, XMP/IPTC o vecchie miniature. I marcatori colore JPEG/ICC standard rimangono in entrambe le modalità. Attivando l’opzione si possono conservare dati di posizione.

## Lingue e scorciatoie

Al primo avvio la lingua segue le preferenze di macOS. Il menu delle lingue permette di cambiarla e memorizza la scelta:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

L’arabo usa una disposizione da destra a sinistra, senza cambiare le coordinate delle immagini.

| Scorciatoia | Azione |
| --- | --- |
| Comando+O | Aggiungi immagini |
| Comando+Invio | Scegli la cartella e avvia la compressione |
| Esc | Annulla la compressione in corso |
| Comando+S | Salva facoltativamente il risultato selezionato altrove |
| Comando+Maiuscole+R | Mostra la cartella di destinazione |
| Comando+Q | Esci |

## Compilazione e test

Su un Mac con Xcode installato:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

Lo script compila entrambe le architetture, crea `build/LightJPEG.app`, applica firme ad hoc e le verifica. Usa `Resources/bin/cjpeg`. Se il codificatore manca, lo ricompila; quel passaggio richiede anche **CMake**.

Per ricompilare esplicitamente codificatore e app:

```sh
bash build-engine.sh
bash build.sh
```

Lo script verifica il SHA-256 dell’archivio sorgente fissato. Se manca, lo scarica; con l’archivio già presente la ricompilazione può avvenire offline. L’app funziona sempre offline. La libreria JPEG viene collegata staticamente; SIMD, ingresso PNG del codificatore, API TurboJPEG e librerie condivise sono disattivati. ImageIO gestisce i formati in ingresso dell’app. Non servono librerie dinamiche Homebrew durante l’uso.

Esegui tutti i test da una sessione desktop macOS con accesso effettuato:

```sh
bash test.sh
```

I test nativi dell’anteprima creano una finestra AppKit nascosta e richiedono una sessione desktop. Per CI senza interfaccia grafica:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Se il sistema non può creare un’immagine HEIC di prova, fornisci un file esistente, ad esempio `example.heic` del progetto libheif:

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Opzioni combinate per CI senza interfaccia grafica:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Senza un codificatore HEIC di sistema utilizzabile né questo file facoltativo, il caso viene indicato come saltato, non come verifica HEIC superata. Progetto di origine: [libheif](https://github.com/strukturag/libheif).

## Verifica documentata e limiti

Il rapporto di verifica del 23 ottobre 2026 copre compressione, salvataggio automatico, nomi duplicati, metadati, lingue e confronto dei pixel. Il computer era un **iMac Intel con macOS 15.7.9, Xcode 26.3 / Swift 6.2.4**. Intel è stato eseguito su hardware reale. Apple Silicon è stato compilato tramite cross-compilazione e incluso nell’app Universal, ma **non è stato provato su hardware ARM in questo ambiente**. Sono state verificate architetture, dipendenze solo di sistema e firme ad hoc.

I test documentati sono riusciti per tutti gli otto orientamenti EXIF, riduzione senza ingrandimento, trasparenza bianca, profilo sRGB, opzioni sui metadati, originali invariati, annullamento, errori di salvataggio ed esportazione senza sovrascrittura. La conservazione HEIC è stata verificata con il file libheif. La localizzazione copre **16 lingue × 94 chiavi**, parametri dei testi, selezione della lingua e RTL arabo. L’anteprima nativa ha superato **40 verifiche**, comprese decodifica integrale, pixel a scala 1x e Retina simulata, allineamento dopo la riduzione, eventi reali del mouse e scorrimento.

Sono state esaminate le interfacce della serie 1.1 in cinese, tedesco e arabo, anche in una finestra larga 940 punti, con entrambe le modalità e statistiche dell’immagine selezionata. La versione 1.0 aveva anche verifiche visive in inglese e hindi. Non si afferma di aver verificato visivamente ogni lingua o configurazione Mac.

Una sola immagine dimostrativa pubblica di Picdiet, `photographer.jpg`, è passata da 984.065 byte a 1920 × 1280 a circa 155 KB con qualità 75, circa l’84% in meno. È una misurazione singola, non una riduzione garantita. La foto non è inclusa.

## Novità

**1.1.1:** rimuove il pulsante di esportazione dall’anteprima, mantiene il salvataggio facoltativo nei menu e usa il nome stabile `LightJPEG.app`.

**1.1.0:** sceglie la cartella prima della compressione e salva automaticamente ogni risultato; introduce il confronto 1:1 in pixel fisici con spostamento, un’unica opzione EXIF comprendente GPS e statistiche dell’immagine selezionata.

## Licenza e provenienza del codificatore

Il codice originale di LightJPEG usa la [licenza MIT](../../LICENSE.txt). I componenti di terze parti conservano le proprie condizioni. Consulta i testi legali originali in [Resources/Licenses](../../Resources/Licenses), in particolare [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) e [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Questa guida non sostituisce tali testi.

Il codificatore incluso usa i sorgenti non modificati di [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 dell’[archivio sorgente](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5):

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG è un’implementazione indipendente basata su MozJPEG. Non copia l’interfaccia del sito Picdiet né i suoi script distribuiti.
