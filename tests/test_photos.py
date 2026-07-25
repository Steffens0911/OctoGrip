"""Testes dos endpoints OctoPhotos — GET/POST/DELETE feed, like, restrições."""

import io
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync
from app.models import Academy, User


@pytest.fixture(autouse=True)
def mock_photo_task():
    """Impede que process_photo_upload.delay tente conectar ao broker Celery nos testes."""
    mock_task = MagicMock()
    mock_task.delay = MagicMock(return_value=None)
    with patch("app.tasks.photo_tasks.process_photo_upload", mock_task):
        yield


# ─── helpers ────────────────────────────────────────────────────────────────


def _tiny_jpeg() -> bytes:
    """JPEG mínimo válido (10×10 px branco) para testes de upload."""
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (10, 10), color=(255, 255, 255)).save(buf, "JPEG")
    return buf.getvalue()


async def _make_academy(db: AsyncSession, *, octophotos: bool = False) -> Academy:
    a = Academy(
        name=f"Acad {uuid4().hex[:6]}",
        slug=f"acad-{uuid4().hex[:6]}",
        octophotos_enabled=octophotos,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


async def _make_user(
    db: AsyncSession,
    *,
    academy: Academy,
    role: str = "aluno",
) -> tuple[User, str]:
    u = User(
        email=f"{role}-{uuid4().hex[:8]}@test.com",
        name=f"{role.capitalize()} Teste",
        role=role,
        academy_id=academy.id,
        password_hash=hash_password_sync("pass1234"),
    )
    db.add(u)
    await db.commit()
    await db.refresh(u)
    return u, create_access_token(u.id)


# ─── feed ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_feed_sem_octophotos_retorna_403(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=False)
    _, token = await _make_user(db, academy=academy)

    r = await client.get(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_feed_vazio_com_octophotos(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)

    r = await client.get(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["items"] == []
    assert data["next_cursor"] is None


@pytest.mark.asyncio
async def test_feed_nao_membro_retorna_403(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    outra = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=outra)

    r = await client.get(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 403


# ─── criar post ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_criar_post_sucesso(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        data={"caption": "Treino pesado hoje!"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "processing"
    assert data["caption"] == "Treino pesado hoje!"
    assert data["is_system_post"] is False
    assert data["likes_count"] == 0


@pytest.mark.asyncio
async def test_criar_post_sem_octophotos_retorna_403(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=False)
    _, token = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_criar_post_tipo_invalido_retorna_403(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("arquivo.pdf", b"%PDF-1.4 fake", "application/pdf")},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_criar_post_caption_muito_longa(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        data={"caption": "x" * 281},
    )
    assert r.status_code == 403


# ─── @menções na legenda do post ──────────────────────────────────────────────


async def _notifications_for(db: AsyncSession, user_id, type_: str) -> list:
    """Busca notificações de um usuário por tipo."""
    from sqlalchemy import select

    from app.models import Notification

    result = await db.execute(select(Notification).where(Notification.user_id == user_id, Notification.type == type_))
    return list(result.scalars().all())


@pytest.mark.asyncio
async def test_criar_post_menciona_colega_gera_notificacao(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    autor, token = await _make_user(db, academy=academy)
    colega, _ = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        data={"caption": f"Rolando com @[{colega.name}|{colega.id}] hoje!"},
    )
    assert r.status_code == 201

    notifs = await _notifications_for(db, colega.id, "photo_mention")
    assert len(notifs) == 1
    assert notifs[0].title == f"{autor.name} te marcou em uma foto"
    # A tag @[Nome|uuid] é convertida para @Nome no corpo exibido
    assert "@[" not in notifs[0].body
    assert f"@{colega.name}" in notifs[0].body
    assert notifs[0].data["photo_id"] == r.json()["id"]


@pytest.mark.asyncio
async def test_criar_post_nao_notifica_o_proprio_autor(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    autor, token = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        data={"caption": f"Selfie pós-treino @[{autor.name}|{autor.id}]"},
    )
    assert r.status_code == 201

    notifs = await _notifications_for(db, autor.id, "photo_mention")
    assert notifs == []


@pytest.mark.asyncio
async def test_criar_post_sem_mencao_nao_gera_notificacao(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)
    colega, _ = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        data={"caption": "Treino leve hoje"},
    )
    assert r.status_code == 201

    notifs = await _notifications_for(db, colega.id, "photo_mention")
    assert notifs == []


# ─── like / unlike ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_like_unlike_ciclo(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    user, token = await _make_user(db, academy=academy)
    headers = {"Authorization": f"Bearer {token}"}

    # Cria post
    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers=headers,
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    assert r.status_code == 201
    photo_id = r.json()["id"]

    # Curtir
    r = await client.post(
        f"/academies/{academy.id}/photos/{photo_id}/like",
        headers=headers,
    )
    assert r.status_code == 204

    # liked_by_me é injetado dinamicamente (não usa cache) — deve ser True
    r = await client.get(f"/academies/{academy.id}/photos", headers=headers)
    item = next(p for p in r.json()["items"] if p["id"] == photo_id)
    assert item["liked_by_me"] is True
    # likes_count no feed pode estar cacheado; verifica no DB diretamente
    from sqlalchemy import text

    count_row = await db.execute(
        text("SELECT likes_count FROM academy_photos WHERE id = :pid"),
        {"pid": photo_id},
    )
    assert count_row.scalar_one() == 1

    # Descurtir
    r = await client.delete(
        f"/academies/{academy.id}/photos/{photo_id}/like",
        headers=headers,
    )
    assert r.status_code == 204

    # liked_by_me dinâmico deve voltar a False
    r = await client.get(f"/academies/{academy.id}/photos", headers=headers)
    item = next(p for p in r.json()["items"] if p["id"] == photo_id)
    assert item["liked_by_me"] is False
    # Confirma decremento no DB (feed pode ainda estar cacheado)
    count_row = await db.execute(
        text("SELECT likes_count FROM academy_photos WHERE id = :pid"),
        {"pid": photo_id},
    )
    assert count_row.scalar_one() == 0


# ─── deletar post ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_autor_pode_deletar_proprio_post(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)
    headers = {"Authorization": f"Bearer {token}"}

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers=headers,
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    photo_id = r.json()["id"]

    r = await client.delete(
        f"/academies/{academy.id}/photos/{photo_id}",
        headers=headers,
    )
    assert r.status_code == 204

    # Feed não exibe mais o post
    r = await client.get(f"/academies/{academy.id}/photos", headers=headers)
    ids = [p["id"] for p in r.json()["items"]]
    assert photo_id not in ids


@pytest.mark.asyncio
async def test_outro_aluno_nao_pode_deletar(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token_autor = await _make_user(db, academy=academy)
    _, token_outro = await _make_user(db, academy=academy)

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token_autor}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    photo_id = r.json()["id"]

    r = await client.delete(
        f"/academies/{academy.id}/photos/{photo_id}",
        headers={"Authorization": f"Bearer {token_outro}"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_gerente_pode_deletar_qualquer_post(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token_aluno = await _make_user(db, academy=academy)
    _, token_gerente = await _make_user(db, academy=academy, role="gerente_academia")

    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token_aluno}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    photo_id = r.json()["id"]

    r = await client.delete(
        f"/academies/{academy.id}/photos/{photo_id}",
        headers={"Authorization": f"Bearer {token_gerente}"},
    )
    assert r.status_code == 204


# ─── restrições ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_gerente_cria_restricao(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    aluno, _ = await _make_user(db, academy=academy)
    _, token_gerente = await _make_user(db, academy=academy, role="gerente_academia")

    r = await client.post(
        f"/academies/{academy.id}/photos/restrictions",
        headers={"Authorization": f"Bearer {token_gerente}"},
        json={"user_id": str(aluno.id), "reason": "Comportamento inadequado"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["user_id"] == str(aluno.id)
    assert data["active"] is True
    assert data["reason"] == "Comportamento inadequado"


@pytest.mark.asyncio
async def test_aluno_restrito_nao_pode_postar(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    aluno, token_aluno = await _make_user(db, academy=academy)
    _, token_gerente = await _make_user(db, academy=academy, role="gerente_academia")

    # Cria restrição
    await client.post(
        f"/academies/{academy.id}/photos/restrictions",
        headers={"Authorization": f"Bearer {token_gerente}"},
        json={"user_id": str(aluno.id)},
    )

    # Aluno tenta postar
    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token_aluno}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_gerente_inativa_restricao(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    aluno, token_aluno = await _make_user(db, academy=academy)
    _, token_gerente = await _make_user(db, academy=academy, role="gerente_academia")
    headers_g = {"Authorization": f"Bearer {token_gerente}"}

    # Cria restrição
    r = await client.post(
        f"/academies/{academy.id}/photos/restrictions",
        headers=headers_g,
        json={"user_id": str(aluno.id)},
    )
    restriction_id = r.json()["id"]

    # Inativa
    r = await client.patch(
        f"/academies/{academy.id}/photos/restrictions/{restriction_id}",
        headers=headers_g,
        json={"active": False},
    )
    assert r.status_code == 200
    assert r.json()["active"] is False

    # Agora o aluno consegue postar
    r = await client.post(
        f"/academies/{academy.id}/photos",
        headers={"Authorization": f"Bearer {token_aluno}"},
        files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
    )
    assert r.status_code == 201


@pytest.mark.asyncio
async def test_aluno_nao_ve_restricoes(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token_aluno = await _make_user(db, academy=academy)

    r = await client.get(
        f"/academies/{academy.id}/photos/restrictions",
        headers={"Authorization": f"Bearer {token_aluno}"},
    )
    assert r.status_code == 403


# ─── paginação cursor ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_paginacao_cursor(client: AsyncClient, db: AsyncSession):
    academy = await _make_academy(db, octophotos=True)
    _, token = await _make_user(db, academy=academy)
    headers = {"Authorization": f"Bearer {token}"}

    # Cria 3 posts
    ids_criados = []
    for _ in range(3):
        r = await client.post(
            f"/academies/{academy.id}/photos",
            headers=headers,
            files={"file": ("foto.jpg", _tiny_jpeg(), "image/jpeg")},
        )
        ids_criados.append(r.json()["id"])

    # Pega 2 por vez
    r = await client.get(
        f"/academies/{academy.id}/photos?limit=2",
        headers=headers,
    )
    data = r.json()
    assert len(data["items"]) == 2
    assert data["next_cursor"] is not None

    # Página 2
    r = await client.get(
        f"/academies/{academy.id}/photos?limit=2&cursor={data['next_cursor']}",
        headers=headers,
    )
    data2 = r.json()
    assert len(data2["items"]) == 1
    assert data2["next_cursor"] is None
