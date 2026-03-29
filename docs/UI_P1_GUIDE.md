# UI P1 Guide (AppBaby Viewer)

Este guia resume os padroes de UI/UX P1 para manter consistencia nas telas de aluno e admin.

## 1) Estados de tela

Use `AppScreenState` para padronizar:

- `loading`
- `error` com retry
- `empty`
- `content`

Arquivo: `viewer/lib/widgets/app_screen_state.dart`

## 2) Listas e CRUD

Use `AppListScaffold` em telas de listagem para:

- comportamento de refresh consistente
- bloco opcional de filtros no topo
- padding padrao de lista

Arquivo: `viewer/lib/widgets/app_list_scaffold.dart`

## 3) Componentes visuais base

- `AppCard` para superfícies de conteudo
- `AppNavigationTile` para atalhos navegaveis

Arquivos:

- `viewer/lib/widgets/app_card.dart`
- `viewer/lib/widgets/app_navigation_tile.dart`

## 4) Tipografia e hierarquia

- fonte legivel para corpo/metadados
- fonte de marca apenas como acento visual (titulos estrategicos)
- manter escala consistente entre `title`, `body` e `label`

Arquivo: `viewer/lib/app_theme.dart`

## 5) Acessibilidade basica

- adicionar `Semantics` em controles criticos
- nao depender apenas de cor para status
- manter labels e hints curtos e descritivos

## 6) Checklist para novos CRUDs

- [ ] usa `AppScreenState` para loading/error/empty
- [ ] usa `AppListScaffold` para lista principal
- [ ] usa `AppNavigationTile`/`AppCard` em vez de layout duplicado
- [ ] segue espacos e tipografia do tema
- [ ] inclui rotulo acessivel em acoes criticas
