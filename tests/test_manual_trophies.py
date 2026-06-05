"""Testes para troféus manuais: templates, campeonatos e concessões."""

from datetime import date, timedelta
from uuid import uuid4

import pytest

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
async def championship_template(db, academy, professor_user):
    from app.models.manual_trophy import AcademyTrophyTemplate

    t = AcademyTrophyTemplate(
        academy_id=academy.id,
        name="Medalha de Campeonato",
        trophy_type="championship",
        created_by=professor_user.id,
    )
    db.add(t)
    await db.commit()
    await db.refresh(t)
    return t


@pytest.fixture
async def custom_template(db, academy, professor_user):
    from app.models.manual_trophy import AcademyTrophyTemplate

    t = AcademyTrophyTemplate(
        academy_id=academy.id,
        name="Troféu Pontualidade",
        trophy_type="custom",
        icon="trophy_star",
        color="#FFD700",
        created_by=professor_user.id,
    )
    db.add(t)
    await db.commit()
    await db.refresh(t)
    return t


@pytest.fixture
async def championship_event(db, academy, professor_user):
    from app.models.manual_trophy import AcademyChampionshipEvent

    e = AcademyChampionshipEvent(
        academy_id=academy.id,
        name="IBJJF SP 2026",
        location="São Paulo",
        event_date=date.today() - timedelta(days=10),
        created_by=professor_user.id,
    )
    db.add(e)
    await db.commit()
    await db.refresh(e)
    return e


# ---------------------------------------------------------------------------
# Templates — criação
# ---------------------------------------------------------------------------


async def test_professor_cria_template_custom(client, professor_headers, academy):
    r = await client.post(
        "/manual-trophies/templates",
        headers=professor_headers,
        json={
            "academy_id": str(academy.id),
            "name": "Troféu Assiduidade",
            "description": "Para quem nunca faltou no mês",
            "icon": "star",
            "color": "#FFD700",
            "trophy_type": "custom",
        },
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["name"] == "Troféu Assiduidade"
    assert data["trophy_type"] == "custom"
    assert data["icon"] == "star"
    assert data["color"] == "#FFD700"


async def test_professor_cria_template_championship(client, professor_headers, academy):
    r = await client.post(
        "/manual-trophies/templates",
        headers=professor_headers,
        json={
            "academy_id": str(academy.id),
            "name": "Medalha IBJJF",
            "trophy_type": "championship",
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["trophy_type"] == "championship"


async def test_aluno_nao_pode_criar_template(client, aluno_headers, academy):
    r = await client.post(
        "/manual-trophies/templates",
        headers=aluno_headers,
        json={
            "academy_id": str(academy.id),
            "name": "Troféu Indevido",
            "trophy_type": "custom",
        },
    )
    assert r.status_code == 403


async def test_cor_invalida_rejeitada(client, professor_headers, academy):
    r = await client.post(
        "/manual-trophies/templates",
        headers=professor_headers,
        json={
            "academy_id": str(academy.id),
            "name": "X",
            "trophy_type": "custom",
            "color": "red",  # sem #
        },
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Templates — listagem e edição
# ---------------------------------------------------------------------------


async def test_listar_templates(client, professor_headers, academy, custom_template, championship_template):
    r = await client.get(f"/manual-trophies/templates?academy_id={academy.id}", headers=professor_headers)
    assert r.status_code == 200
    ids = [t["id"] for t in r.json()]
    assert str(custom_template.id) in ids
    assert str(championship_template.id) in ids


async def test_filtrar_templates_por_tipo(client, professor_headers, academy, custom_template, championship_template):
    r = await client.get(
        f"/manual-trophies/templates?academy_id={academy.id}&trophy_type=custom",
        headers=professor_headers,
    )
    assert r.status_code == 200
    assert all(t["trophy_type"] == "custom" for t in r.json())


async def test_atualizar_template(client, professor_headers, custom_template):
    r = await client.patch(
        f"/manual-trophies/templates/{custom_template.id}",
        headers=professor_headers,
        json={"name": "Troféu Pontualidade Atualizado"},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "Troféu Pontualidade Atualizado"


async def test_deletar_template(client, professor_headers, academy, db):
    from app.models.manual_trophy import AcademyTrophyTemplate

    t = AcademyTrophyTemplate(academy_id=academy.id, name="Temp", trophy_type="custom")
    db.add(t)
    await db.commit()
    await db.refresh(t)

    r = await client.delete(f"/manual-trophies/templates/{t.id}", headers=professor_headers)
    assert r.status_code == 204

    r2 = await client.get(f"/manual-trophies/templates?academy_id={academy.id}", headers=professor_headers)
    ids = [x["id"] for x in r2.json()]
    assert str(t.id) not in ids


# ---------------------------------------------------------------------------
# Campeonatos
# ---------------------------------------------------------------------------


async def test_professor_cria_campeonato(client, professor_headers, academy):
    r = await client.post(
        "/manual-trophies/championships",
        headers=professor_headers,
        json={
            "academy_id": str(academy.id),
            "name": "IBJJF São Paulo 2026",
            "location": "São Paulo, SP",
            "event_date": date.today().isoformat(),
        },
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["name"] == "IBJJF São Paulo 2026"
    assert data["location"] == "São Paulo, SP"


async def test_listar_campeonatos(client, professor_headers, academy, championship_event):
    r = await client.get(f"/manual-trophies/championships?academy_id={academy.id}", headers=professor_headers)
    assert r.status_code == 200
    ids = [e["id"] for e in r.json()]
    assert str(championship_event.id) in ids


async def test_atualizar_campeonato(client, professor_headers, championship_event):
    r = await client.patch(
        f"/manual-trophies/championships/{championship_event.id}",
        headers=professor_headers,
        json={"name": "IBJJF SP 2026 Atualizado"},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "IBJJF SP 2026 Atualizado"


async def test_deletar_campeonato(client, professor_headers, academy, db):
    from app.models.manual_trophy import AcademyChampionshipEvent

    e = AcademyChampionshipEvent(academy_id=academy.id, name="Temp", event_date=date.today())
    db.add(e)
    await db.commit()
    await db.refresh(e)

    r = await client.delete(f"/manual-trophies/championships/{e.id}", headers=professor_headers)
    assert r.status_code == 204


# ---------------------------------------------------------------------------
# Concessões — troféu livre (custom)
# ---------------------------------------------------------------------------


async def test_conceder_trofeu_custom(client, professor_headers, aluno_user, custom_template):
    r = await client.post(
        "/manual-trophies/awards",
        headers=professor_headers,
        json={
            "template_id": str(custom_template.id),
            "user_id": str(aluno_user.id),
            "note": "Parabéns pela pontualidade!",
        },
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["template_id"] == str(custom_template.id)
    assert data["user_id"] == str(aluno_user.id)
    assert data["medal_type"] is None
    assert data["note"] == "Parabéns pela pontualidade!"


async def test_conceder_trofeu_custom_multiplas_vezes(client, professor_headers, aluno_user, custom_template):
    """Troféu livre pode ser concedido ao mesmo aluno mais de uma vez."""
    for _ in range(3):
        r = await client.post(
            "/manual-trophies/awards",
            headers=professor_headers,
            json={"template_id": str(custom_template.id), "user_id": str(aluno_user.id)},
        )
        assert r.status_code == 201


async def test_aluno_nao_pode_conceder_trofeu(client, aluno_headers, aluno_user, custom_template):
    r = await client.post(
        "/manual-trophies/awards",
        headers=aluno_headers,
        json={"template_id": str(custom_template.id), "user_id": str(aluno_user.id)},
    )
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Concessões — medalha de campeonato
# ---------------------------------------------------------------------------


async def test_conceder_medalha_campeonato_ouro(
    client, professor_headers, aluno_user, championship_template, championship_event
):
    r = await client.post(
        "/manual-trophies/awards",
        headers=professor_headers,
        json={
            "template_id": str(championship_template.id),
            "user_id": str(aluno_user.id),
            "championship_event_id": str(championship_event.id),
            "medal_type": "gold",
            "note": "Campeão absoluto!",
        },
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["medal_type"] == "gold"
    assert data["championship_event_id"] == str(championship_event.id)
    assert data["championship_event_name"] == championship_event.name


async def test_campeonato_sem_event_id_rejeitado(client, professor_headers, aluno_user, championship_template):
    r = await client.post(
        "/manual-trophies/awards",
        headers=professor_headers,
        json={
            "template_id": str(championship_template.id),
            "user_id": str(aluno_user.id),
            "medal_type": "gold",
        },
    )
    assert r.status_code == 400


async def test_campeonato_sem_medal_type_rejeitado(
    client, professor_headers, aluno_user, championship_template, championship_event
):
    r = await client.post(
        "/manual-trophies/awards",
        headers=professor_headers,
        json={
            "template_id": str(championship_template.id),
            "user_id": str(aluno_user.id),
            "championship_event_id": str(championship_event.id),
        },
    )
    assert r.status_code == 400


async def test_medal_type_invalido_rejeitado(
    client, professor_headers, aluno_user, championship_template, championship_event
):
    r = await client.post(
        "/manual-trophies/awards",
        headers=professor_headers,
        json={
            "template_id": str(championship_template.id),
            "user_id": str(aluno_user.id),
            "championship_event_id": str(championship_event.id),
            "medal_type": "diamante",
        },
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Listagem de concessões
# ---------------------------------------------------------------------------


async def test_listar_premios_por_template(client, professor_headers, aluno_user, custom_template, db):
    from app.models.manual_trophy import AcademyTrophyAward

    award = AcademyTrophyAward(template_id=custom_template.id, user_id=aluno_user.id)
    db.add(award)
    await db.commit()

    r = await client.get(
        f"/manual-trophies/awards/template/{custom_template.id}",
        headers=professor_headers,
    )
    assert r.status_code == 200
    assert len(r.json()) >= 1


async def test_listar_premios_por_usuario(
    client, professor_headers, aluno_user, custom_template, championship_template, championship_event, db
):
    from app.models.manual_trophy import AcademyTrophyAward

    db.add(AcademyTrophyAward(template_id=custom_template.id, user_id=aluno_user.id))
    db.add(
        AcademyTrophyAward(
            template_id=championship_template.id,
            user_id=aluno_user.id,
            championship_event_id=championship_event.id,
            medal_type="silver",
        )
    )
    await db.commit()

    r = await client.get(
        f"/manual-trophies/awards/user/{aluno_user.id}",
        headers=professor_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data["championship_awards"]) >= 1
    assert len(data["custom_awards"]) >= 1


async def test_aluno_ve_proprios_premios(client, aluno_headers, aluno_user, custom_template, db):
    from app.models.manual_trophy import AcademyTrophyAward

    db.add(AcademyTrophyAward(template_id=custom_template.id, user_id=aluno_user.id))
    await db.commit()

    r = await client.get(
        f"/manual-trophies/awards/user/{aluno_user.id}",
        headers=aluno_headers,
    )
    assert r.status_code == 200


# ---------------------------------------------------------------------------
# Revogação
# ---------------------------------------------------------------------------


async def test_revogar_concessao(client, professor_headers, aluno_user, custom_template, db):
    from app.models.manual_trophy import AcademyTrophyAward

    award = AcademyTrophyAward(template_id=custom_template.id, user_id=aluno_user.id)
    db.add(award)
    await db.commit()
    await db.refresh(award)

    r = await client.delete(f"/manual-trophies/awards/{award.id}", headers=professor_headers)
    assert r.status_code == 204

    r2 = await client.get(f"/manual-trophies/awards/template/{custom_template.id}", headers=professor_headers)
    ids = [a["id"] for a in r2.json()]
    assert str(award.id) not in ids


async def test_revogar_concessao_inexistente(client, professor_headers):
    r = await client.delete(f"/manual-trophies/awards/{uuid4()}", headers=professor_headers)
    assert r.status_code == 404
