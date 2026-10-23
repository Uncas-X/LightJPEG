[Todos os idiomas](../../README.md) · [Baixar a versão mais recente](https://github.com/Uncas-X/LightJPEG/releases/latest)

# LightJPEG 1.1.1

LightJPEG é um aplicativo nativo para comprimir imagens no macOS, desenvolvido com SwiftUI, AppKit, ImageIO e MozJPEG. Todo o processamento acontece no seu Mac, sem envio de imagens, anúncios, telemetria ou APIs on-line.

Requer **macOS 13 ou posterior**. O aplicativo Universal inclui executáveis para Intel (`x86_64`) e Apple Silicon (`arm64`). Baixe a versão publicada, extraia **LightJPEG.app** e abra o aplicativo ou mova-o para Aplicativos. O nome do aplicativo não inclui o número da versão. Não é necessário instalar Homebrew, Node.js, Python ou um codificador separado.

O aplicativo tem **assinatura ad hoc**; não é assinado com um Developer ID da Apple nem notarizado pela Apple.

## Primeiros passos

1. Adicione imagens pelo botão correspondente, arraste arquivos para a janela ou adicione uma pasta. Imagens compatíveis nas subpastas também são encontradas.
2. Escolha a qualidade, inicialmente **75**, e, se necessário, uma dimensão máxima. Manter o tamanho original preserva as dimensões em pixels. O redimensionamento mantém a proporção e nunca amplia a imagem.
3. Ative opcionalmente **4:4:4** para preservar melhor textos e bordas coloridas. O padrão 4:2:0 costuma produzir arquivos menores.
4. Decida se deseja ativar **Manter informações EXIF**. Essa opção única também inclui GPS e fica desativada por padrão.
5. Clique em **Comprimir tudo**, escolha a pasta de saída e confirme com **Comprimir e salvar**. Cada resultado será salvo automaticamente; não há uma segunda etapa obrigatória de exportação.
6. Selecione uma imagem para compará-la. **Mostrar pasta de saída** abre o destino no Finder.

Os tamanhos e a economia exibidos abaixo da prévia correspondem **à imagem selecionada**, não ao lote inteiro. Os resultados mostram `—` enquanto ainda não houver uma imagem comprimida. A mensagem final informa a quantidade de arquivos salvos e de falhas do lote.

## Salvamento, cancelamento e falhas

Os resultados são JPEGs com `_compressed` acrescentado ao nome. Arquivos e pastas existentes nunca são sobrescritos; nomes repetidos recebem um número. Os originais permanecem intactos, mesmo quando a pasta de origem é escolhida como destino.

Cada resultado concluído é salvo imediatamente. Cancelar a compressão, limpar a lista ou sair do aplicativo não remove arquivos já salvos. Cancelar a escolha da pasta não inicia a compressão nem descarta resultados anteriores. Ao comprimir novamente, o aplicativo pede outra confirmação de pasta e usa novos nomes, preservando os arquivos anteriores.

Se o salvamento falhar, o resultado comprimido permanece disponível durante a sessão. Use **Exportar imagem** no menu Arquivo ou no menu de contexto da imagem para salvá-lo em outro local. **Command+S** abre a mesma ação opcional. A versão 1.1.1 remove o botão de exportação redundante da barra da prévia.

## Comparação e pixels reais

- **Imagem inteira** mostra toda a imagem em uma prévia limitada a 1.600 pixels. Arraste o divisor para comparar o original com o resultado.
- **Pixels 1:1** decodifica as imagens na resolução completa. Um **pixel da imagem de saída** corresponde a um **pixel físico da tela**, inclusive em telas Retina. A miniatura da prévia ajustada não é ampliada.
- Use a roda do mouse ou o trackpad para rolar, ou arraste a imagem fora do divisor para deslocá-la. O divisor continua disponível para a comparação.
- Se a imagem foi reduzida, a grade de pixels da saída define o modo 1:1. O original é alinhado às dimensões de saída para mostrar a mesma região; nesse caso, funciona como uma referência redimensionada. Antes da compressão, 1:1 usa os pixels do original.

As coordenadas das fotos permanecem iguais nas interfaces da direita para a esquerda; as imagens não são espelhadas.

## Formatos, qualidade e metadados

Entradas: **JPEG, PNG, HEIC/HEIF, TIFF, WebP e BMP**, decodificadas pelo ImageIO do macOS. A saída é sempre **JPEG**. Somente a primeira imagem é processada; animações, Live Photos, imagens auxiliares HDR e outras páginas de TIFFs multipágina não são preservadas.

A compressão JPEG tem perdas. Qualidade 75 não significa “manter 75% da qualidade” nem garante reduzir o tamanho em 75%. Imagens pequenas ou já otimizadas podem ficar maiores; o aplicativo informa isso. Uma qualidade menor pode ajudar.

Áreas transparentes ficam brancas. As cores são convertidas para sRGB com perfil ICC incorporado, e as rotações ou reflexões EXIF são aplicadas. Limites: **1.000 imagens por lote**, **100 milhões de pixels na origem** e **65.500 pixels por dimensão do JPEG de saída**. Imagens de origem grandes demais são recusadas mesmo quando se solicita redução.

**Manter informações EXIF** é uma única caixa de seleção, desativada por padrão:

- Desativada: remove EXIF e GPS.
- Ativada: preserva em conjunto os campos padrão EXIF/TIFF de câmera compatíveis e os dados GPS. A orientação é normalizada e as dimensões EXIF são atualizadas conforme a saída.

A inserção de metadados não recodifica os dados JPEG da imagem. Campos MakerNote proprietários, XMP/IPTC e miniaturas antigas não são copiados. Os marcadores de cor JPEG/ICC padrão permanecem nos dois modos. Ativar a opção pode preservar dados de localização.

## Idiomas e atalhos

Na primeira execução, o idioma segue as preferências do macOS. O menu de idioma permite alterá-lo e memoriza sua escolha:

简体中文 · English · 繁體中文 · 日本語 · 한국어 · Français · Deutsch · Español · Italiano · Português (Brasil) · Русский · العربية · हिन्दी · Türkçe · Nederlands · Polski

O árabe usa uma disposição da direita para a esquerda, mantendo as coordenadas das imagens.

| Atalho | Ação |
| --- | --- |
| Command+O | Adicionar imagens |
| Command+Return | Escolher a pasta e iniciar a compressão |
| Escape | Cancelar a compressão em andamento |
| Command+S | Salvar opcionalmente o resultado selecionado em outro local |
| Command+Shift+R | Mostrar a pasta de saída |
| Command+Q | Sair |

## Compilação e testes

Em um Mac com Xcode instalado:

```sh
git clone https://github.com/Uncas-X/LightJPEG.git
cd LightJPEG
bash build.sh
open build/LightJPEG.app
```

O script compila as duas arquiteturas, cria `build/LightJPEG.app`, aplica assinaturas ad hoc e as verifica. Ele usa `Resources/bin/cjpeg`. Se o codificador não estiver presente, será recompilado; essa etapa também exige **CMake**.

Para recompilar explicitamente o codificador e o aplicativo:

```sh
bash build-engine.sh
bash build.sh
```

O script verifica o SHA-256 do arquivo de código-fonte fixado. Se o arquivo estiver ausente, ele será baixado; com o arquivo já disponível, a recompilação pode ser feita off-line. O aplicativo sempre funciona off-line. A biblioteca JPEG é vinculada estaticamente; SIMD, entrada PNG do codificador, API TurboJPEG e bibliotecas compartilhadas ficam desativados. O ImageIO cuida dos formatos de entrada do aplicativo. Não há dependência de bibliotecas dinâmicas do Homebrew durante o uso.

Execute todos os testes em uma sessão de desktop macOS com login ativo:

```sh
bash test.sh
```

Os testes nativos de prévia criam uma janela AppKit oculta e precisam de uma sessão de desktop. Para CI sem interface gráfica:

```sh
LIGHTJPEG_SKIP_UI_TESTS=1 bash test.sh
```

Se o sistema não conseguir criar uma imagem HEIC de teste, forneça um arquivo existente, como `example.heic` do projeto libheif:

```sh
LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
# Opções combinadas para CI sem interface gráfica:
LIGHTJPEG_SKIP_UI_TESTS=1 LIGHTJPEG_HEIC_FIXTURE=/absolute/path/example.heic bash test.sh
```

Sem um codificador HEIC do sistema disponível nem esse arquivo opcional, o caso é informado como ignorado, e não como uma verificação HEIC aprovada. Projeto de origem: [libheif](https://github.com/strukturag/libheif).

## Validação registrada e limitações

O registro de validação, de 23 de outubro de 2026, cobre compressão, salvamento automático, colisões de nomes, metadados, idiomas e comparação de pixels. O computador era um **iMac Intel com macOS 15.7.9, Xcode 26.3 / Swift 6.2.4**. Intel foi executado em hardware real. A versão Apple Silicon foi compilada de forma cruzada e incluída no aplicativo Universal, mas **não foi testada em hardware ARM neste ambiente**. Foram verificadas as arquiteturas, as dependências apenas do sistema e as assinaturas ad hoc.

Os testes registrados passaram para as oito orientações EXIF, redução sem ampliação, transparência branca, perfil sRGB, opções de metadados, originais intactos, cancelamento, falhas de salvamento e exportações sem sobrescrita. A preservação de metadados HEIC foi verificada com o arquivo do libheif. A localização abrange **16 idiomas × 94 chaves**, parâmetros de texto, resolução de idioma e RTL árabe. A prévia nativa passou por **40 verificações**, incluindo decodificação completa, pixels nas escalas 1x e Retina simulada, alinhamento após redução, eventos reais de mouse e rolagem.

Foram revisadas interfaces da série 1.1 em chinês, alemão e árabe, inclusive em uma janela de 940 pontos, nos dois modos e com estatísticas da imagem selecionada. A versão 1.0 também teve revisões em inglês e hindi. Isso não significa que todos os idiomas ou configurações de Mac tenham sido testados visualmente.

## Alterações

**1.1.1:** remove o botão de exportação da prévia, mantém o salvamento opcional pelos menus e usa o nome estável `LightJPEG.app`.

**1.1.0:** escolhe a pasta antes da compressão e salva cada resultado automaticamente; adiciona comparação 1:1 em pixels físicos com deslocamento, uma única opção EXIF incluindo GPS e estatísticas da imagem selecionada.

## Licença e origem do codificador

O código original do LightJPEG usa a [licença MIT](../../LICENSE.txt). Componentes de terceiros mantêm seus próprios termos. Leia os textos legais originais em [Resources/Licenses](../../Resources/Licenses), especialmente [MozJPEG-LICENSE.md](../../Resources/Licenses/MozJPEG-LICENSE.md), [MozJPEG-README.ijg](../../Resources/Licenses/MozJPEG-README.ijg) e [THIRD-PARTY-NOTICES.txt](../../Resources/Licenses/THIRD-PARTY-NOTICES.txt). Este guia não substitui esses textos.

O codificador incluído usa o código-fonte sem modificações do [Mozilla MozJPEG v4.1.5](https://github.com/mozilla/mozjpeg/tree/v4.1.5), commit `6c9f0897afa1c2738d7222a0a9ab49e8b536a267`. SHA-256 do [arquivo de código-fonte](https://codeload.github.com/mozilla/mozjpeg/tar.gz/refs/tags/v4.1.5):

```text
9fcbb7171f6ac383f5b391175d6fb3acde5e64c4c4727274eade84ed0998fcc1
```

> This software is based in part on the work of the Independent JPEG Group.

LightJPEG é uma implementação independente baseada no MozJPEG.
