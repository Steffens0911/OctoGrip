# Estratégia de testes — viewer (Flutter)

Plano de cobertura para sair de ~3 testes para uma suíte real (unit → widget → service → E2E),
sem quebrar o comportamento já coberto pelo backend.

## Como rodar

```bash
cd viewer
flutter pub get          # necessário após adicionar mocktail/network_image_mock/integration_test
flutter test             # unit + widget
flutter test --coverage  # gera coverage/lcov.info
flutter test integration_test -d chrome   # E2E (Fase 5, quando existir)
```

## Convenções

- Estrutura espelha `lib/`: `test/models/`, `test/utils/`, `test/widgets/`, `test/services/`, `test/features/`.
- Sufixo `_test.dart`; um arquivo de teste por arquivo de produção.
- Sem codegen: fakes manuais (ver `features/techniques/..._usecase_test.dart`) ou `mocktail`.
- Fixtures de JSON inline nos testes de model, espelhando as respostas reais da API (snake_case).

## Fases

- [x] **Fase 0 — Infra**: deps de teste (`mocktail`, `network_image_mock`, `integration_test`).
- [x] **Fase 1 — Lógica pura + serialização**: models (`fromJson/toJson`) e utils. (ROI alto, zero refatoração.)
- [ ] **Fase 2 — Widget tests**: `consent_gate` (LGPD), `login_screen`, `privacy_data_screen`,
      `mission_card`, `role_guard`, `account_frozen_banner`, `bottom_navigation_widget`.
      Usar `mocktail` para falsear `AuthService`/`ApiService` e `pumpWidget` com `Provider`.
- [x] **Fase 3 — Services**: `ApiService` recebe `http.Client` via `setHttpClientForTesting()`
      (`@visibleForTesting`); 161 call sites `_client.*` + 9 multipart `_client.send(request)`.
      Testes: mapeamento de erros (401/403/404/AccountFrozenError), `formatApiDetail`, headers de
      auth (Bearer + impersonation), `getMyConsents` (payload real `{"items":[...]}`), TTL cache,
      timeout. `AuthService` testado com `SharedPreferences.setMockInitialValues`: init/state,
      roles, impersonação, authHeader, persistência e notifyListeners.
- [x] **Fase 4 — Features (techniques clean arch)**: `TechniqueMapper` (toEntity/fromEntity/round-trip),
      `TechniqueDto` (fromJson com academyId, toJson, fromHiveMap/toHiveMap), `TechniqueRepositoryImpl`
      com fakes (getCached, syncFromRemote sucesso/falha/hive-write-fail, create/update com merge de
      cache, delete, clearLocalCache), todos os 5 usecases (Create/Update/Delete/Sync/Clear),
      `TechniqueListState` (filtered/visible/hasMore/isEmpty/copyWith).
      Padrão: fakes manuais (sem mocktail), assertivas via `fold` para tipos genéricos `Either`.
- [ ] **Fase 5 — E2E (`integration_test`)**: login → home → completar missão; gate de consentimento.
- [x] **Fase 6 — CI**: job `flutter-test` em `.github/workflows/ci.yml`; roda em push/PR para main;
      `flutter test --coverage` + `lcov` com threshold ≥ 20% (sobe gradualmente). Artifact
      `flutter-coverage` retido 30 dias.

## Cobertura atual (Fases 0–4)

- `models/`: user, mission_today (+ week/kits), trophy (+ helpers), notification, attendance_ranking, technique.
- `utils/`: youtube_utils, error_message, form_utils.
- `core/`: leveling (já existia).
- `features/techniques/`: get_cached usecase (já existia), TechniqueMapper, TechniqueDto, TechniqueRepositoryImpl (fakes), todos os 5 usecases, TechniqueListState.
- `widgets/`: account_frozen_banner, mission_card, role_guard (admin/supervisor/impersonação), consent_gate (loading, fail-open, termos, biometria + pular).
- `screens/auth/`: login_screen (estrutura, toggle senha, validação de formulário).

**Mudanças nas sources (mínimas) para testar:**
- `AuthService.setForTesting(...)` — `@visibleForTesting`, ajusta estado do singleton sem tocar em SharedPreferences nem em rede.
- `ConsentGate.testApiService` — `@visibleForTesting`, injeta `ApiService` no gate e nas views internas (passo 1 e 2).
- `ApiService._client` — campo `http.Client` com `setHttpClientForTesting(client)` `@visibleForTesting`; 161 call sites refatorados de `http.*` → `_client.*`; 9 multiparts de `request.send()` → `_client.send(request)`.
