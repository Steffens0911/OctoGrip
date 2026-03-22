import pytest
from datetime import date


def test_threshold_for_level_progression():
    from app.core.leveling import threshold_for_level

    assert threshold_for_level(1) == 50
    assert threshold_for_level(2) == 60
    assert threshold_for_level(3) == 72
    assert threshold_for_level(4) == 87


@pytest.mark.parametrize(
    "total_points,expected",
    [
        (0, (1, 0, 50)),
        (49, (1, 49, 50)),
        (50, (2, 0, 60)),
        (59, (2, 9, 60)),
        (60, (2, 10, 60)),
        (71, (2, 21, 60)),
        (72, (2, 22, 60)),
        (110, (3, 0, 72)),
        (111, (3, 1, 72)),
    ],
)
def test_compute_level_from_total_points(total_points, expected):
    from app.core.leveling import compute_level_from_total_points

    assert compute_level_from_total_points(total_points) == expected


async def test_get_user_points_includes_level_after_mission_complete(
    client, aluno_headers, aluno_user, db, academy, technique
):
    """Integração: após completar missão, endpoint /users/{id}/points devolve nível coerente."""
    from app.models import Mission

    mission = Mission(
        academy_id=academy.id,
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today(),
        level="beginner",
        is_active=True,
        multiplier=10,
    )
    db.add(mission)
    await db.commit()
    await db.refresh(mission)

    r0 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r0.status_code == 200

    # Completar missão
    r1 = await client.post(
        "/mission_complete",
        headers=aluno_headers,
        json={"mission_id": str(mission.id), "usage_type": "after_training"},
    )
    assert r1.status_code == 201

    r2 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r2.status_code == 200
    data = r2.json()

    assert data["points"] == 10
    assert data["level"] == 1
    assert data["level_points"] == 10
    assert data["next_level_threshold"] == 50

