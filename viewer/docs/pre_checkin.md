# Pré-checkin de treinos

Sistema alternativo de chamada com confirmação de presença antecipada, substituindo a enquete do WhatsApp e incentivando o aluno a abrir o app num momento tranquilo.

---

## O que é

Dois momentos separados no fluxo de presença:

1. **Pré-confirmação (véspera / no dia)** — aluno confirma no app em quais treinos vai. Substitui a enquete do WhatsApp e expõe o aluno ao resto do app (missões, troféus, stats) num momento de folga.
2. **Check-in real (tatame)** — reconhecimento facial (totem/celular do professor) ou QR como fallback. Já existe, será reaproveitado.

---

## Linha do tempo de um treino

```
véspera          18h30           19h00          19h15
   |________________|_______________|_______________|------>
   [   confirmar: vou no app   ]   [  chamada aberta  ]  fechado
                   ^                ^               ^
              confirmação       pontual          fecha
               fecha aqui      (troféu)        sozinha
```

- **Confirmar "vou":** disponível a partir do lançamento até **30 minutos antes** da aula (18h30).
- **Chamada no tatame:** professor pode abrir a partir de **30 minutos antes** (18h30); fecha sozinha em **início + tolerância** (ex: 19h15).
- **Troféu de pontualidade:** quem bate presença antes das 19h00 (início) ganha o ponto. Chegou entre 19h00 e 19h15 = presença conta, mas não é "pontual".

---

## Como o professor lança um treino

Equivalente a postar a enquete no grupo do WhatsApp — só que no app:

1. Toca em **"Lançar treino"** (ou escolhe um favorito salvo com 1 toque).
2. Preenche 3 campos:
   - **Dia** (ex: amanhã, ou escolhe a data)
   - **Horário** (ex: 19h)
   - **Tolerância** (ex: 15 minutos)
3. Confirma — a notificação vai pros alunos automaticamente.

**Treinos favoritos:** professor salva treinos recorrentes (ex: "Adulto Gi 19h") e lança com 1 toque, sem redigitar.

---

## O que o aluno vê

- Notificação na véspera (~18h): *"Vai treinar amanhã? Confirme aqui 👊"* com deep-link direto pra tela.
- Tela de pré-checkin: lista os treinos do dia/amanhã com horário; toca em **"Vou"** ou **"Não vou"**.
- Consegue ver **quem mais confirmou** (foto, nome, faixa, contagem) — prova social para motivar os indecisos.
- Pode **cancelar** a confirmação (enquanto a janela estiver aberta) — não conta como furão.
- No tatame: bate presença por câmera (face) ou QR como fallback.

---

## Link de aulas do dia pro WhatsApp

O professor toca em **"Compartilhar aulas de hoje"** e o app monta a mensagem pronta com um link. Quem receber:
- **Com o app instalado** → cai direto na tela de confirmação do dia.
- **Sem o app** → abre o site (octogrip.com.br) na mesma tela.

> Requer configuração de App Links (Android) / Universal Links (iOS) — tarefa de infra incluída na Fase 4.

---

## Modos de gate de presença (toggle por academia)

| Modo | Comportamento |
|---|---|
| **Flexível** (default) | Quem não confirmou ainda consegue bater presença no tatame normalmente. |
| **Estrito** | Sem pré-confirmação = sem presença (face/QR bloqueados com mensagem clara). |

- O professor escolhe o modo por academia.
- Em qualquer modo, **presença manual do professor sempre funciona** como override.

---

## Gate por assinatura

- `pre_checkin_enabled` (bool, default `false`) — **só o admin global edita**, igual ao `face_recognition_enabled`.
- `pre_checkin_strict` (bool, default `false`) — professor/gestor edita para o modo estrito.

O sistema fica invisível para academias sem a flag ligada.

---

## Furo inteligente + resumo pós-aula

Como o sistema sabe quem confirmou e quem realmente veio, o professor recebe ao encerrar a chamada:

- Quantos confirmaram.
- Quantos vieram.
- Quantos **confirmaram e furaram**.
- Quantos **vieram sem confirmar**.

É de graça — sai dos dados já coletados.

---

## Troféu de pontualidade

Confirmou + chegou dentro da janela **antes do início** = ponto de pontualidade que alimenta o sistema de gamificação existente (selos/troféus). Reforça chegar na hora sem punir presença.

---

## Dados novos (novos models)

### `TrainingSession` — o treino lançado pelo professor
| Campo | Tipo | Descrição |
|---|---|---|
| `academy_id` | FK | Academia |
| `created_by_user_id` | FK | Professor que lançou |
| `class_date` | date | Data do treino |
| `start_time` | time | Horário de início |
| `tolerance_minutes` | int | Tolerância após o início (ex: 15) |
| `label?` | str | Nome opcional (ex: "Adulto Gi") |
| `status` | enum | `upcoming`, `open`, `closed` |
| `opened_at?` | datetime | Quando o professor abriu a chamada |
| `closed_at?` | datetime | Quando fechou (manual ou automático) |
| `is_favorite_template` | bool | Se é um favorito salvo |

### `TrainingPreCheckin` — confirmação do aluno
| Campo | Tipo | Descrição |
|---|---|---|
| `training_session_id` | FK | Treino |
| `user_id` | FK | Aluno |
| `academy_id` | FK | Academia |
| `status` | enum | `confirmed`, `cancelled` |
| `confirmed_at?` | datetime | |
| `cancelled_at?` | datetime | |

Único por `(training_session_id, user_id)`.

`AttendanceSession` ganha `training_session_id?` (opcional, retrocompatível com a chamada avulsa que já existe).

---

## Endpoints novos (backend FastAPI)

**Treinos lançados**
- `POST /academies/{id}/training-sessions` — lança treino
- `GET /academies/{id}/training-sessions` — lista (filtros: data, status)
- `GET /academies/{id}/training-sessions/today` — aulas do dia (para o link do WhatsApp)
- `PATCH /training-sessions/{id}` — editar tolerância/horário (enquanto não abriu)
- `POST /training-sessions/{id}/open` — professor abre a chamada
- `POST /training-sessions/{id}/close` — professor fecha manualmente
- `DELETE /training-sessions/{id}` — cancelar treino

**Favoritos**
- `GET /academies/{id}/training-templates` — lista favoritos
- `POST /academies/{id}/training-templates` — salvar como favorito
- `DELETE /training-templates/{id}`

**Pré-checkin**
- `GET /training-sessions/{id}/pre-checkins` — quem confirmou (foto, nome, faixa)
- `POST /training-sessions/{id}/pre-checkin` — aluno confirma (idempotente)
- `DELETE /training-sessions/{id}/pre-checkin` — aluno cancela
- `GET /me/pre-checkins/upcoming` — meus treinos confirmados que ainda vêm

---

## Telas Flutter novas

| Tela | Quem usa | O que faz |
|---|---|---|
| `LaunchTrainingScreen` | Professor | Lança treino (3 campos + favoritos) |
| `TrainingSessionListScreen` | Professor | Aulas do dia com status + pré-lista |
| `PreCheckinScreen` | Aluno | Lista treinos do dia/amanhã, confirmar/cancelar, ver confirmados |
| Card na home do aluno | Aluno | "Treino amanhã 19h — confirmar" |
| Link web (octogrip.com.br) | Aluno sem app | Tela de confirmação via browser |

**Alterações em telas existentes:**
- `AttendanceSessionScreen` — seletor de `TrainingSession` ao iniciar + regra de gate (modo estrito)
- [academy_detail_screen.dart](../lib/screens/admin/academy_detail_screen.dart) — toggle `pre_checkin_enabled` (admin global)

---

## Push de lembrete

Task Celery `send_pre_checkin_reminder_push` (~18h Brasília, junto das tasks de streak):
- Academias com `pre_checkin_enabled = true`.
- Alunos ativos que **não confirmaram nada de amanhã**.
- Mensagem: *"Vai treinar amanhã? Confirme seus treinos 👊"* com deep-link.

---

## Fases de implementação

| Fase | Entrega | Depende de |
|---|---|---|
| **0** | Flags `pre_checkin_enabled` + `pre_checkin_strict` na Academy; toggle no admin; migration Alembic | — |
| **1** | `TrainingSession` + lançar treino + favoritos; tela `LaunchTrainingScreen` + lista | Fase 0 |
| **2** | `TrainingPreCheckin` + confirmar/cancelar + ver confirmados; `PreCheckinScreen` + card na home + notificação | Fase 1 |
| **3** | Abrir/fechar chamada pelo treino; regra de gate (estrito/flexível); badge "confirmou" na lista ao vivo | Fase 2 |
| **4** | Link de aulas do dia pro WhatsApp + App Links / Universal Links | Fase 1 |
| **5** | Furo inteligente + resumo pós-aula | Fase 3 |
| **6** | Troféu de pontualidade | Fase 3 |

Testes junto de cada fase (padrão do projeto).

---

## Notas importantes

- **Fuso horário:** `class_date`, corte de 30 min e task de push devem operar em horário de Brasília (America/Sao_Paulo). Cuidado com virada de dia.
- **LGPD:** nomes e fotos dos alunos ficam visíveis para membros da academia. Cobrir em uma linha da política de privacidade — não é dado biométrico, sem impacto no consentimento do face recognition.
- **Chamada avulsa existente:** `AttendanceSession` sem `training_session_id` continua funcionando normalmente. A feature nova é aditiva, não substitui.
- **Build / deploy:** não automático — implementar e avisar para testar.
