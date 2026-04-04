"""Testes de Training Feedback e Métricas."""
from uuid import uuid4


# ========================== TRAINING FEEDBACK ==========================


async def test_criar_feedback(client, aluno_headers, aluno_user):
    """Criar feedback de treino com sucesso (sem position_id)."""
    r = await client.post(
        "/training_feedback",
        headers=aluno_headers,
        json={"observation": "Tive dificuldade nesta posição"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["user_id"] == str(aluno_user.id)
    assert data["observation"] == "Tive dificuldade nesta posição"
    assert "created_at" in data


async def test_criar_feedback_sem_observacao(client, aluno_headers, aluno_user):
    """Criar feedback sem observação (opcional)."""
    r = await client.post("/training_feedback", headers=aluno_headers, json={})
    assert r.status_code == 201
    data = r.json()
    assert data["observation"] is None


async def test_criar_feedback_sem_auth(client):
    """Criar feedback sem autenticação retorna 401."""
    r = await client.post(
        "/training_feedback",
        json={"observation": "Teste"},
    )
    assert r.status_code == 401


async def test_criar_feedback_multiplos(client, aluno_headers, aluno_user):
    """Usuário pode criar múltiplos feedbacks."""
    r1 = await client.post(
        "/training_feedback",
        headers=aluno_headers,
        json={"observation": "Dificuldade 1"},
    )
    assert r1.status_code == 201

    r2 = await client.post(
        "/training_feedback",
        headers=aluno_headers,
        json={"observation": "Dificuldade 2"},
    )
    assert r2.status_code == 201


# ========================== MÉTRICAS ==========================


async def test_metricas_uso_basicas(client, db, admin_headers):
    """Obter métricas básicas de uso."""
    r = await client.get("/metrics/usage", headers=admin_headers)
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


async def test_metricas_uso_com_dados(client, db, academy, aluno_user, admin_headers):
    """Métricas com dados existentes."""
    from app.models import Lesson, LessonProgress, MissionUsage, Technique
    from datetime import datetime, timezone, timedelta

    technique = Technique(
        academy_id=academy.id,
        name="Técnica Teste",
        slug=f"tecnica-{uuid4().hex[:6]}",
    )
    db.add(technique)
    await db.commit()
    await db.refresh(technique)

    lesson1 = Lesson(
        technique_id=technique.id,
        title="Lição Métricas 1",
        slug=f"metricas-1-{uuid4().hex[:6]}",
        order_index=0,
    )
    lesson2 = Lesson(
        technique_id=technique.id,
        title="Lição Métricas 2",
        slug=f"metricas-2-{uuid4().hex[:6]}",
        order_index=1,
    )
    db.add_all([lesson1, lesson2])
    await db.commit()
    await db.refresh(lesson1)
    await db.refresh(lesson2)

    progress1 = LessonProgress(user_id=aluno_user.id, lesson_id=lesson1.id)
    progress2 = LessonProgress(
        user_id=aluno_user.id,
        lesson_id=lesson2.id,
        completed_at=datetime.now(timezone.utc) - timedelta(days=3),
    )
    db.add_all([progress1, progress2])

    usage = MissionUsage(
        user_id=aluno_user.id,
        lesson_id=lesson1.id,
        usage_type="before_training",
        opened_at=datetime.now(timezone.utc),
        completed_at=datetime.now(timezone.utc),
    )
    db.add(usage)
    await db.commit()

    r = await client.get("/metrics/usage", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["total_completions"] >= 2
    assert data["completions_last_7_days"] >= 1
    assert data["unique_users_completed"] >= 1
    assert data["before_training_count"] >= 1


async def test_metricas_uso_percentual(client, db, academy, aluno_user, admin_headers):
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

    for _ in range(3):
        usage = MissionUsage(
            user_id=aluno_user.id,
            lesson_id=lesson.id,
            usage_type="before_training",
            opened_at=now,
            completed_at=now,
        )
        db.add(usage)

    for _ in range(7):
        usage = MissionUsage(
            user_id=aluno_user.id,
            lesson_id=lesson.id,
            usage_type="after_training",
            opened_at=now,
            completed_at=now,
        )
        db.add(usage)

    await db.commit()

    r = await client.get("/metrics/usage", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["before_training_percent"] > 0
    assert data["before_training_percent"] <= 100.0


async def test_metricas_uso_sem_dados(client, admin_headers):
    """Métricas sem dados retornam zeros."""
    r = await client.get("/metrics/usage", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["total_completions"] >= 0
    assert data["completions_last_7_days"] >= 0
    assert data["unique_users_completed"] >= 0


async def test_metricas_uso_por_academia(client, db, academy, aluno_user, admin_headers):
    """Métricas por academy_id retornam estrutura igual ao global e respeitam filtro."""
    from app.models import Lesson, LessonProgress, MissionUsage, Technique
    from datetime import datetime, timezone

    technique = Technique(
        academy_id=academy.id,
        name="Técnica Métricas Academia",
        slug=f"tecnica-academia-{uuid4().hex[:6]}",
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

    r = await client.get(
        f"/metrics/usage/by_academy?academy_id={academy.id}",
        headers=admin_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total_completions"] >= 1
    assert data["before_training_count"] >= 0
    assert data["after_training_count"] >= 1
