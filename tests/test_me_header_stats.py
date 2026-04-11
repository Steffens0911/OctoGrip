"""Testes do endpoint agregado de header do usuário autenticado."""


async def test_me_header_stats_requires_auth(client):
    r = await client.get("/me/header_stats")
    assert r.status_code == 401


async def test_me_header_stats_returns_level_and_academy(
    client,
    db,
    aluno_headers,
    aluno_user,
    academy,
):
    academy.logo_url = "/media/academies/logo.png"
    academy.schedule_image_url = "/media/academies/schedule.png"
    academy.show_trophies = False
    academy.show_partners = True
    academy.show_schedule = False
    academy.show_global_supporters = True
    aluno_user.reward_level = 3
    aluno_user.reward_level_points = 17
    await db.commit()

    r = await client.get("/me/header_stats", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["user_id"] == str(aluno_user.id)
    assert data["reward_level"] == 3
    assert data["reward_level_points"] == 17
    assert data["next_level_threshold"] == 72
    assert data["academy"]["id"] == str(academy.id)
    assert data["academy"]["logo_url"] == "/media/academies/logo.png"
    assert data["academy"]["schedule_image_url"] == "/media/academies/schedule.png"
    assert data["academy"]["show_trophies"] is False
    assert data["academy"]["show_partners"] is True
    assert data["academy"]["show_schedule"] is False
    assert data["academy"]["show_global_supporters"] is True


async def test_me_header_stats_returns_null_academy(client, db, admin_headers, admin_user):
    admin_user.reward_level = 2
    admin_user.reward_level_points = 5
    admin_user.academy_id = None
    await db.commit()

    r = await client.get("/me/header_stats", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["user_id"] == str(admin_user.id)
    assert data["reward_level"] == 2
    assert data["reward_level_points"] == 5
    assert data["next_level_threshold"] == 60
    assert data["academy"] is None
