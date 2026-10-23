[Toutes les langues](../../README.md) · [Télécharger la dernière version](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG est un outil natif de compression d’images pour macOS, développé avec SwiftUI, AppKit, ImageIO et MozJPEG. Tout le traitement reste sur votre Mac : aucun envoi d’images, aucune publicité, télémétrie ou API en ligne.

Il nécessite **macOS 13 ou une version ultérieure**. L’application Universal contient les exécutables Intel (`x86_64`) et Apple Silicon (`arm64`). Téléchargez la version publiée, décompressez **LightJPEG.app**, puis ouvrez-la ou placez-la dans Applications. Le nom de l’application ne contient pas de numéro de version. Homebrew, Node.js, Python et un encodeur séparé ne sont pas nécessaires.

L’application est **signée ad hoc** ; elle n’est ni signée avec un Developer ID Apple, ni notariée par Apple.

## Premiers pas

1. Ajoutez des images avec le bouton prévu, déposez des fichiers dans la fenêtre ou ajoutez un dossier. Les sous-dossiers sont également parcourus.
2. Réglez la qualité, fixée à **75** par défaut, puis éventuellement la dimension maximale. Conserver la taille d’origine préserve les dimensions en pixels. Le redimensionnement conserve les proportions et n’agrandit jamais l’image.
3. Activez éventuellement le mode **4:4:4** pour mieux conserver les contours colorés ou le texte. Le mode 4:2:0 par défaut produit généralement des fichiers plus petits.
4. Choisissez si vous souhaitez **Conserver les informations EXIF**. Cette option unique inclut le GPS et est désactivée par défaut.
5. Cliquez sur **Tout compresser**, choisissez le dossier de sortie et confirmez avec **Compresser et enregistrer**. Chaque résultat est ensuite enregistré automatiquement, sans seconde étape d’export obligatoire.
6. Sélectionnez une image pour la comparer. **Afficher le dossier de sortie** ouvre la destination dans le Finder.

Les tailles et les économies affichées sous l’aperçu concernent **l’image sélectionnée**, pas le total du lot. Les valeurs de résultat restent à `—` tant qu’aucun résultat n’existe. Le message de fin indique, lui, les enregistrements et échecs du lot.

## Enregistrement, annulation et erreurs

Les résultats sont des JPEG dont le nom reçoit le suffixe `_compressed`. Les fichiers et dossiers existants ne sont jamais écrasés : un numéro est ajouté en cas de collision. Les originaux restent intacts, même si vous choisissez leur dossier comme destination.

Chaque résultat terminé est immédiatement enregistré. Annuler la compression, vider la liste ou quitter l’application ne supprime pas les fichiers déjà enregistrés. Annuler le choix du dossier ne démarre pas la compression et conserve les résultats précédents. Une nouvelle compression redemande le dossier et utilise de nouveaux noms sans écraser les anciens fichiers.

Si l’enregistrement échoue, le résultat compressé reste accessible pendant la session. Utilisez l’export de l’image dans le menu Fichier ou le menu contextuel de l’image pour l’enregistrer ailleurs ; **Commande+S** ouvre aussi cette action facultative. La version 1.1.1 retire le bouton d’export redondant de la barre d’aperçu.

## Comparaison et pixels réels

- Le mode **Image entière** affiche toute l’image à partir d’un aperçu limité à 1 600 pixels. Faites glisser le séparateur pour comparer.
- Le mode **Pixels 1:1** décode les images à leur résolution complète. Un **pixel de l’image de sortie** occupe un **pixel physique de l’écran**, y compris sur Retina. Il ne s’agit pas d’un agrandissement de la miniature.
- Utilisez la molette, le trackpad ou faites glisser l’image hors du séparateur pour vous déplacer. Le séparateur reste déplaçable pour la comparaison.
- Si l’image a été réduite, le mode 1:1 suit la grille de pixels de la sortie. L’original est aligné sur les dimensions de sortie afin de montrer la même zone : il sert alors de référence redimensionnée. Avant compression, le mode 1:1 utilise les pixels de l’original.

Les coordonnées des photos ne changent pas dans une interface de droite à gauche ; les images ne sont pas mises en miroir.

## Formats, qualité et métadonnées

Entrées : **JPEG, PNG, HEIC/HEIF, TIFF, WebP et BMP**, décodées par ImageIO de macOS. La sortie est toujours un **JPEG**. Seule la première image est traitée ; animations, Live Photos, images auxiliaires HDR et contenu des TIFF multipages ne sont pas conservés.

La compression JPEG est avec perte. Une qualité de 75 ne signifie ni « conserver 75 % de la qualité », ni « réduire la taille de 75 % ». Une petite image ou une image déjà optimisée peut devenir plus volumineuse ; l’application le signale. Une qualité inférieure peut aider.

La transparence devient blanche. Les couleurs sont converties en sRGB avec un profil ICC intégré ; la rotation ou la symétrie EXIF est appliquée. Limites : **1 000 images par lot**, **100 millions de pixels pour la source** et **65 500 pixels par dimension JPEG de sortie**. Une source trop grande est refusée même si une réduction est demandée.

**Conserver les informations EXIF** est une seule case, désactivée par défaut :

- Désactivée : les métadonnées EXIF et GPS sont supprimées.
- Activée : les champs standard EXIF/TIFF de l’appareil photo pris en charge et les données GPS sont conservés ensemble. L’orientation est normalisée et les dimensions EXIF sont actualisées selon la sortie.

L’insertion des métadonnées ne recompresse pas les données JPEG. Les champs privés MakerNote, les données XMP/IPTC et les anciennes miniatures ne sont pas recopiés. Les marqueurs JPEG/ICC standard restent présents dans les deux modes. Activer l’option peut conserver la localisation.

## Langues et raccourcis

Au premier lancement, la langue suit les préférences de macOS. Vous pouvez la changer dans le menu de langue ; le choix est mémorisé :

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

L’arabe utilise une disposition de droite à gauche, sans modifier les coordonnées des images.

| Raccourci | Action |
| --- | --- |
| Commande+O | Ajouter des images |
| Commande+Retour | Choisir le dossier puis démarrer la compression |
| Échap | Annuler une compression en cours |
| Commande+S | Enregistrer facultativement le résultat sélectionné ailleurs |
| Commande+Maj+R | Afficher le dossier de sortie |
| Commande+Q | Quitter |

## Compilation et tests

Sur un Mac équipé de Xcode, exécutez :

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

Le script compile les deux architectures, crée `build/LightJPEG.app`, puis applique et vérifie les signatures ad hoc. Il utilise `Resources/bin/cjpeg`. Si cet encodeur est absent, il le reconstruit ; cette étape nécessite aussi **CMake**.

Pour reconstruire explicitement l’encodeur puis l’application :

```sh
bash build-engine.sh
bash build.sh
```

Le script vérifie le SHA-256 de l’archive source fixée. Il la télécharge si elle manque ; une archive déjà disponible permet la reconstruction hors ligne. L’application fonctionne toujours hors ligne. La bibliothèque JPEG est liée statiquement ; SIMD, entrée PNG de l’encodeur, API TurboJPEG et bibliothèques partagées sont désactivés. ImageIO décode les formats d’entrée de l’application ; aucune bibliothèque dynamique Homebrew n’est nécessaire.

Tous les tests, depuis une session de bureau macOS ouverte :

```sh
bash test.sh
```

Les tests natifs d’aperçu créent une fenêtre AppKit masquée et nécessitent une session de bureau. Pour une CI sans interface graphique :

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Si le système ne peut pas créer l’image de test HEIC, fournissez un fichier existant, par exemple `example.heic` du projet libheif :

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Combinaison pour une CI sans interface graphique :
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Sans encodeur HEIC système utilisable ni fichier facultatif, ce cas est indiqué comme ignoré ; cela ne constitue pas une validation HEIC réussie. Projet amont : [libheif](https://github.com/strukturag/libheif).

## Validation consignée et limites

Le rapport de validation du 23 octobre 2026 couvre la compression, l’enregistrement automatique, les collisions de noms, les métadonnées, les langues et l’aperçu. Machine : **iMac Intel, macOS 15.7.9, Xcode 26.3 / Swift 6.2.4**. L’exécutable Intel a été utilisé sur matériel réel. La version Apple Silicon a été compilée de manière croisée et intégrée, mais **aucun Mac ARM n’a été testé dans cet environnement**. Les architectures Universal, les dépendances limitées au système et les signatures ad hoc ont été vérifiées.

Les tests consignés ont réussi pour les huit orientations EXIF, le redimensionnement sans agrandissement, la transparence blanche, le profil sRGB, la suppression/conservation des métadonnées, les originaux inchangés, l’annulation, les échecs d’enregistrement et les exports sans écrasement. La conservation HEIC a été vérifiée avec le fichier libheif. Les tests de traduction couvrent **16 langues × 94 clés**, les paramètres de texte, la sélection de langue et l’arabe RTL. Les **40 assertions** de l’aperçu natif couvrent notamment le décodage intégral, les pixels à l’échelle 1x et Retina simulée, l’alignement, les gestes de souris et le défilement.

Les mises en page de la série 1.1 ont été examinées en chinois, allemand et arabe, y compris à 940 points de largeur, avec les deux modes et les statistiques par image. La version 1.0 avait aussi été examinée en anglais et en hindi. Cela ne signifie pas que toutes les langues et configurations matérielles ont été testées visuellement.

Sur une seule image de démonstration publique de Picdiet, `photographer.jpg`, la taille est passée de 984 065 octets, à 1920 × 1280, à environ 155 Ko avec une qualité de 75, soit environ 84 % de moins. Ce résultat n’est pas garanti pour d’autres images ; la photo n’est pas fournie.

## Historique

**1.1.1 :** retrait du bouton d’export de l’aperçu ; export facultatif conservé dans les menus ; nom d’application stable `LightJPEG.app`.

**1.1.0 :** choix du dossier avant traitement et enregistrement automatique de chaque résultat ; comparaison 1:1 en pixels physiques avec déplacement ; option EXIF unique incluant le GPS ; statistiques de l’image sélectionnée.

## Licence et provenance de l’encodeur

Le code original de LightJPEG est sous [licence MIT](../../LICENSE.txt). Les composants tiers gardent leurs propres conditions. Consultez les textes juridiques originaux dans [Resources/Licenses](../../Resources/Licenses), notamment [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) et [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Ce guide ne les remplace pas.

L’encodeur est issu des sources non modifiées de [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 de l’[archive source](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5) :

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG est une réalisation indépendante fondée sur MozJPEG. Ni l’interface du site Picdiet ni ses scripts empaquetés n’ont été copiés.
