# Notificações push (FCM) — OctoGrip

## Visão geral

- **Aluno / equipa**: com a app **Android ou iOS**, após login, o token FCM é enviado para `POST /me/push_token` e fica associado ao utilizador e à sua academia.
- **Gerente ou professor** (com permissão de escrita na academia): no painel **Academia → Aviso à academia (push)**, envia título + mensagem. A API chama o **Firebase Cloud Messaging HTTP v1** para cada token dos utilizadores com `academy_id` igual à da academia alvo.

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

## Endpoints

- `POST /me/push_token` — corpo `{ "token": "...", "platform": "android"|"ios"|"web" }` (autenticado).
- `DELETE /me/push_tokens` — remove todos os tokens do utilizador (logout chama isto).
- `POST /academies/{academy_id}/push_notification` — corpo `{ "title": "...", "body": "..." }`; requer role com escrita na academia e acesso à academia indicada.

## Segurança

- O envio está limitado por **verificação de academia** (`verify_academy_access`): gerente/professor só dispara para a própria academia.
- Tokens inválidos (app desinstalada, etc.) são **removidos** da base após resposta FCM indicativa.
