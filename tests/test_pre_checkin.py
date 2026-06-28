"""
Testes do sistema de pré-checkin: confirm/cancel, status, furo inteligente.
"""

from datetime import date, timedelta
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync

# ---------------------------------------------------------------------------
# Fixtures locais
# ---------------------------------------------------------------------------


@pytest.fixture
async def pce_academy(db: AsyncSession):
    """Academia com pré-checkin habilitado."""
    from app.models import Academy

    a = Academy(
        name=f"Academia PCE {uuid4().hex[:6]}",
        slug=f"pce-{uuid4().hex[:6]}",
        pre_checkin_enabled=True,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


@pytest.fixture
async def pce_professor(db: AsyncSession, pce_academy):
    from app.models import User

    user = User(
        email=f"prof-pce-{uuid4().hex[:8]}@test.com",
        name="Prof PCE",
        role="professor",
        graduation="black",
        academy_id=pce_academy.id,
        password_hash=hash_password_sync("prof1234"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
async def pce_aluno(db: AsyncSession, pce_academy):
    from app.models import User

    user = User(
        email=f"aluno-pce-{uuid4().hex[:8]}@test.com",
        name="Aluno PCE",
        role="aluno",
        graduation="white",
        academy_id=pce_academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
async def pce_aluno2(db: AsyncSession, pce_academy):
    from app.models import User

    user = User(
        email=f"aluno2-pce-{uuid4().hex[:8]}@test.com",
        name="Aluno PCE 2",
        role="aluno",
        graduation="blue",
        academy_id=pce_academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
def pce_prof_headers(pce_professor):
    return {"Authorization": f"Bearer {create_access_token(pce_professor.id)}"}


@pytest.fixture
def pce_aluno_headers(pce_aluno):
    return {"Authorization": f"Bearer {create_access_token(pce_aluno.id)}"}


@pytest.fixture
def pce_aluno2_headers(pce_aluno2):
    return {"Authorization": f"Bearer {create_access_token(pce_aluno2.id)}"}


@pytest.fixture
async def pce_session(db: AsyncSession, pce_academy, pce_professor):
    """Sessão de treino upcoming com data 3 dias no futuro (janela aberta)."""
    from app.models.training_session import TrainingSession

    s = TrainingSession(
        academy_id=pce_academy.id,
        created_by_user_id=pce_professor.id,
        class_date=date.today() + timedelta(days=3),
        start_time="22:00",  # 22h local → corta às 21h30 → janela aberta agora
        tolerance_minutes=15,
        status="upcoming",
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return s


@pytest.fixture
async def pce_session_passado(db: AsyncSession, pce_academy, pce_professor):
    """Sessão com data ontem (janela de confirmação fechada)."""
    from app.models.training_session import TrainingSession

    s = TrainingSession(
        academy_id=pce_academy.id,
        created_by_user_id=pce_professor.id,
        class_date=date.today() - timedelta(days=1),
        start_time="19:00",
        tolerance_minutes=15,
        status="upcoming",
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return s


# ---------------------------------------------------------------------------
# Criar sessão via API
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_criar_sessao_requer_pre_checkin_habilitado(client, professor_headers):
    """Academia sem pré-checkin retorna 403 ao criar sessão."""
    r = await client.post(
        f"/academies/{uuid4()}/training-sessions",
        json={
            "class_date": str(date.today() + timedelta(days=1)),
            "start_time": "19:00",
            "tolerance_minutes": 15,
        },
        headers=professor_headers,
    )
    # Academy inexistente → 404 ou academy sem pre_checkin_enabled → 403
    assert r.status_code in (403, 404)


@pytest.mark.asyncio
async def test_criar_sessao_com_pre_checkin_habilitado(
    client, pce_academy, pce_prof_headers
):
    """Professor cria sessão de treino quando academia tem pré-checkin habilitado."""
    class_date = str(date.today() + timedelta(days=2))
    r = await client.post(
        f"/academies/{pce_academy.id}/training-sessions",
        json={
            "class_date": class_date,
            "start_time": "19:00",
            "tolerance_minutes": 15,
            "label": "Adulto GI",
        },
        headers=pce_prof_headers,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["class_date"] == class_date
    assert data["start_time"] == "19:00"
    assert data["label"] == "Adulto GI"
    assert data["status"] == "upcoming"
    assert data["pre_checkin_count"] == 0


# ---------------------------------------------------------------------------
# Confirm / Cancel
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_aluno_confirma_pre_checkin(client, pce_session, pce_aluno_headers):
    """Aluno confirma presença antecipada."""
    r = await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "confirmed"
    assert data["training_session_id"] == str(pce_session.id)


@pytest.mark.asyncio
async def test_confirmacao_idempotente(client, pce_session, pce_aluno_headers):
    """Segunda confirmação não cria duplicata — retorna o mesmo registro."""
    r1 = await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    r2 = await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    assert r1.status_code == 201
    assert r2.status_code == 201
    assert r1.json()["id"] == r2.json()["id"]


@pytest.mark.asyncio
async def test_aluno_cancela_pre_checkin(client, pce_session, pce_aluno_headers):
    """Aluno cancela após confirmar."""
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    r = await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/cancel",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "cancelled"


@pytest.mark.asyncio
async def test_cancelar_sem_confirmacao_retorna_404(
    client, pce_session, pce_aluno_headers
):
    """Cancelar sem ter confirmado antes retorna 404."""
    r = await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/cancel",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_janela_fechada_nao_permite_confirmar(
    client, pce_session_passado, pce_aluno_headers
):
    """Não é possível confirmar após o prazo (30 min antes do treino)."""
    r = await client.post(
        f"/academies/training-sessions/{pce_session_passado.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 403
    assert "prazo" in r.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Status (GET)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_status_sem_confirmacao(client, pce_session, pce_aluno_headers):
    """Status inicial: sem confirmação, lista de confirmantes vazia."""
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] is None
    assert data["pre_checkin_id"] is None
    assert data["total_confirmed"] == 0
    assert data["confirmants"] == []


@pytest.mark.asyncio
async def test_status_apos_confirmacao(
    client, pce_session, pce_aluno, pce_aluno_headers
):
    """Status após confirmar: status=confirmed, aparece na lista."""
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "confirmed"
    assert data["total_confirmed"] == 1
    assert len(data["confirmants"]) == 1
    assert data["confirmants"][0]["name"] == pce_aluno.name


@pytest.mark.asyncio
async def test_status_mostra_todos_confirmantes(
    client,
    pce_session,
    pce_aluno,
    pce_aluno2,
    pce_aluno_headers,
    pce_aluno2_headers,
):
    """Dois alunos confirmam; status de qualquer um mostra a lista completa."""
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno2_headers,
    )
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total_confirmed"] == 2
    nomes = {c["name"] for c in data["confirmants"]}
    assert pce_aluno.name in nomes
    assert pce_aluno2.name in nomes


@pytest.mark.asyncio
async def test_status_apos_cancelamento(client, pce_session, pce_aluno_headers):
    """Após cancelar, status=cancelled e não aparece na lista de confirmados."""
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/cancel",
        headers=pce_aluno_headers,
    )
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "cancelled"
    assert data["total_confirmed"] == 0
    assert data["confirmants"] == []


# ---------------------------------------------------------------------------
# pre_checkin_count no GET /training-sessions
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_pre_checkin_count_atualiza_apos_confirmacao(
    client, pce_academy, pce_session, pce_aluno_headers, pce_prof_headers
):
    """pre_checkin_count na listagem reflete o número de confirmados."""
    r_before = await client.get(
        f"/academies/{pce_academy.id}/training-sessions",
        headers=pce_prof_headers,
    )
    assert r_before.status_code == 200
    count_before = next(
        s["pre_checkin_count"]
        for s in r_before.json()
        if str(s["id"]) == str(pce_session.id)
    )
    assert count_before == 0

    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )

    r_after = await client.get(
        f"/academies/{pce_academy.id}/training-sessions",
        headers=pce_prof_headers,
    )
    count_after = next(
        s["pre_checkin_count"]
        for s in r_after.json()
        if str(s["id"]) == str(pce_session.id)
    )
    assert count_after == 1


# ---------------------------------------------------------------------------
# Resumo (furo inteligente)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_resumo_sem_dados(client, pce_session, pce_prof_headers):
    """Resumo de sessão sem pré-checkins nem presenças."""
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/summary",
        headers=pce_prof_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total_pre_confirmed"] == 0
    assert data["total_attended"] == 0
    assert data["furos"] == []
    assert data["surpresas"] == []
    assert data["confirmed_and_attended"] == []


@pytest.mark.asyncio
async def test_resumo_furo_aluno_confirmou_mas_nao_veio(
    client, pce_session, pce_aluno, pce_aluno_headers, pce_prof_headers
):
    """Aluno confirmou pré-checkin mas não foi à chamada → aparece em furos."""
    await client.post(
        f"/academies/training-sessions/{pce_session.id}/pre-checkin/confirm",
        headers=pce_aluno_headers,
    )
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/summary",
        headers=pce_prof_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total_pre_confirmed"] == 1
    assert data["total_attended"] == 0
    assert len(data["furos"]) == 1
    assert data["furos"][0]["name"] == pce_aluno.name
    assert data["surpresas"] == []
    assert data["confirmed_and_attended"] == []


@pytest.mark.asyncio
async def test_resumo_apenas_professor_acessa(
    client, pce_session, pce_aluno_headers
):
    """Aluno não pode acessar o resumo (require_write_access)."""
    r = await client.get(
        f"/academies/training-sessions/{pce_session.id}/summary",
        headers=pce_aluno_headers,
    )
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Templates de treino (favoritos)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_criar_e_listar_template(client, pce_academy, pce_prof_headers):
    """Professor cria um template e ele aparece na listagem."""
    r = await client.post(
        f"/academies/{pce_academy.id}/training-templates",
        json={"start_time": "19:00", "tolerance_minutes": 15, "label": "Adulto GI"},
        headers=pce_prof_headers,
    )
    assert r.status_code == 201

    r_list = await client.get(
        f"/academies/{pce_academy.id}/training-templates",
        headers=pce_prof_headers,
    )
    assert r_list.status_code == 200
    labels = [t["label"] for t in r_list.json()]
    assert "Adulto GI" in labels


@pytest.mark.asyncio
async def test_deletar_template(client, pce_academy, pce_prof_headers):
    """Professor cria e deleta um template."""
    r = await client.post(
        f"/academies/{pce_academy.id}/training-templates",
        json={"start_time": "06:30", "tolerance_minutes": 10},
        headers=pce_prof_headers,
    )
    assert r.status_code == 201
    template_id = r.json()["id"]

    r_del = await client.delete(
        f"/academies/training-templates/{template_id}",
        headers=pce_prof_headers,
    )
    assert r_del.status_code == 204

    r_list = await client.get(
        f"/academies/{pce_academy.id}/training-templates",
        headers=pce_prof_headers,
    )
    ids = [t["id"] for t in r_list.json()]
    assert template_id not in ids
