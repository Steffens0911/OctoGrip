# Integração com Figma

O projeto usa [figma_puller](https://pub.dev/packages/figma_puller) para importar cores, ícones e tokens de design do Figma.

## Configuração

### 1. Token da API Figma
- Acesse [Figma → Settings → Personal access tokens](https://www.figma.com/settings)
- Crie um novo token e guarde-o em local seguro

### 2. File key do arquivo Figma
- Abra o arquivo no Figma
- O file key fica na URL: `https://www.figma.com/file/ABC123XYZ/Nome-do-Arquivo` → `ABC123XYZ`

## Uso

Na pasta `viewer`, execute:

```bash
# Extrair cores e ícones
dart run figma_puller:figma_pull -k SEU_FILE_KEY -t SEU_TOKEN

# Com theme extension e ícones em SVG
dart run figma_puller:figma_pull -k SEU_FILE_KEY -t SEU_TOKEN --theme-extension --icon-widgets --icon-format svg

# Apenas cores
dart run figma_puller:figma_pull -k SEU_FILE_KEY -t SEU_TOKEN --colors-only
```

### Opções úteis
- `-o lib/generated` — diretório de saída (padrão)
- `-a assets/icons` — diretório para ícones
- `--categorized` — organizar cores/ícones em categorias
- `--clean` — baixar tudo de novo (ignorar cache)

## Estrutura gerada

```
viewer/
├── lib/generated/     # app_colors.dart, app_icons.dart, etc.
└── assets/icons/      # SVGs ou PNGs baixados
```

Depois de rodar, inclua `assets/icons/` no `pubspec.yaml` e adicione `flutter_svg` se usar ícones SVG.
