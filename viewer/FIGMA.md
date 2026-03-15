# Integração com Figma

O projeto usa [figma_puller](https://pub.dev/packages/figma_puller) para importar cores, ícones e tokens de design do Figma.

## Memo UI Kit (Figma Community)

**File key do Memo UI Kit:** use o key da **sua cópia** do arquivo (após duplicar). Ex.: `N6Gy3Mf32Y9npHLbG5AEe7` — extrair da URL `https://www.figma.com/design/XXXXXXXX/...` → `XXXXXXXX`.

Para usar o [Memo UI Kit](https://www.figma.com/community/file/1007652386132205250) no projeto:

1. **Obter um arquivo editável (se precisar de outro key)**  
   A API do Figma trabalha com arquivos (`/file/...`). Para este kit você pode usar o file key acima; se o comando falhar (ex.: arquivo só acessível após duplicar), duplique o arquivo no Figma e use o key da URL da cópia: `https://www.figma.com/file/XXXXXXXX/Nome-do-Arquivo` → `XXXXXXXX`.

2. **Token da API Figma**  
   - Acesse [Figma → Settings → Personal access tokens](https://www.figma.com/settings).
   - Crie um token e guarde em local seguro (variável de ambiente ou arquivo não versionado).

Depois disso, use os comandos abaixo na pasta `viewer` (substitua apenas `SEU_TOKEN` pelo seu token).

## Configuração geral

### 1. Token da API Figma
- Acesse [Figma → Settings → Personal access tokens](https://www.figma.com/settings)
- Crie um novo token e guarde-o em local seguro

### 2. File key do arquivo Figma
- Para arquivos que você criou: abra o arquivo no Figma; o file key fica na URL: `https://www.figma.com/file/ABC123XYZ/Nome-do-Arquivo` → `ABC123XYZ`
- Para arquivos da Community (ex.: Memo UI Kit): duplique o arquivo primeiro; o file key é o da cópia (ver seção "Memo UI Kit" acima).

## Uso

Na pasta `viewer`, execute:

```bash
# Memo UI Kit: com theme extension e ícones em SVG (recomendado)
dart run figma_puller:figma_pull -k N6Gy3Mf32Y9npHLbG5AEe7 -t SEU_TOKEN --theme-extension --icon-widgets --icon-format svg -o lib/generated -a assets/icons

# Extrair apenas cores e ícones (sem theme extension)
dart run figma_puller:figma_pull -k N6Gy3Mf32Y9npHLbG5AEe7 -t SEU_TOKEN -o lib/generated -a assets/icons

# Apenas cores
dart run figma_puller:figma_pull -k N6Gy3Mf32Y9npHLbG5AEe7 -t SEU_TOKEN --colors-only
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

O `pubspec.yaml` já declara `assets/icons/` e a dependência `flutter_svg` para uso de ícones SVG.

## Integração no app (Memo UI Kit)

O figma_puller gera **cores, ícones e tokens**; não gera widgets Flutter. Use o Figma como referência e implemente componentes à mão.

- **Opção A — Só tokens:** Usar as cores/ícones gerados em novos widgets ou telas específicas, sem mudar o tema global.
- **Opção B — Alinhar ao Memo:** Copiar valores do gerado para `AppTheme` em `lib/app_theme.dart` e usar os ícones gerados onde fizer sentido.
- **Opção C — Novo estilo "Memo":** Adicionar um terceiro `ThemeStyle` (ex.: `memo`) em `ThemeService` e em `main.dart`, e definir um `ThemeData` em `app_theme.dart` baseado nas cores geradas pelo figma_puller.
