"""Testes do relatório semanal de logins do painel (global/academia)."""
from datetime import date, datetime, timedelta, timezone
from uuid import uuid4

from app.core.security import create_access_token, hash_password_sync


async def test_weekly_panel_logins_global(client, db, admin_headers, academy):
    from app.models import User
    from app.models.user_login_day import UserLoginDay

    ref = date(2026, 4, 5)  # semana ISO 14 (2026-03-30..2026-04-05)

    manager = User(
        email=f"manager-{uuid4().hex[:8]}@test.com",
        name="Manager A",
        role="gerente_academia",
        academy_id=academy.id,
        password_hash=hash_password_sync("manager123"),
    )
    professor = User(
        email=f"prof-{uuid4().hex[:8]}@test.com",
        name="Professor A",
        role="professor",
        academy_id=academy.id,
        password_hash=hash_password_sync("prof123"),
    )
    admin_global = User(
        email=f"admglobal-{uuid4().hex[:8]}@test.com",
        name="Admin Global",
        role="administrador",
        academy_id=None,
        password_hash=hash_password_sync("admin123"),
    )
    student = User(
        email=f"student-{uuid4().hex[:8]}@test.com",
        name="Aluno X",
        role="aluno",
        academy_id=academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add_all([manager, professor, admin_global, student])
    await db.commit()
    for u in (manager, professor, admin_global, student):
        await db.refresh(u)

    # manager: 2 dias na semana
    # professor: 1 dia na semana
    # admin_global: 1 dia na semana
    # student (aluno): 1 dia na semana (incluído no relatório de logins)
    db.add_all(
        [
            UserLoginDay(user_id=manager.id, login_day=date(2026, 3, 30)),
            UserLoginDay(user_id=manager.id, login_day=date(2026, 4, 2)),
            UserLoginDay(user_id=professor.id, login_day=date(2026, 4, 1)),
            UserLoginDay(user_id=admin_global.id, login_day=date(2026, 4, 5)),
            UserLoginDay(user_id=student.id, login_day=date(2026, 4, 4)),
        ]
    )
    await db.commit()

    r = await client.get(
        f"/reports/weekly_panel_logins?reference_date={ref.isoformat()}",
        headers=admin_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["academy_id"] is None
    assert data["week_start"] == "2026-03-30"
    assert data["week_end"] == "2026-04-05"
    assert data["eligible_users_count"] >= 4
    assert data["users_logged_at_least_once"] >= 4

    ids = {u["user_id"] for u in data["users"]}
    assert str(manager.id) in ids
    assert str(professor.id) in ids
    assert str(admin_global.id) in ids
    assert str(student.id) in ids

    manager_item = next(u for u in data["users"] if u["user_id"] == str(manager.id))
    assert manager_item["distinct_login_days_in_week"] == 2
    assert manager_item["login_days"] == ["2026-03-30", "2026-04-02"]


async def test_weekly_panel_logins_by_academy_excludes_global_admins(
    client,
    db,
    admin_headers,
    academy,
):
    from app.models import Academy, User
    from app.models.user_login_day import UserLoginDay

    other_academy = Academy(name="Other Academy", slug=f"other-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    aluno_here = User(
        email=f"aluno-here-{uuid4().hex[:8]}@test.com",
        name="Aluno Here",
        role="aluno",
        academy_id=academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    manager_here = User(
        email=f"manager-here-{uuid4().hex[:8]}@test.com",
        name="Manager Here",
        role="gerente_academia",
        academy_id=academy.id,
        password_hash=hash_password_sync("manager123"),
    )
    manager_other = User(
        email=f"manager-other-{uuid4().hex[:8]}@test.com",
        name="Manager Other",
        role="gerente_academia",
        academy_id=other_academy.id,
        password_hash=hash_password_sync("manager123"),
    )
    admin_global = User(
        email=f"admglobal2-{uuid4().hex[:8]}@test.com",
        name="Admin Global 2",
        role="administrador",
        academy_id=None,
        password_hash=hash_password_sync("admin123"),
    )
    db.add_all([aluno_here, manager_here, manager_other, admin_global])
    await db.commit()
    for u in (aluno_here, manager_here, manager_other, admin_global):
        await db.refresh(u)

    db.add_all(
        [
            UserLoginDay(user_id=aluno_here.id, login_day=date(2026, 4, 3)),
            UserLoginDay(user_id=manager_here.id, login_day=date(2026, 4, 2)),
            UserLoginDay(user_id=manager_other.id, login_day=date(2026, 4, 2)),
            UserLoginDay(user_id=admin_global.id, login_day=date(2026, 4, 2)),
        ]
    )
    await db.commit()

    r = await client.get(
        f"/reports/weekly_panel_logins?reference_date=2026-04-05&academy_id={academy.id}",
        headers=admin_headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["academy_id"] == str(academy.id)
    ids = {u["user_id"] for u in data["users"]}
    assert str(aluno_here.id) in ids
    assert str(manager_here.id) in ids
    assert str(manager_other.id) not in ids
    assert str(admin_global.id) not in ids


async def test_weekly_panel_logins_supervisor_requires_academy_id(client, db, academy):
    from app.models import User

    supervisor = User(
        email=f"sup-{uuid4().hex[:8]}@test.com",
        name="Supervisor A",
        role="supervisor",
        academy_id=academy.id,
        password_hash=hash_password_sync("sup123"),
        last_login_at=datetime.now(timezone.utc) - timedelta(days=1),
    )
    db.add(supervisor)
    await db.commit()
    await db.refresh(supervisor)
    headers = {"Authorization": f"Bearer {create_access_token(supervisor.id)}"}

    r = await client.get(
        "/reports/weekly_panel_logins?reference_date=2026-04-05",
        headers=headers,
    )
    assert r.status_code == 403
