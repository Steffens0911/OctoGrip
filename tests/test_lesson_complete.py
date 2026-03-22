"""Testes de conclusão de lição."""
import pytest
from uuid import uuid4


@pytest.fixture
async def lesson(db, technique):
    """Cria uma lição para testes."""
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Teste",
        slug=f"licao-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return lesson


async def test_status_licao_nao_concluida(client, aluno_headers, lesson):
    """Verificar status de lição não concluída retorna completed=False."""
    r = await client.get(f"/lesson_complete/status?lesson_id={lesson.id}", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["completed"] is False


async def test_status_licao_concluida(client, aluno_headers, aluno_user, lesson, db):
    """Verificar status de lição concluída retorna completed=True."""
    from app.models import LessonProgress

    # Completar lição primeiro
    progress = LessonProgress(user_id=aluno_user.id, lesson_id=lesson.id)
    db.add(progress)
    await db.commit()

    r = await client.get(f"/lesson_complete/status?lesson_id={lesson.id}", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["completed"] is True


async def test_status_licao_inexistente(client, aluno_headers):
    """Lição inexistente: status retorna completed=False (sem validar existência da lição)."""
    fake_lesson_id = uuid4()
    r = await client.get(f"/lesson_complete/status?lesson_id={fake_lesson_id}", headers=aluno_headers)
    assert r.status_code == 200
    assert r.json()["completed"] is False


async def test_status_licao_sem_auth(client, lesson):
    """Verificar status sem autenticação retorna 401."""
    r = await client.get(f"/lesson_complete/status?lesson_id={lesson.id}")
    assert r.status_code == 401


async def test_completar_licao(client, aluno_headers, aluno_user, lesson):
    """Completar lição com sucesso."""
    r = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r.status_code == 201
    data = r.json()
    assert data["user_id"] == str(aluno_user.id)
    assert data["lesson_id"] == str(lesson.id)
    assert "completed_at" in data


async def test_completar_licao_duplicada(client, aluno_headers, aluno_user, lesson):
    """Tentar completar lição duas vezes retorna 409."""
    # Primeira conclusão
    r1 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r1.status_code == 201

    # Segunda conclusão (deve falhar)
    r2 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r2.status_code == 409


async def test_completar_licao_inexistente(client, aluno_headers):
    """Completar lição inexistente retorna 404."""
    fake_lesson_id = uuid4()
    r = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(fake_lesson_id),
    })
    assert r.status_code == 404


async def test_completar_licao_sem_auth(client, lesson):
    """Completar lição sem autenticação retorna 401."""
    r = await client.post("/lesson_complete", json={
        "lesson_id": str(lesson.id),
    })
    assert r.status_code == 401


async def test_completar_licao_multiplos_usuarios(client, db, lesson, technique):
    """Múltiplos usuários podem completar a mesma lição."""
    from app.models import User
    from app.core.security import create_access_token, hash_password_sync

    # Mesma academia da técnica/lição (obrigatório para alunos)
    aid = technique.academy_id

    # Criar dois usuários
    user1 = User(
        email=f"aluno1-{uuid4().hex[:8]}@test.com",
        name="Aluno 1",
        role="aluno",
        graduation="white",
        academy_id=aid,
        password_hash=hash_password_sync("aluno123"),
    )
    user2 = User(
        email=f"aluno2-{uuid4().hex[:8]}@test.com",
        name="Aluno 2",
        role="aluno",
        graduation="white",
        academy_id=aid,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add_all([user1, user2])
    await db.commit()
    await db.refresh(user1)
    await db.refresh(user2)

    headers1 = {"Authorization": f"Bearer {create_access_token(user1.id)}"}
    headers2 = {"Authorization": f"Bearer {create_access_token(user2.id)}"}

    # Primeiro usuário completa
    r1 = await client.post("/lesson_complete", headers=headers1, json={
        "lesson_id": str(lesson.id),
    })
    assert r1.status_code == 201

    # Segundo usuário também pode completar
    r2 = await client.post("/lesson_complete", headers=headers2, json={
        "lesson_id": str(lesson.id),
    })
    assert r2.status_code == 201


async def test_status_apos_completar(client, aluno_headers, aluno_user, lesson):
    """Status deve mudar para True após completar."""
    # Verificar que não está concluída
    r1 = await client.get(f"/lesson_complete/status?lesson_id={lesson.id}", headers=aluno_headers)
    assert r1.json()["completed"] is False

    # Completar
    r2 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r2.status_code == 201

    # Verificar que agora está concluída
    r3 = await client.get(f"/lesson_complete/status?lesson_id={lesson.id}", headers=aluno_headers)
    assert r3.json()["completed"] is True
