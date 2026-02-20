"""Testes de sync e histórico de Mission Usages."""
import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4


@pytest.fixture
async def lesson_para_sync(db, technique):
    """Cria uma lição para testes de sync."""
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Sync",
        slug=f"sync-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return lesson


async def test_sync_mission_usages(client, aluno_headers, aluno_user, lesson_para_sync):
    """Sync de usos de missão com sucesso."""
    now = datetime.now(timezone.utc)
    r = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })
    assert r.status_code == 200
    data = r.json()
    assert data["synced"] == 1
    assert "message" in data


async def test_sync_mission_usages_multiplos(client, aluno_headers, aluno_user, lesson_para_sync, db):
    """Sync de múltiplos usos."""
    from app.models import Lesson

    lesson2 = Lesson(
        technique_id=lesson_para_sync.technique_id,
        title="Lição 2",
        slug=f"licao2-{uuid4().hex[:6]}",
        order_index=1,
    )
    db.add(lesson2)
    await db.commit()
    await db.refresh(lesson2)

    now = datetime.now(timezone.utc)
    r = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [
            {
                "lesson_id": str(lesson_para_sync.id),
                "opened_at": now.isoformat(),
                "completed_at": now.isoformat(),
                "usage_type": "after_training",
            },
            {
                "lesson_id": str(lesson2.id),
                "opened_at": (now + timedelta(hours=1)).isoformat(),
                "completed_at": (now + timedelta(hours=1)).isoformat(),
                "usage_type": "before_training",
            },
        ],
    })
    assert r.status_code == 200
    data = r.json()
    assert data["synced"] == 2


async def test_sync_mission_usages_duplicado(client, aluno_headers, aluno_user, lesson_para_sync):
    """Sync ignora duplicatas (mesmo lesson_id e completed_at)."""
    now = datetime.now(timezone.utc)
    
    # Primeiro sync
    r1 = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })
    assert r1.status_code == 200
    assert r1.json()["synced"] == 1

    # Segundo sync com mesmo completed_at (deve ignorar)
    r2 = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),  # Mesmo completed_at
            "usage_type": "after_training",
        }],
    })
    assert r2.status_code == 200
    assert r2.json()["synced"] == 0  # Duplicata ignorada


async def test_sync_mission_usages_licao_inexistente(client, aluno_headers):
    """Sync ignora lições inexistentes."""
    fake_lesson_id = uuid4()
    now = datetime.now(timezone.utc)
    r = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(fake_lesson_id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })
    assert r.status_code == 200
    data = r.json()
    assert data["synced"] == 0  # Lição inexistente ignorada


async def test_sync_mission_usages_sem_lesson_id(client, aluno_headers):
    """Sync ignora usos sem lesson_id."""
    now = datetime.now(timezone.utc)
    r = await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
            # Sem lesson_id
        }],
    })
    assert r.status_code == 200
    data = r.json()
    assert data["synced"] == 0


async def test_sync_mission_usages_sem_auth(client, lesson_para_sync):
    """Sync sem autenticação retorna 401."""
    now = datetime.now(timezone.utc)
    r = await client.post("/mission_usages/sync", json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })
    assert r.status_code == 401


async def test_historico_mission_usages(client, aluno_headers, aluno_user, lesson_para_sync):
    """Obter histórico de missões."""
    # Primeiro fazer sync para ter dados
    now = datetime.now(timezone.utc)
    await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })

    r = await client.get("/mission_usages/history", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert "missions" in data
    assert isinstance(data["missions"], list)
    assert len(data["missions"]) >= 1


async def test_historico_mission_usages_com_limit(client, aluno_headers, aluno_user, lesson_para_sync, db):
    """Histórico respeita limite."""
    from app.models import Lesson

    # Criar múltiplas lições e fazer sync
    lessons = []
    for i in range(5):
        lesson = Lesson(
            technique_id=lesson_para_sync.technique_id,
            title=f"Lição {i}",
            slug=f"licao{i}-{uuid4().hex[:6]}",
            order_index=i,
        )
        db.add(lesson)
        lessons.append(lesson)
    await db.commit()
    for lesson in lessons:
        await db.refresh(lesson)

    # Sync de todas
    now = datetime.now(timezone.utc)
    usages = [{
        "lesson_id": str(lesson.id),
        "opened_at": (now + timedelta(hours=i)).isoformat(),
        "completed_at": (now + timedelta(hours=i)).isoformat(),
        "usage_type": "after_training",
    } for i, lesson in enumerate(lessons)]

    await client.post("/mission_usages/sync", headers=aluno_headers, json={"usages": usages})

    # Buscar histórico com limit=3
    r = await client.get("/mission_usages/history?limit=3", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data["missions"]) <= 3


async def test_historico_mission_usages_limit_maximo(client, aluno_headers):
    """Histórico respeita limite máximo de 500."""
    r = await client.get("/mission_usages/history?limit=1000", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    # Deve retornar no máximo 500 itens
    assert len(data["missions"]) <= 500


async def test_historico_mission_usages_vazio(client, aluno_headers):
    """Histórico vazio retorna lista vazia."""
    r = await client.get("/mission_usages/history", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["missions"] == []


async def test_historico_mission_usages_sem_auth(client):
    """Histórico sem autenticação retorna 401."""
    r = await client.get("/mission_usages/history")
    assert r.status_code == 401


async def test_historico_mission_usages_ordenado_por_data(client, aluno_headers, aluno_user, lesson_para_sync, db):
    """Histórico ordenado por data (mais recente primeiro)."""
    from app.models import Lesson

    lesson2 = Lesson(
        technique_id=lesson_para_sync.technique_id,
        title="Lição Antiga",
        slug=f"antiga-{uuid4().hex[:6]}",
        order_index=1,
    )
    db.add(lesson2)
    await db.commit()
    await db.refresh(lesson2)

    now = datetime.now(timezone.utc)
    
    # Sync lição mais antiga primeiro
    await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson2.id),
            "opened_at": (now - timedelta(hours=2)).isoformat(),
            "completed_at": (now - timedelta(hours=2)).isoformat(),
            "usage_type": "after_training",
        }],
    })

    # Sync lição mais recente depois
    await client.post("/mission_usages/sync", headers=aluno_headers, json={
        "usages": [{
            "lesson_id": str(lesson_para_sync.id),
            "opened_at": now.isoformat(),
            "completed_at": now.isoformat(),
            "usage_type": "after_training",
        }],
    })

    r = await client.get("/mission_usages/history", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data["missions"]) >= 2
    # Primeira deve ser a mais recente
    assert data["missions"][0]["lesson_title"] == "Lição Sync"
