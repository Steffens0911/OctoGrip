# Presença (QR) — WebSocket em tempo real

## Visão geral

O fluxo de chamada por QR continua a usar as rotas REST existentes (`POST /attendance/sessions`, `GET .../qr`, `POST /attendance/scan`, etc.). Para o professor ver **presenças ao vivo** sem depender só do polling lento, existe um canal WebSocket que emite um evento sempre que um aluno faz um **novo** check-in (duplicatas no mesmo scan não emitem evento).

## Endpoint WebSocket

- **URL**: `WS` ou `WSS` + mesmo host/path base da API +  
  `/attendance/sessions/{session_id}/ws?token=<JWT>`
- **Query `token`**: JWT de acesso (mesmo valor do header `Authorization: Bearer ...`, **sem** o prefixo `Bearer `). Os browsers não enviam headers customizáveis em WebSocket da mesma forma que `http`; por isso o token vai na query.
- **Quem pode conectar**: `administrador`, `gerente_academia` ou `professor`. O utilizador tem de ter acesso à academia da sessão (regra igual às rotas REST).

## Eventos enviados pelo servidor

JSON em texto (uma mensagem por evento):

```json
{
  "type": "checkin",
  "session_id": "<uuid>",
  "record": {
    "id": "<uuid>",
    "session_id": "<uuid>",
    "user_id": "<uuid>",
    "checked_in_at": "2026-04-26T00:00:00+00:00",
    "method": "qr"
  },
  "present_count": 12
}
```

O evento só é emitido quando o `POST /attendance/scan` **cria** um novo registo de presença (não quando o aluno reenvia o mesmo scan e o servidor devolve o registo existente). O mesmo evento é emitido quando um professor adiciona presença manual (`POST /attendance/sessions/{id}/records`) e o registo é novo.

Após `DELETE /attendance/records/{record_id}`, o servidor envia `type: "record_removed"` com `record_id`, `user_id`, `session_id` e `present_count` atualizado — ver [ATTENDANCE_EDITING.md](./ATTENDANCE_EDITING.md).

## Implementação no backend

- `app/services/attendance_realtime.py` — `AttendanceConnectionManager` (conexões **em memória** no processo Uvicorn).
- `app/routes/attendance.py` — rota WebSocket + `broadcast` após scan com `created=True`.

**Escalabilidade**: com vários workers Uvicorn, cada processo tem o seu próprio conjunto de sockets; use Redis pub/sub (ou similar) para broadcast entre workers, se necessário.

## Implementação no Flutter

- `viewer/lib/services/attendance_live_service.dart` — liga ao WS com reconexão exponencial (1s → 30s).
- `viewer/lib/screens/academy/attendance_session_screen.dart` — subscreve o stream ao iniciar a sessão; encerra em `dispose` e ao fechar a chamada. Mantém polling HTTP a cada **15s** como rede de segurança.

## Dependência

- `web_socket_channel` no `viewer/pubspec.yaml`.
