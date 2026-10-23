[Todos los idiomas](../../README.md) · [Descargar la última versión](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG es una aplicación nativa de compresión de imágenes para macOS, creada con SwiftUI, AppKit, ImageIO y MozJPEG. Todo se procesa en tu Mac, sin subir imágenes, anuncios, telemetría ni API en línea.

Requiere **macOS 13 o posterior**. La aplicación Universal incluye ejecutables para Intel (`x86_64`) y Apple Silicon (`arm64`). Descarga la versión publicada, extrae **LightJPEG.app** y ábrela o muévela a Aplicaciones. El nombre de la aplicación no lleva número de versión. No necesitas instalar Homebrew, Node.js, Python ni un codificador aparte.

La aplicación tiene **firma ad hoc**; no está firmada con un Developer ID de Apple ni notarizada por Apple.

## Primeros pasos

1. Añade imágenes con el botón correspondiente, arrastra archivos a la ventana o añade una carpeta. También se buscan imágenes compatibles en sus subcarpetas.
2. Elige la calidad, **75** de forma predeterminada, y, si quieres, una dimensión máxima. Conservar el tamaño original mantiene las dimensiones en píxeles. El cambio de tamaño respeta las proporciones y nunca amplía una imagen.
3. Activa opcionalmente **4:4:4** para conservar mejor los bordes de color y el texto. El valor predeterminado 4:2:0 suele generar archivos más pequeños.
4. Decide si activar **Conservar información EXIF**. Es una sola opción, incluye GPS y está desactivada por defecto.
5. Pulsa **Comprimir todo**, elige la carpeta de salida y confirma con **Comprimir y guardar**. Cada resultado se guarda automáticamente al terminar; no hace falta una segunda exportación.
6. Selecciona una imagen para compararla. La acción para mostrar la carpeta de salida abre el destino en Finder.

Las cifras de tamaño y ahorro bajo la vista previa corresponden a **la imagen seleccionada**, no al lote completo. Los resultados muestran `—` hasta que exista una imagen comprimida. El mensaje final sí indica el número de archivos guardados y fallidos del lote.

## Guardado, cancelación y errores

Los resultados son JPEG con `_compressed` añadido al nombre. Nunca se sobrescriben archivos ni carpetas existentes: si hay una coincidencia, se añade un número. Los originales no se modifican, aunque se guarden los resultados en la carpeta de origen.

Cada resultado terminado se guarda de inmediato. Cancelar, vaciar la lista o cerrar la aplicación no borra los archivos ya guardados. Cancelar el selector de carpeta no inicia la compresión ni descarta resultados anteriores. Al volver a comprimir, se pide de nuevo una carpeta y se usan nombres nuevos para conservar los archivos previos.

Si falla el guardado, el resultado comprimido sigue disponible durante la sesión. Usa la exportación de imagen del menú Archivo o del menú contextual de la imagen para guardarlo en otra ubicación. **Comando+S** abre esa misma acción opcional. La versión 1.1.1 elimina el botón de exportación redundante de la barra de vista previa.

## Comparación y píxeles reales

- **Imagen completa** muestra la imagen completa mediante una vista previa limitada a 1.600 píxeles. Arrastra el separador para comparar original y resultado.
- **Píxeles 1:1** decodifica las imágenes a resolución completa. Un **píxel de la imagen de salida** ocupa un **píxel físico de la pantalla**, también en pantallas Retina. No amplía la miniatura de la vista ajustada.
- Usa la rueda o el trackpad para desplazarte, o arrastra la imagen fuera del separador. El separador puede seguir moviéndose para comparar.
- Si se ha reducido el tamaño, la cuadrícula de salida define el modo 1:1. El original se alinea con las dimensiones de salida para mostrar la misma zona; en ese caso sirve como referencia escalada. Antes de comprimir, el modo 1:1 usa los píxeles del original.

Las coordenadas de las imágenes no cambian en interfaces de derecha a izquierda; las fotos no se reflejan.

## Formatos, calidad y metadatos

Entradas: **JPEG, PNG, HEIC/HEIF, TIFF, WebP y BMP**, mediante ImageIO de macOS. La salida siempre es **JPEG**. Solo se procesa la primera imagen: no se conservan animaciones, Live Photos, imágenes auxiliares HDR ni todas las páginas de un TIFF multipágina.

La compresión JPEG tiene pérdida. Una calidad de 75 no significa «conservar el 75 % de la calidad» ni garantiza reducir el tamaño un 75 %. Las imágenes pequeñas o ya optimizadas pueden crecer; la aplicación lo indica. Una calidad inferior puede ayudar.

Las zonas transparentes se vuelven blancas. El color se convierte a sRGB con un perfil ICC incrustado, y se aplica la rotación o reflexión indicada por EXIF. Límites: **1.000 imágenes por lote**, **100 millones de píxeles de origen** y **65.500 píxeles por dimensión del JPEG de salida**. Se rechazan fuentes demasiado grandes incluso si se solicita reducirlas.

**Conservar información EXIF** es una sola casilla, desactivada por defecto:

- Desactivada: se eliminan EXIF y GPS.
- Activada: se conservan juntos los campos estándar EXIF/TIFF de cámara compatibles y los datos GPS. Se normaliza la orientación y se actualizan las dimensiones EXIF según la salida.

Insertar los metadatos no vuelve a codificar los datos de imagen JPEG. No se copian MakerNote específicos del fabricante, XMP/IPTC ni miniaturas antiguas. Los marcadores de color JPEG/ICC estándar se mantienen en ambos modos. Activar la opción puede conservar información de ubicación.

## Idiomas y atajos

El primer inicio sigue las preferencias de idioma de macOS. El menú de idioma permite cambiarlo y recuerda la elección:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

El árabe usa una distribución de derecha a izquierda, sin alterar las coordenadas de las fotos.

| Atajo | Acción |
| --- | --- |
| Comando+O | Añadir imágenes |
| Comando+Retorno | Elegir carpeta e iniciar la compresión |
| Escape | Cancelar la compresión en curso |
| Comando+S | Guardar opcionalmente el resultado seleccionado en otra ubicación |
| Comando+Mayús+R | Mostrar la carpeta de salida |
| Comando+Q | Salir |

## Compilar y probar

En un Mac con Xcode instalado:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

El script compila ambas arquitecturas, crea `build/LightJPEG.app` y aplica y verifica las firmas ad hoc. Usa `Resources/bin/cjpeg`. Si falta el codificador, lo reconstruye; ese paso requiere también **CMake**.

Para reconstruir expresamente el codificador y la aplicación:

```sh
bash build-engine.sh
bash build.sh
```

El script comprueba el SHA-256 del archivo fuente fijado. Lo descarga si no está disponible; si ya existe, la reconstrucción puede hacerse sin conexión. El uso de la aplicación siempre es local. La biblioteca JPEG se enlaza estáticamente; SIMD, entrada PNG del codificador, API TurboJPEG y bibliotecas compartidas están desactivados. ImageIO decodifica los formatos de entrada de la aplicación. No se necesitan bibliotecas dinámicas de Homebrew.

Ejecuta todos los tests desde una sesión de escritorio macOS iniciada:

```sh
bash test.sh
```

Las pruebas nativas de vista previa crean una ventana AppKit oculta y requieren una sesión de escritorio. Para CI sin interfaz gráfica:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Si el sistema no puede crear una imagen HEIC de prueba, proporciona una existente, por ejemplo `example.heic` de libheif:

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Opciones combinadas para CI sin interfaz gráfica:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Sin un codificador HEIC del sistema disponible ni ese archivo opcional, el caso se informa como omitido, no como una verificación HEIC superada. Proyecto original: [libheif](https://github.com/strukturag/libheif).

## Validación registrada y límites

El informe de validación, del 23 de octubre de 2026, recoge pruebas de compresión, guardado automático, nombres repetidos, metadatos, idiomas y comparación por píxeles. Se usó un **iMac Intel, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4**. Intel se ejecutó en hardware real. Apple Silicon se compiló de forma cruzada y se incluyó en la aplicación Universal, pero **no se probó en hardware ARM en este entorno**. Se verificaron las arquitecturas, las dependencias exclusivamente del sistema y las firmas ad hoc.

Las pruebas registradas pasaron para las ocho orientaciones EXIF, reducción sin ampliación, transparencia blanca, perfil sRGB, opciones de metadatos, originales intactos, cancelación, errores de guardado y exportaciones sin sobrescritura. La conservación HEIC se comprobó con el archivo de libheif. La localización cubre **16 idiomas × 94 claves**, parámetros de texto, resolución del idioma y RTL árabe. La vista previa nativa superó **40 comprobaciones**, incluidas decodificación completa, píxeles a escala 1x y Retina simulada, alineación tras reducir, eventos reales de ratón y desplazamiento.

Se revisaron interfaces de la serie 1.1 en chino, alemán y árabe, incluida una ventana de 940 puntos, ambos modos de vista y estadísticas de la imagen seleccionada. La versión 1.0 también tuvo revisiones en inglés e hindi. No se afirma haber probado visualmente todos los idiomas o configuraciones de Mac.

Una imagen pública de demostración de Picdiet, `photographer.jpg`, pasó de 984.065 bytes a 1920 × 1280 a unos 155 KB con calidad 75, aproximadamente un 84 % menos. Es una única medición, no una reducción garantizada. La foto no se incluye.

## Cambios

**1.1.1:** elimina el botón de exportación de la vista previa, mantiene el guardado opcional desde los menús y usa el nombre estable `LightJPEG.app`.

**1.1.0:** elige la carpeta antes de comprimir y guarda automáticamente cada resultado; añade comparación 1:1 en píxeles físicos con desplazamiento, una opción EXIF que incluye GPS y estadísticas de la imagen seleccionada.

## Licencia y procedencia del codificador

El código original de LightJPEG usa la [licencia MIT](../../LICENSE.txt). Los componentes de terceros conservan sus condiciones. Consulta los textos legales originales en [Resources/Licenses](../../Resources/Licenses), especialmente [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) y [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Esta guía no sustituye esos textos.

El codificador incluido usa las fuentes sin modificar de [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 del [archivo fuente](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5):

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG es una implementación independiente basada en MozJPEG. No se han copiado la interfaz del sitio Picdiet ni sus scripts empaquetados.
