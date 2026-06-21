"""
Testes do sistema de pontualidade e do endpoint de quiosque facial.

O face matching é mockado para testar o fluxo completo sem precisar de DeepFace.
"""
from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync


# ---------------------------------------------------------------------------
# Fixtures locais
# ---------------------------------------------------------------------------


@pytest.fixture
async def pct_academy(db: AsyncSession):
    """Academia com face_recognition_enabled + face_checkin_enabled + pré-checkin."""
    from app.models import Academy

    a = Academy(
        name=f"Academia PCT {uuid4().hex[:6]}",
        slug=f"pct-{uuid4().hex[:6]}",
        face_recognition_enabled=True,
        face_checkin_enabled=True,
        pre_checkin_enabled=True,
        punctuality_xp=15,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


@pytest.fixture
async def pct_professor(db: AsyncSession, pct_academy):
    from app.models import User

    user = User(
        email=f"prof-pct-{uuid4().hex[:8]}@test.com",
        name="Prof PCT",
        role="professor",
        graduation="black",
        academy_id=pct_academy.id,
        password_hash=hash_password_sync("prof1234"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
async def pct_aluno(db: AsyncSession, pct_academy):
    from app.models import User

    user = User(
        email=f"aluno-pct-{uuid4().hex[:8]}@test.com",
        name="Aluno PCT",
        role="aluno",
        graduation="white",
        academy_id=pct_academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
def pct_prof_headers(pct_professor):
    return {"Authorization": f"Bearer {create_access_token(pct_professor.id)}"}


@pytest.fixture
async def pct_session(db: AsyncSession, pct_academy, pct_professor):
    """Sessão de chamada ativa com TrainingSession vinculado (treino às 19h de hoje)."""
    from datetime import timezone

    from app.models import AttendanceSession
    from app.models.training_session import TrainingSession

    ts = TrainingSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_professor.id,
        class_date=date.today(),
        start_time="23:00",  # Late enough that tests run as "pontual"
        tolerance_minutes=15,
        status="open",
    )
    db.add(ts)
    await db.commit()
    await db.refresh(ts)

    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_professor.id,
        training_session_id=ts.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)
    return att, ts


@pytest.fixture
async def pct_session_closed(db: AsyncSession, pct_academy, pct_professor):
    """Sessão de chamada já encerrada."""
    from app.models import AttendanceSession

    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_professor.id,
        status="closed",
        starts_at=datetime.now(UTC) - timedelta(hours=2),
        expires_at=datetime.now(UTC) - timedelta(hours=1),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)
    return att


# ---------------------------------------------------------------------------
# Testes da lógica de pontualidade (unitário)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_apply_punctuality_pontual(db: AsyncSession, pct_academy, pct_aluno):
    """Aluno chega antes do horário → pontual, streak+1, XP concedido."""
    from app.models import AttendanceSession
    from app.models.attendance_record import AttendanceRecord
    from app.models.training_session import TrainingSession
    from app.services.punctuality_service import apply_punctuality

    ts = TrainingSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        class_date=date.today(),
        start_time="22:00",
        tolerance_minutes=15,
        status="open",
    )
    db.add(ts)
    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(ts)
    await db.refresh(att)

    record = AttendanceRecord(
        session_id=att.id,
        user_id=pct_aluno.id,
        checked_in_at=datetime.now(UTC),
        method="face",
        face_recognition=True,
        added_manually=False,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    # Simula chegada bem antes do horário (UTC-3 → 22h local = 01h UTC d+1)
    early_checkin = datetime(date.today().year, date.today().month, date.today().day, 0, 0, 0, tzinfo=UTC)

    was_punctual, xp = await apply_punctuality(
        db,
        user=pct_aluno,
        academy=pct_academy,
        record=record,
        training_session=ts,
        checked_in_at=early_checkin,
    )

    assert was_punctual is True
    assert xp == 15  # punctuality_xp padrão da academia
    assert record.was_punctual is True
    assert pct_aluno.punctuality_streak == 1
    assert pct_aluno.punctuality_streak_best == 1


@pytest.mark.asyncio
async def test_apply_punctuality_atrasado_zera_streak(db: AsyncSession, pct_academy, pct_aluno):
    """Aluno atrasado → streak zerado imediatamente."""
    from app.models import AttendanceSession
    from app.models.attendance_record import AttendanceRecord
    from app.models.training_session import TrainingSession
    from app.services.punctuality_service import apply_punctuality

    # Pré-condição: aluno tinha streak 5
    pct_aluno.punctuality_streak = 5
    pct_aluno.punctuality_streak_best = 5
    await db.commit()

    ts = TrainingSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        class_date=date.today(),
        start_time="08:00",  # horário cedo (08h local = 11h UTC)
        tolerance_minutes=15,
        status="open",
    )
    db.add(ts)
    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(ts)
    await db.refresh(att)

    record = AttendanceRecord(
        session_id=att.id,
        user_id=pct_aluno.id,
        checked_in_at=datetime.now(UTC),
        method="face",
        face_recognition=True,
        added_manually=False,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    # Aluno chegou tarde (depois das 08h local → depois das 11h UTC)
    late_checkin = datetime(date.today().year, date.today().month, date.today().day, 15, 0, 0, tzinfo=UTC)

    was_punctual, xp = await apply_punctuality(
        db,
        user=pct_aluno,
        academy=pct_academy,
        record=record,
        training_session=ts,
        checked_in_at=late_checkin,
    )

    assert was_punctual is False
    assert xp == 0
    assert record.was_punctual is False
    assert pct_aluno.punctuality_streak == 0
    assert pct_aluno.punctuality_streak_best == 5  # Recorde preservado


@pytest.mark.asyncio
async def test_streak_best_atualizado(db: AsyncSession, pct_academy, pct_aluno):
    """Recorde é atualizado quando o novo streak supera o anterior."""
    from app.models import AttendanceSession
    from app.models.attendance_record import AttendanceRecord
    from app.models.training_session import TrainingSession
    from app.services.punctuality_service import apply_punctuality

    pct_aluno.punctuality_streak = 9
    pct_aluno.punctuality_streak_best = 9
    await db.commit()

    ts = TrainingSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        class_date=date.today(),
        start_time="22:00",
        tolerance_minutes=15,
        status="open",
    )
    db.add(ts)
    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(ts)
    await db.refresh(att)

    record = AttendanceRecord(
        session_id=att.id,
        user_id=pct_aluno.id,
        checked_in_at=datetime.now(UTC),
        method="face",
        face_recognition=True,
        added_manually=False,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    early = datetime(date.today().year, date.today().month, date.today().day, 0, 0, 0, tzinfo=UTC)
    await apply_punctuality(db, user=pct_aluno, academy=pct_academy, record=record, training_session=ts, checked_in_at=early)

    assert pct_aluno.punctuality_streak == 10
    assert pct_aluno.punctuality_streak_best == 10


# ---------------------------------------------------------------------------
# Testes do endpoint de quiosque
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_face_arrive_sessao_nao_encontrada(client, pct_academy):
    """Sessão inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.post(
        f"/attendance/sessions/{fake_id}/face-arrive",
        files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_face_arrive_sessao_fechada(client, pct_session_closed):
    """Sessão encerrada retorna 409."""
    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.return_value = (None, 0.0)
        r = await client.post(
            f"/attendance/sessions/{pct_session_closed.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_face_arrive_quiosque_desabilitado(client, db: AsyncSession, pct_academy, pct_professor):
    """Academia sem face_checkin_enabled retorna 403."""
    from app.models import Academy, AttendanceSession

    acad_off = Academy(
        name=f"Sem Quiosque {uuid4().hex[:6]}",
        slug=f"sq-{uuid4().hex[:6]}",
        face_recognition_enabled=True,
        face_checkin_enabled=False,
    )
    db.add(acad_off)
    await db.commit()
    await db.refresh(acad_off)

    prof2 = __import__("app.models", fromlist=["User"]).User
    from app.models import User

    u = User(
        email=f"prof2-{uuid4().hex[:8]}@test.com",
        name="Prof2",
        role="professor",
        graduation="black",
        academy_id=acad_off.id,
        password_hash=hash_password_sync("x"),
    )
    db.add(u)
    att = AttendanceSession(
        academy_id=acad_off.id,
        created_by_user_id=pct_professor.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)

    r = await client.post(
        f"/attendance/sessions/{att.id}/face-arrive",
        files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_face_arrive_sem_reconhecimento(client, pct_session):
    """Confiança baixa → matched=False, orienta ao QR Code."""
    att, _ts = pct_session

    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.return_value = (None, 0.45)
        r = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )

    assert r.status_code == 200
    data = r.json()
    assert data["matched"] is False
    assert data["confidence"] == 0.45
    assert "QR" in data["greeting"]


@pytest.mark.asyncio
async def test_face_arrive_registra_presenca_pontual(client, db: AsyncSession, pct_session, pct_aluno):
    """Aluno identificado antes do horário → presença registrada, was_punctual=True."""
    att, ts = pct_session

    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.return_value = (pct_aluno, 0.85)
        r = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )

    assert r.status_code == 200
    data = r.json()
    assert data["matched"] is True
    assert data["student_name"] == pct_aluno.name
    assert data["was_punctual"] is True  # treino às 23h, check-in agora < 23h
    assert data["xp_awarded"] == 15
    assert data["punctuality_streak"] == 1
    assert data["duplicate"] is False


@pytest.mark.asyncio
async def test_face_arrive_duplicata(client, db: AsyncSession, pct_session, pct_aluno):
    """Segunda chegada com o mesmo aluno retorna duplicate=True e não duplica presença."""
    from sqlalchemy import func, select

    from app.models import AttendanceRecord

    att, _ts = pct_session

    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.return_value = (pct_aluno, 0.82)
        r1 = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )
        r2 = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )

    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["duplicate"] is False
    assert r2.json()["duplicate"] is True

    # Apenas 1 registro de presença criado
    count = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(
                AttendanceRecord.session_id == att.id,
                AttendanceRecord.user_id == pct_aluno.id,
            )
        )
    ).scalar_one()
    assert count == 1


@pytest.mark.asyncio
async def test_face_arrive_sem_treino_vinculado(client, db: AsyncSession, pct_academy, pct_professor, pct_aluno):
    """Sessão sem TrainingSession → presença registrada, was_punctual=None."""
    from app.models import AttendanceSession

    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_professor.id,
        training_session_id=None,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)

    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.return_value = (pct_aluno, 0.91)
        r = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )

    assert r.status_code == 200
    data = r.json()
    assert data["matched"] is True
    assert data["was_punctual"] is None
    assert data["xp_awarded"] == 0


# ---------------------------------------------------------------------------
# Testes do relatório de pontualidade
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_relatorio_pontualidade_vazio(client, pct_academy, pct_prof_headers):
    """Relatório sem dados retorna lista vazia."""
    r = await client.get(
        "/reports/punctuality",
        params={"academy_id": str(pct_academy.id), "days": 30},
        headers=pct_prof_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["academy_id"] == str(pct_academy.id)
    assert data["students"] == []


@pytest.mark.asyncio
async def test_relatorio_pontualidade_acesso_negado_aluno(client, pct_aluno):
    """Aluno não pode acessar o relatório de pontualidade."""
    headers = {"Authorization": f"Bearer {create_access_token(pct_aluno.id)}"}
    r = await client.get(
        "/reports/punctuality",
        params={"days": 30},
        headers=headers,
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_relatorio_pontualidade_com_dados(client, db: AsyncSession, pct_academy, pct_aluno, pct_prof_headers):
    """Após registrar was_punctual, o aluno aparece no relatório."""
    from app.models import AttendanceSession
    from app.models.attendance_record import AttendanceRecord

    att = AttendanceSession(
        academy_id=pct_academy.id,
        created_by_user_id=pct_aluno.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)

    record = AttendanceRecord(
        session_id=att.id,
        user_id=pct_aluno.id,
        checked_in_at=datetime.now(UTC),
        method="face",
        face_recognition=True,
        added_manually=False,
        was_punctual=True,
    )
    db.add(record)
    pct_aluno.punctuality_streak = 3
    pct_aluno.punctuality_streak_best = 3
    await db.commit()

    r = await client.get(
        "/reports/punctuality",
        params={"academy_id": str(pct_academy.id), "days": 30},
        headers=pct_prof_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data["students"]) == 1
    entry = data["students"][0]
    assert entry["student_id"] == str(pct_aluno.id)
    assert entry["punctual_count"] == 1
    assert entry["late_count"] == 0
    assert entry["total_checkins"] == 1
    assert entry["punctuality_pct"] == 100.0
    assert entry["punctuality_streak"] == 3
