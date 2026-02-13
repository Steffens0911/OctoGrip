# JJB Viewer (Flutter)

App Flutter com **seção de administração** para o usuário administrador gerenciar academias, usuários, lições, técnicas, posições e missões.

## Como rodar

1. Tenha a API rodando (ex.: `http://localhost:8000`).
2. Instale dependências e rode o app:

```bash
cd viewer
flutter pub get
flutter run
```

Se o Flutter não estiver no PATH (ex.: instalado em `C:\flutter`), use o caminho completo:

```bash
cd viewer
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run
```

**Dica:** Para usar só `flutter` em qualquer terminal, adicione `C:\flutter\bin` às variáveis de ambiente PATH do Windows.

## URL da API

Por padrão o app usa `http://localhost:8000`. Para alterar (ex.: emulador Android usa `10.0.2.2` para localhost do host):

- **Web:** altere `kApiBaseUrl` em `lib/config.dart` ou use:
  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  ```
- **Android emulador:** use `http://10.0.2.2:8000` como base.
- **Dispositivo físico:** use o IP da máquina onde a API está (ex.: `http://192.168.1.10:8000`).

## Navegação

- **Menu (drawer):** Início | **Administração**
- **Administração:** lista de CRUDs (Academias, Usuários, Lições, Técnicas, Posições, Missões). Em cada tela: lista, botão **+** para criar, toque para editar, ícone de lixeira para excluir.

## Estrutura

- `lib/main.dart` — App e shell com drawer (Início / Administração)
- `lib/screens/home_screen.dart` — Tela inicial do viewer
- `lib/screens/admin/` — Telas da seção Administração (lista + formulário por entidade)
- `lib/services/api_service.dart` — Cliente HTTP para a API
- `lib/models/` — Modelos (Academy, User, Lesson, Technique, Position, Mission)
- `lib/config.dart` — URL base da API
- `lib/app_theme.dart` — Tema (verde #58CC02)
