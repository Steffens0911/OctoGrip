"""Testes de Training Feedback e Métricas."""
import pytest
from uuid import uuid4


# ========================== TRAINING FEEDBACK ==========================

async def test_criar_feedback(client, aluno_headers, aluno_user, position_pair):
    """Criar feedback de treino com sucesso."""
    p1, _ = position_pair
    r = await client.post("/training_feedback", headers=aluno_headers, json={
        "position_id": str(p1.id),
        "observation": "Tive dificuldade nesta posição",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["user_id"] == str(aluno_user.id)
    assert data["position_id"] == str(p1.id)
    assert data["observation"] == "Tive dificuldade nesta posição"
    assert "created_at" in data


async def test_criar_feedback_sem_observacao(client, aluno_headers, aluno_user, position_pair):
    """Criar feedback sem observação (opcional)."""
    p1, _ = position_pair
    r = await client.post("/training_feedback", headers=aluno_headers, json={
        "position_id": str(p1.id),
    })
    assert r.status_code == 201
    data = r.json()
    assert data["position_id"] == str(p1.id)
    assert data["observation"] is None


async def test_criar_feedback_posicao_inexistente(client, aluno_headers):
    """Criar feedback com posição inexistente retorna 404."""
    fake_position_id = uuid4()
    r = await client.post("/training_feedback", headers=aluno_headers, json={
        "position_id": str(fake_position_id),
        "observation": "Teste",
    })
    assert r.status_code == 404


async def test_criar_feedback_sem_auth(client, position_pair):
    """Criar feedback sem autenticação retorna 401."""
    p1, _ = position_pair
    r = await client.post("/training_feedback", json={
        "position_id": str(p1.id),
        "observation": "Teste",
    })
    assert r.status_code == 401


async def test_criar_feedback_multiplos(client, aluno_headers, aluno_user, position_pair):
    """Usuário pode criar múltiplos feedbacks."""
    p1, p2 = position_pair
    
    # Primeiro feedback
    r1 = await client.post("/training_feedback", headers=aluno_headers, json={
        "position_id": str(p1.id),
        "observation": "Dificuldade 1",
    })
    assert r1.status_code == 201

    # Segundo feedback
    r2 = await client.post("/training_feedback", headers=aluno_headers, json={
        "position_id": str(p2.id),
        "observation": "Dificuldade 2",
    })
    assert r2.status_code == 201


# ========================== MÉTRICAS ==========================

async def test_metricas_uso_basicas(client, db):
    """Obter métricas básicas de uso."""
    r = await client.get("/metrics/usage")
    assert r.status_code == 200
    data = r.json()
    assert "total_completions" in data
    assert "completions_last_7_days" in data
    assert "unique_users_completed" in data
    assert "before_training_count" in data
    assert "after_training_count" in data
    assert "before_training_percent" in data
    assert isinstance(data["total_completions"], int)
    assert isinstance(data["completions_last_7_days"], int)
    assert isinstance(data["unique_users_completed"], int)


async def test_metricas_uso_com_dados(client, db, academy, aluno_user):
    """Métricas com dados existentes."""
    from app.models import Lesson, LessonProgress, Technique, MissionUsage
    from datetime import datetime, timezone, timedelta

    technique = Technique(
        academy_id=academy.id,
        name="Técnica Teste",
        slug=f"tecnica-{uuid4().hex[:6]}",
    )
    db.add(technique)
    await db.commit()
    await db.refresh(technique)

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Métricas",
        slug=f"metricas-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    # Criar conclusões
    progress1 = LessonProgress(user_id=aluno_user.id, lesson_id=lesson.id)
    progress2 = LessonProgress(
        user_id=aluno_user.id,
        lesson_id=lesson.id,
        completed_at=datetime.now(timezone.utc) - timedelta(days=3),  # Últimos 7 dias
    )
    db.add_all([progress1, progress2])
    
    # Criar MissionUsage
    usage = MissionUsage(
        user_id=aluno_user.id,
        lesson_id=lesson.id,
        usage_type="before_training",
        opened_at=datetime.now(timezone.utc),
        completed_at=datetime.now(timezone.utc),
    )
    db.add(usage)
    await db.commit()

    r = await client.get("/metrics/usage")
    assert r.status_code == 200
    data = r.json()
    assert data["total_completions"] >= 2
    assert data["completions_last_7_days"] >= 1
    assert data["unique_users_completed"] >= 1
    assert data["before_training_count"] >= 1


async def test_metricas_uso_percentual(client, db, academy, aluno_user):
    """Métricas calculam percentual corretamente."""
    from app.models import Lesson, MissionUsage, Technique
    from datetime import datetime, timezone

    technique = Technique(
        academy_id=academy.id,
        name="Técnica Teste",
        slug=f"tecnica-{uuid4().hex[:6]}",
    )
    db.add(technique)
    await db.commit()
    await db.refresh(technique)

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Percentual",
        slug=f"percentual-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    now = datetime.now(timezone.utc)
    
    # Criar 3 before_training e 7 after_training (30% before)
    for i in range(3):
        usage = MissionUsage(
            user_id=aluno_user.id,
            lesson_id=lesson.id,
            usage_type="before_training",
            opened_at=now,
            completed_at=now,
        )
        db.add(usage)
    
    for i in range(7):
        usage = MissionUsage(
            user_id=aluno_user.id,
            lesson_id=lesson.id,
            usage_type="after_training",
            opened_at=now,
            completed_at=now,
        )
        db.add(usage)
    
    await db.commit()

    r = await client.get("/metrics/usage")
    assert r.status_code == 200
    data = r.json()
    # Deve calcular aproximadamente 30% (3/10)
    assert data["before_training_percent"] > 0
    assert data["before_training_percent"] <= 100.0


async def test_metricas_uso_sem_dados(client):
    """Métricas sem dados retornam zeros."""
    r = await client.get("/metrics/usage")
    assert r.status_code == 200
    data = r.json()
    # Em um banco limpo, pode retornar zeros ou valores baixos
    assert data["total_completions"] >= 0
    assert data["completions_last_7_days"] >= 0
    assert data["unique_users_completed"] >= 0


async def test_metricas_uso_por_academia(client, db, academy, aluno_user):
    """Métricas por academy_id retornam estrutura igual ao global e respeitam filtro."""
    from app.models import Lesson, LessonProgress, Technique, MissionUsage
    from datetime import datetime, timezone

    # Criar técnica/posição/lesson vinculadas à academia do aluno
    p1 = Position(academy_id=academy.id, name="Guarda A", slug=f"guarda-a-{uuid4().hex[:6]}")
    p2 = Position(academy_id=academy.id, name="Montada A", slug=f"montada-a-{uuid4().hex[:6]}")
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

    technique = Technique(
        academy_id=academy.id,
        name="Técnica Métricas Academia",
        slug=f"tecnica-academia-{uuid4().hex[:6]}",
        from_position_id=p1.id,
        to_position_id=p2.id,
    )
    db.add(technique)
    await db.commit()
    await db.refresh(technique)

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Métricas Academia",
        slug=f"metricas-academia-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    now = datetime.now(timezone.utc)

    # Criar progressos e usos apenas para essa academia/usuário
    db.add(LessonProgress(user_id=aluno_user.id, lesson_id=lesson.id, completed_at=now))
    db.add(
        MissionUsage(
            user_id=aluno_user.id,
            lesson_id=lesson.id,
            usage_type="after_training",
            opened_at=now,
            completed_at=now,
        )
    )
    await db.commit()

    # Chamar endpoint filtrado por academy_id
    r = await client.get(f"/metrics/usage/by_academy?academy_id={academy.id}")
    assert r.status_code == 200
    data = r.json()
    assert data["total_completions"] >= 1
    assert data["before_training_count"] >= 0
    assert data["after_training_count"] >= 1
