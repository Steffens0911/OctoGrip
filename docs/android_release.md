# App Android — release e compatibilidade com a API

Plano completo: documento "Octogrip Android — plano de lançamento e atualizações".
Ficha da loja, Data safety e classificação: `docs/play_store.md`.
Regra central: **uma versão do app já instalada nunca pode quebrar por causa de um deploy da API.**

## Identidade do app

- `applicationId` / `namespace`: `br.com.octogrip.app` (`viewer/android/app/build.gradle.kts`).
  Depois do primeiro envio à Play Store, **nunca muda**.
- Firebase: o `google-services.json` precisa conter um app Android com o pacote `br.com.octogrip.app`
  (Console Firebase → projeto `octogrip` → Adicionar app → Android). Sem isso o build Android falha
  com "No matching client found for package name".

## Chave de assinatura

**Atalho:** `powershell -ExecutionPolicy Bypass -File scriptsndroid_setup_signing.ps1` faz os passos 1, 3 e 4
(instala Java e GitHub CLI se faltarem, gera a chave fora do repositório e cadastra os secrets).
Rode você mesmo: a senha é digitada só no seu terminal.

1. Gerar a chave de upload (uma vez, fora do repositório):

   ```bash
   keytool -genkey -v -keystore octogrip-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Ativar o **Play App Signing** no primeiro envio (a Google guarda a chave definitiva).
3. Guardar o `.jks` e as senhas no gerenciador de senhas e numa cópia offline. **Nunca no git**
   (`*.jks` e `key.properties` já estão no `.gitignore`).
4. Secrets do GitHub (environment `secrets`): `ANDROID_KEYSTORE_BASE64` (`base64 -w0 octogrip-upload.jks`),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`,
   `API_BASE_URL` (`https://api.octogrip.com.br`) e, opcional, `SENTRY_DSN_APP` (DSN de um projeto Sentry
   só do app, ex.: `octogrip-app`; sem ele o Sentry fica desligado no app).
5. Build de release local (opcional): `viewer/android/key.properties`

   ```properties
   storeFile=/caminho/para/octogrip-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

   Sem chave, `flutter run --release` local usa a chave de debug; no CI isso é erro.

## Publicar uma versão

1. Subir a versão no `viewer/pubspec.yaml` (`1.3.0+12`: o número depois do `+` sobe a cada envio).
2. `git tag v1.3.0+12 && git push --tags` → `build-mobile.yml` roda os testes, gera o `.aab` e envia
   para a trilha **interna**.
3. Produção: GitHub Actions → *Build & Publish Mobile* → *Run workflow* com `track: production`
   e `user_fraction: 0.2`. Depois de 2–3 dias sem erro novo no Sentry, aumentar para 100% no console da Play.

## Versão mínima e feature flags (API)

| Rota | Quem | Para quê |
| --- | --- | --- |
| `GET /app/config?platform=android` | público | o app lê ao abrir: `min_version`, `latest_version`, `update_message`, `store_url`, `feature_flags` |
| `PUT /admin/app-config/android` | admin | muda os valores acima (vale em até 60 s em todos os workers) |
| `GET /admin/app-versions?days=30` | admin | quantos usuários ativos estão em cada versão |

- O app manda `X-App-Version: 1.3.0+12` e `X-App-Platform: android` em toda requisição.
- Abaixo de `min_version`, qualquer rota (exceto `/app/config`, `/health`, `/metrics`, `/legal`)
  responde **426** com `update.min_version` e `update.store_url`.
- Sem esses headers (web, apps antigos) nada é bloqueado.
- A versão de cada usuário fica em `users.last_app_version` / `last_app_platform` / `last_app_seen_at`.

## Do lado do app (Flutter)

- `AppClientInfo` (`lib/services/app_update_service.dart`) lê a versão do pacote e o cliente HTTP da
  `ApiService` manda os headers em toda requisição. Só Android/iOS se identificam; a web não.
- `AppUpdateService` consulta `/app/config` ao abrir e ao voltar ao app (no máximo a cada 30 min) e trata
  qualquer 426. `AppUpdateGate` (no `MaterialApp.builder`) mostra a tela "Atualização necessária" ou o aviso
  de versão nova. O botão usa o fluxo nativo da Play (`in_app_update`) e cai no link da loja se não der.
- Feature flag: `AppUpdateService.instance.isFeatureEnabled('novo_ranking')`.
- Modelos (`lib/models`) leem o JSON com padrão (`as String? ?? ''`); `test/models/models_tolerant_json_test.dart`
  garante que todo `fromJson` aceita `{}`. **Modelo novo entra nessa lista.**
- Sentry do app em `lib/services/error_reporting.dart`, ativado só com `SENTRY_DSN` no build, sem PII.

## Contrato da API (`docs/openapi_snapshot.json`)

`tests/test_openapi_contract.py` compara a API atual com o snapshot:

- **quebra** (campo removido ou renomeado, tipo trocado, campo que passa a aceitar `null`, enum com valor novo,
  campo novo obrigatório na requisição, endpoint removido) → o teste falha. Torne a mudança aditiva ou siga o
  ciclo de depreciação abaixo;
- **mudança aditiva** → o teste pede para atualizar o snapshot:

  ```bash
  python scripts/update_openapi_snapshot.py
  ```

Só rotas com `response_model` têm a resposta verificada; rotas que devolvem `dict` sem schema ficam de fora.

### Ciclo de depreciação

1. Marcar o campo/rota com `# DEPRECATED desde app X.Y` e anotar abaixo.
2. Publicar uma versão do app que não usa mais aquilo.
3. Acompanhar `GET /admin/app-versions` até quase ninguém ficar abaixo dessa versão (ex.: < 5% em 7 dias).
4. Subir `min_version` para essa versão.
5. Remover da API e rodar `python scripts/update_openapi_snapshot.py --force`.

### Depreciações em andamento

| Campo / rota | Depreciado desde | App que parou de usar | Remover quando |
| --- | --- | --- | --- |
| — | — | — | — |
