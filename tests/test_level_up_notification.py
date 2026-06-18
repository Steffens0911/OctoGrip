"""Testes da notificação de subida de nível (level-up)."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.leveling_service import refresh_user_level
from app.services.notification_service import list_notifications


async def _level_up_notifs(db: AsyncSession, user_id) -> list:
    notifs = await list_notifications(db, user_id, limit=100)
    return [n for n in notifs if n.type == "level_up"]


async def test_level_up_creates_notification(db: AsyncSession, aluno_user):
    """Cruzar o threshold do nível 1 (50 pts) gera uma notificação level_up."""
    assert aluno_user.reward_level == 1

    level, _, _ = await refresh_user_level(db, aluno_user.id, total_points=50)
    assert level == 2

    notifs = await _level_up_notifs(db, aluno_user.id)
    assert len(notifs) == 1
    assert "2" in notifs[0].title
    assert notifs[0].data == {"level": "2"}
    assert notifs[0].read is False


async def test_no_notification_without_level_change(db: AsyncSession, aluno_user):
    """Pontuar dentro do mesmo nível não dispara notificação."""
    level, _, _ = await refresh_user_level(db, aluno_user.id, total_points=10)
    assert level == 1

    assert await _level_up_notifs(db, aluno_user.id) == []


async def test_no_notification_on_recalc_or_drop(db: AsyncSession, aluno_user):
    """Recalcular para um nível igual/menor (ex.: estorno de pontos) não notifica."""
    # Sobe para o nível 3 e limpa as notificações geradas.
    await refresh_user_level(db, aluno_user.id, total_points=110)
    assert await _level_up_notifs(db, aluno_user.id)  # subiu, gerou notificação

    before = len(await _level_up_notifs(db, aluno_user.id))

    # Recalcular com o mesmo total não deve gerar nova notificação.
    await refresh_user_level(db, aluno_user.id, total_points=110)
    # Queda de pontos (estorno) também não deve notificar.
    await refresh_user_level(db, aluno_user.id, total_points=10)

    after = len(await _level_up_notifs(db, aluno_user.id))
    assert after == before


async def test_each_level_up_notifies_once(db: AsyncSession, aluno_user):
    """Subir dois níveis em momentos distintos gera duas notificações."""
    await refresh_user_level(db, aluno_user.id, total_points=50)  # -> nível 2
    await refresh_user_level(db, aluno_user.id, total_points=110)  # -> nível 3

    notifs = await _level_up_notifs(db, aluno_user.id)
    assert len(notifs) == 2
    levels = sorted(n.data["level"] for n in notifs)
    assert levels == ["2", "3"]
