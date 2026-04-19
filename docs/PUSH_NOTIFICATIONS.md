# Notificações push (FCM) — OctoGrip

## Visão geral

- **Aluno / equipa**: após login, o token FCM é enviado para `POST /me/push_token` com `platform` `android`, `ios` ou **`web`** (browser), conforme o cliente.
- **Web (Chrome / PWA):** o FCM só é inicializado se o build incluir **`--dart-define=FIREBASE_WEB_APP_ID=...`** (ID do app **Web** no Firebase Console, formato `1:NUM:web:HASH`). Opcional mas recomendado: **`FCM_VAPID_KEY`** — chave pública em **Definições do projeto → Cloud Messaging → certificados Web Push**. O ficheiro **`viewer/web/firebase-messaging-sw.js`** tem de usar o **mesmo** `appId` (no Docker o `Dockerfile` substitui `__FIREBASE_WEB_APP_ID__` pelo `ARG FIREBASE_WEB_APP_ID` antes do `flutter build web`). Sem `FIREBASE_WEB_APP_ID`, o viewer Web **não** regista token (comportamento anterior).
- **Gerente ou professor** (com permissão de escrita na academia): no painel **Academia → Aviso à academia (push)**, envia título + mensagem. A API chama o **Firebase Cloud Messaging HTTP v1** para cada token dos utilizadores com `academy_id` igual à da academia alvo.
- **Administrador da plataforma**: `POST /admin/push_broadcast` com o mesmo corpo `{ "title", "body" }` envia para **todos** os tokens FCM registados (toda a base), útil para avisos globais. No app Flutter, aba **Admin** → **Notificação push global** (com confirmação antes do envio).

## Configuração do servidor (API)

Variáveis de ambiente (ou `.env`):

| Variável | Descrição |
|----------|-----------|
| `FIREBASE_PROJECT_ID` | ID do projeto Firebase (ex.: `meu-projeto-123`). |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Caminho ao JSON da **service account** (Google Cloud / IAM → conta de serviço → chave JSON). No repositório o `.env` de exemplo usa `secrets/firebase-service-account.json` (pasta `secrets/` na raiz; ficheiros `*.json` ignorados pelo Git). |

Sem estas variáveis, `POST /academies/{id}/push_notification` responde **503** com mensagem explicativa.

Dependências Python: `httpx`, `google-auth` e **`requests`** (o transporte `google.auth.transport.requests` exige o pacote `requests`; está em `requirements.txt`). Sem `requests`, a API falha ao arrancar com `ImportError` no `fcm_service`.

## Migração de base de dados

Aplicar `migrations/055_user_device_push_tokens.sql` (executada pelo fluxo habitual de migrações da app).

## Configuração do app (Flutter)

1. Criar projeto no [Firebase Console](https://console.firebase.google.com/), ativar **Cloud Messaging**.
2. Instalar apps Android (package `com.example.viewer` ou o que definires) e iOS com o bundle id correspondente.
3. Executar no diretório `viewer/`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Isto gera/atualiza `lib/firebase_options.dart` (substitui o placeholder do repositório).
4. **Android**: coloca o ficheiro **`google-services.json`** (botão “Baixar” no assistente Firebase) em **`viewer/android/app/`**. O projeto já inclui o plugin Gradle `com.google.gms.google-services` para o Gradle processar esse ficheiro. Sem ele, o build Android falha até colocares o JSON correto.
5. **iOS**: adicionar capacidade **Push Notifications** no Xcode e configurar certificados APNs no Firebase, conforme documentação Apple/Firebase.
6. **Web (push no browser):** no Firebase, adicionar uma app do tipo **Web** ao mesmo projecto. Copiar o **App ID** para o build (`FIREBASE_WEB_APP_ID`). Gerar o par de chaves **Web Push** na consola e passar a chave pública em `FCM_VAPID_KEY` se `getToken()` falhar sem ela. Garantir que `firebase-messaging-sw.js` na raiz do build coincide com o `appId` (substituição automática no `viewer/Dockerfile` com `ARG FIREBASE_WEB_APP_ID`).

### Web — `init (web) falhou` com `TypeError: ... is not a subtype`

Em builds **release** (`dart2js`), o resultado de `Notification.requestPermission()` pode chegar ao Dart já como `String`. O plugin `firebase_messaging_web` aplicava um segundo `.toDart` e gerava esse erro; o viewer pede a permissão via `lib/services/push_notification_web_permission.dart` (import condicional) para contornar o problema. Depois de **rebuild** do viewer, o `POST /me/push_token` deve voltar a ser tentado após login.

**Ordem de inicialização:** na Web é obrigatório chamar `Firebase.initializeApp` **antes** de `FirebaseMessaging.instance` (por exemplo `isSupported()`), porque o getter `instance` invoca `Firebase.app()`. Se a ordem estiver invertida, podem ocorrer falhas difíceis de ler no JS minificado.

Para diagnóstico, a consola imprime `[OctoGrip FCM] init web: passo A–E`; o último passo visto antes do erro indica onde parou.

## Endpoints

- `POST /me/push_token` — corpo `{ "token": "...", "platform": "android"|"ios"|"web" }` (autenticado).
- `DELETE /me/push_tokens` — remove todos os tokens do utilizador (logout chama isto).
- `POST /academies/{academy_id}/push_notification` — corpo `{ "title": "...", "body": "..." }`; requer role com escrita na academia e acesso à academia indicada.
- `POST /admin/push_broadcast` — mesmo corpo; requer JWT de utilizador com role **`administrador`**. Envia para todos os tokens na tabela `user_device_tokens`.

## Segurança

- O envio por academia está limitado por **verificação de academia** (`verify_academy_access`): gerente/professor só dispara para a própria academia.
- O broadcast global só é acessível a **administradores**; use com cuidado (todos os utilizadores com app e token activo).
- Tokens inválidos (app desinstalada, etc.) são **removidos** da base após resposta FCM indicativa.

## O que o repositório já automatiza vs. o que só você pode fazer

### Já no projeto (local)

- **`docker compose build api && docker compose up -d api`** — actualiza a API para expor `POST /admin/push_broadcast` (evita 404 com imagem antiga).
- **Script de diagnóstico** (na raiz do repo):

  ```bash
  python scripts/verify_push_setup.py
  python scripts/verify_push_setup.py --base-url https://SUA-API --email SEU_ADMIN --password '***'
  ```

  Interpretação: **404** = redeploy da API com código actual; **503** = falta `FIREBASE_PROJECT_ID` / service account no servidor; **200** com `sent=0` e tokens reais = rever credenciais FCM ou tokens expirados.

### Só na sua conta (Firebase / Google Cloud)

1. Criar ou reutilizar **projeto Firebase** com **Cloud Messaging** activo.
2. **Service account** com permissão para FCM → JSON descarregado → colocado na VPS (ex.: `/srv/octogrip/secrets/firebase-service-account.json`) e referenciado por `FIREBASE_SERVICE_ACCOUNT_PATH` no contentor da API.
3. **`FIREBASE_PROJECT_ID`** = ID do projeto na consola (ex.: `octogrip`).
4. Para **Web**: app tipo **Web** no mesmo projeto → **App ID** e (recomendado) par **Web Push** (VAPID) → passar no **build** do viewer (`FIREBASE_WEB_APP_ID`, `FCM_VAPID_KEY`). Não dá para o agente “inventar” estes valores; têm de vir da consola.

### Só no seu hosting (Coolify / VPS / DNS)

1. Variáveis de ambiente da **API** em produção alinhadas ao `.env` / `docker-compose` (CORS, `DATABASE_URL`, `JWT_SECRET`, `FIREBASE_*`).
2. **Rebuild** da imagem da API após `git pull` (senão continua 404 ou código velho).
3. **Rebuild** do **viewer** quando mudar `API_BASE_URL` ou quando activar FCM Web (build args no `viewer/Dockerfile`).
