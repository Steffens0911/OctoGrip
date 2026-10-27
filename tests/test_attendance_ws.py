"""WebSocket da chamada em tempo real (/attendance/sessions/{id}/ws).

Regressão do Sentry OCTOGRIP-API-9: a dependência global de versão mínima pedia um
Request, que não existe numa conexão WebSocket, e toda abertura do socket quebrava com
"enforce_min_app_version() missing 1 required positional argument: 'request'".
"""

from uuid import uuid4

import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app


def test_ws_reaches_route_and_rejects_invalid_token():
    # Sem `with`: não dispara o lifespan da app. Token inválido fecha antes de tocar no banco.
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect(f"/attendance/sessions/{uuid4()}/ws?token=token-invalido-123") as ws:
            ws.receive_text()
    assert exc.value.code == 4001
