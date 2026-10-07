"""
Presença para qualquer perfil.

O critério para constar numa chamada é o VÍNCULO COM A ACADEMIA, não o papel: a mesma
pessoa pode ser professor numa aula e aluno em outra. Estes testes cobrem os caminhos
que antes eram restritos a ``role == "aluno"`` — presença manual, QR, ranking,
frequência e reconhecimento facial.
"""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync
from app.services import qr_service

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
async def att_academy(db: AsyncSession):
    """Academia com QR e reconhecimento facial habilitados."""
    from app.models import Academy

    a = Academy(
        name=f"Academia ATT {uuid4().hex[:6]}",
        slug=f"att-{uuid4().hex[:6]}",
        qr_attendance_enabled=True,
        face_recognition_enabled=True,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


async def _mk_user(db: AsyncSession, *, role: str, academy_id, name: str | None = None):
    from app.models import User

    user = User(
        email=f"{role}-{uuid4().hex[:8]}@test.com",
        name=name or f"{role.title()} ATT",
        role=role,
        graduation="white" if role == "aluno" else "black",
        academy_id=academy_id,
        password_hash=hash_password_sync("senha12345"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


def _headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


@pytest.fixture
async def att_gerente(db: AsyncSession, att_academy):
    return await _mk_user(db, role="gerente_academia", academy_id=att_academy.id)


@pytest.fixture
async def att_professor(db: AsyncSession, att_academy):
    return await _mk_user(db, role="professor", academy_id=att_academy.id)


@pytest.fixture
async def att_supervisor(db: AsyncSession, att_academy):
    return await _mk_user(db, role="supervisor", academy_id=att_academy.id)


@pytest.fixture
async def att_aluno(db: AsyncSession, att_academy):
    return await _mk_user(db, role="aluno", academy_id=att_academy.id)


@pytest.fixture
async def att_admin_global(db: AsyncSession):
    return await _mk_user(db, role="administrador", academy_id=None)


@pytest.fixture
async def att_session(db: AsyncSession, att_academy, att_gerente):
    from app.models import AttendanceSession

    now = datetime.now(UTC)
    s = AttendanceSession(
        academy_id=att_academy.id,
        created_by_user_id=att_gerente.id,
        status="active",
        starts_at=now,
        expires_at=now + timedelta(minutes=30),
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return s


@pytest.fixture
async def att_outsider(db: AsyncSession):
    """Aluno de outra academia."""
    from app.models import Academy

    other = Academy(name=f"Outra {uuid4().hex[:6]}", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other)
    await db.commit()
    await db.refresh(other)
    return await _mk_user(db, role="aluno", academy_id=other.id)


async def _add_manual(client, session_id, actor, target_ids: list):
    return await client.post(
        f"/attendance/sessions/{session_id}/records",
        json={"student_ids": [str(i) for i in target_ids]},
        headers=_headers(actor),
    )


async def _face_job(db: AsyncSession, *, session, academy, creator):
    from app.models import FaceRecognitionJob

    job = FaceRecognitionJob(
        session_id=session.id,
        academy_id=academy.id,
        created_by_user_id=creator.id,
        status="completed",
        photo_path="/tmp/fake.jpg",
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)
    return job


# ---------------------------------------------------------------------------
# Presença manual — qualquer perfil vinculado pode RECEBER
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("role", ["professor", "gerente_academia", "supervisor", "administrador", "aluno"])
async def test_presenca_manual_aceita_qualquer_perfil_da_academia(
    client, db, att_academy, att_session, att_gerente, role
):
    target = await _mk_user(db, role=role, academy_id=att_academy.id)

    r = await _add_manual(client, att_session.id, att_gerente, [target.id])

    assert r.status_code == 201, r.text
    records = r.json()["records"]
    assert len(records) == 1
    assert records[0]["user_id"] == str(target.id)
    assert records[0]["method"] == "manual"
    assert records[0]["added_manually"] is True


async def test_presenca_manual_contrato_legado_user_id(client, att_session, att_gerente, att_professor):
    r = await client.post(
        f"/attendance/sessions/{att_session.id}/records",
        json={"user_id": str(att_professor.id)},
        headers=_headers(att_gerente),
    )

    assert r.status_code == 201, r.text
    assert r.json()["user_id"] == str(att_professor.id)


async def test_presenca_manual_idempotente_para_nao_aluno(client, att_session, att_gerente, att_professor):
    first = await _add_manual(client, att_session.id, att_gerente, [att_professor.id])
    assert first.status_code == 201

    second = await _add_manual(client, att_session.id, att_gerente, [att_professor.id])

    assert second.status_code == 201
    assert second.json()["records"] == []


async def test_presenca_manual_bloqueia_pessoa_de_outra_academia(client, att_session, att_gerente, att_outsider):
    r = await _add_manual(client, att_session.id, att_gerente, [att_outsider.id])

    assert r.status_code == 403
    assert "academia" in r.json()["detail"].lower()


async def test_presenca_manual_bloqueia_papel_desconhecido(client, db, att_academy, att_session, att_gerente):
    """users.role não tem CHECK no banco — um papel fora da lista não entra na chamada."""
    estranho = await _mk_user(db, role="aluno", academy_id=att_academy.id)
    estranho.role = "visitante"
    await db.commit()

    r = await _add_manual(client, att_session.id, att_gerente, [estranho.id])

    assert r.status_code == 403
    assert "perfil" in r.json()["detail"].lower()


async def test_aluno_nao_lanca_presenca_de_outro(client, att_session, att_aluno, att_professor):
    r = await _add_manual(client, att_session.id, att_aluno, [att_professor.id])

    assert r.status_code == 403


# ---------------------------------------------------------------------------
# QR — bater a própria presença
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("role", ["supervisor", "administrador", "professor", "gerente_academia", "aluno"])
async def test_scan_qr_aceita_qualquer_perfil_da_academia(client, db, att_academy, att_session, role):
    actor = await _mk_user(db, role=role, academy_id=att_academy.id)
    token, _ = qr_service.issue(att_session.id, ttl_seconds=60)

    r = await client.post("/attendance/scan", json={"token": token}, headers=_headers(actor))

    assert r.status_code == 201, r.text
    assert r.json()["user_id"] == str(actor.id)
    assert r.json()["method"] == "qr"


async def test_scan_qr_admin_sem_academia_403(client, att_session, att_admin_global):
    token, _ = qr_service.issue(att_session.id, ttl_seconds=60)

    r = await client.post("/attendance/scan", json={"token": token}, headers=_headers(att_admin_global))

    assert r.status_code == 403
    assert "academia" in r.json()["detail"].lower()


async def test_scan_qr_papel_desconhecido_403(client, db, att_academy, att_session):
    estranho = await _mk_user(db, role="aluno", academy_id=att_academy.id)
    estranho.role = "visitante"
    await db.commit()
    token, _ = qr_service.issue(att_session.id, ttl_seconds=60)

    r = await client.post("/attendance/scan", json={"token": token}, headers=_headers(estranho))

    assert r.status_code == 403
    assert "perfil" in r.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Ranking e frequência — quem bateu presença aparece
# ---------------------------------------------------------------------------


async def test_professor_aparece_no_ranking_de_presenca(client, att_session, att_gerente, att_professor):
    assert (await _add_manual(client, att_session.id, att_gerente, [att_professor.id])).status_code == 201

    r = await client.get(
        f"/attendance/ranking?academy_id={att_session.academy_id}",
        headers=_headers(att_gerente),
    )

    assert r.status_code == 200, r.text
    assert str(att_professor.id) in [e["student_id"] for e in r.json()["ranking"]]


async def test_my_position_preenchido_para_professor(client, att_session, att_gerente, att_professor):
    assert (await _add_manual(client, att_session.id, att_gerente, [att_professor.id])).status_code == 201

    r = await client.get(
        f"/attendance/ranking?academy_id={att_session.academy_id}",
        headers=_headers(att_professor),
    )

    assert r.status_code == 200, r.text
    my = r.json()["my_position"]
    assert my is not None
    assert my["position"] >= 1
    assert my["total_checkins"] == 1


async def test_stats_students_inclui_quem_bateu_presenca(
    client, att_session, att_gerente, att_professor, att_aluno, att_supervisor
):
    assert (
        await _add_manual(client, att_session.id, att_gerente, [att_professor.id, att_aluno.id])
    ).status_code == 201

    r = await client.get(
        f"/attendance/stats/students?academy_id={att_session.academy_id}",
        headers=_headers(att_gerente),
    )

    assert r.status_code == 200, r.text
    ids = [row["user_id"] for row in r.json()]
    assert str(att_professor.id) in ids
    assert str(att_aluno.id) in ids
    # Staff sem nenhum check-in não polui a lista de frequência.
    assert str(att_supervisor.id) not in ids


async def test_stats_student_detail_de_professor(client, att_session, att_gerente, att_professor):
    assert (await _add_manual(client, att_session.id, att_gerente, [att_professor.id])).status_code == 201

    r = await client.get(
        f"/attendance/stats/students/{att_professor.id}?academy_id={att_session.academy_id}",
        headers=_headers(att_gerente),
    )

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["user_id"] == str(att_professor.id)
    assert body["present_count"] == 1


async def test_stats_student_detail_aluno_so_ve_a_si_mesmo(client, att_session, att_aluno, att_professor):
    r = await client.get(
        f"/attendance/stats/students/{att_professor.id}?academy_id={att_session.academy_id}",
        headers=_headers(att_aluno),
    )

    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Lista do modal de presença manual
# ---------------------------------------------------------------------------


async def test_lista_da_academia_inclui_staff_com_papel(
    client, att_academy, att_gerente, att_professor, att_aluno, att_supervisor
):
    r = await client.get(f"/students/academy/{att_academy.id}/list", headers=_headers(att_gerente))

    assert r.status_code == 200, r.text
    by_id = {row["id"]: row for row in r.json()}
    assert by_id[str(att_professor.id)]["role"] == "professor"
    assert by_id[str(att_supervisor.id)]["role"] == "supervisor"
    assert by_id[str(att_aluno.id)]["role"] == "aluno"


async def test_lista_da_academia_exclui_conta_congelada(client, db, att_academy, att_gerente, att_professor):
    att_professor.account_frozen = True
    await db.commit()

    r = await client.get(f"/students/academy/{att_academy.id}/list", headers=_headers(att_gerente))

    assert r.status_code == 200
    assert str(att_professor.id) not in [row["id"] for row in r.json()]


# ---------------------------------------------------------------------------
# Reconhecimento facial
# ---------------------------------------------------------------------------


async def test_face_confirm_aceita_professor(client, db, att_academy, att_session, att_gerente, att_professor):
    job = await _face_job(db, session=att_session, academy=att_academy, creator=att_gerente)

    r = await client.post(
        "/face-recognition/confirm",
        json={
            "session_id": str(att_session.id),
            "job_id": str(job.id),
            "confirmed_student_ids": [str(att_professor.id)],
        },
        headers=_headers(att_gerente),
    )

    assert r.status_code == 200, r.text
    assert r.json()["created_records"] == 1


async def test_face_confirm_bloqueia_pessoa_de_outra_academia(
    client, db, att_academy, att_session, att_gerente, att_outsider
):
    job = await _face_job(db, session=att_session, academy=att_academy, creator=att_gerente)

    r = await client.post(
        "/face-recognition/confirm",
        json={
            "session_id": str(att_session.id),
            "job_id": str(job.id),
            "confirmed_student_ids": [str(att_outsider.id)],
        },
        headers=_headers(att_gerente),
    )

    assert r.status_code == 403
