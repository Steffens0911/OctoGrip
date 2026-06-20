"""Task Celery: alerta semanal de alunos em risco para professores/gestores."""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select

from app.config import settings
from app.models.attendance_record import AttendanceRecord
from app.models.attendance_session import AttendanceSession
from app.models.user import User
from app.models.user_device_token import UserDeviceToken
from celery_app import celery_app

logger = logging.getLogger(__name__)

_AT_RISK_DAYS = 7
_STAFF_ROLES = ("professor", "gerente_academia")


@celery_app.task(bind=True, max_retries=1, time_limit=180)
def send_weekly_at_risk_alert(self) -> None:
    """Envia push semanal para professores/gestores com contagem de alunos sem presença há 7+ dias."""

    async def _wrapper() -> None:
        from app.database import async_engine

        try:
            await _run()
        finally:
            await async_engine.dispose()

    asyncio.run(_wrapper())


async def _run() -> None:
    from app.database import AsyncSessionLocal
    from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
    from app.services.push_token_service import delete_device_token

    async with AsyncSessionLocal() as db:
        # Academias que têm ao menos 1 aluno ativo
        academy_ids = (
            (
                await db.execute(
                    select(User.academy_id)
                    .where(
                        User.role == "aluno",
                        User.account_frozen == False,  # noqa: E712
                        User.academy_id.is_not(None),
                    )
                    .distinct()
                )
            )
            .scalars()
            .all()
        )

        if not academy_ids:
            return

        now_utc = datetime.now(UTC)
        cutoff = now_utc - timedelta(days=_AT_RISK_DAYS)

        # Obtém um único access token OAuth2 para reutilizar em todos os envios
        try:
            access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        except Exception:
            logger.exception("at_risk_alert: falha ao obter access token FCM")
            return

        for academy_id in academy_ids:
            # Última presença por aluno nesta academia
            last_checkin_subq = (
                select(
                    AttendanceRecord.user_id,
                    func.max(AttendanceRecord.checked_in_at).label("last_checkin"),
                )
                .join(AttendanceSession, AttendanceRecord.session_id == AttendanceSession.id)
                .where(AttendanceSession.academy_id == academy_id)
                .group_by(AttendanceRecord.user_id)
                .subquery()
            )

            at_risk_count: int = (
                await db.scalar(
                    select(func.count(User.id))
                    .outerjoin(last_checkin_subq, User.id == last_checkin_subq.c.user_id)
                    .where(
                        User.academy_id == academy_id,
                        User.role == "aluno",
                        User.account_frozen == False,  # noqa: E712
                        or_(
                            last_checkin_subq.c.last_checkin < cutoff,
                            last_checkin_subq.c.last_checkin.is_(None),
                        ),
                    )
                )
            ) or 0

            if at_risk_count == 0:
                continue

            aluno_txt = "aluno" if at_risk_count == 1 else "alunos"
            title = "Alunos precisam de atenção"
            body = f"{at_risk_count} {aluno_txt} sem aparecer há mais de 7 dias. Que tal dar um alô?"

            # Notificação in-app sempre (independente de ter token FCM)
            from app.services.notification_service import create_notifications_for_academy_students

            await create_notifications_for_academy_students(
                db,
                academy_id=academy_id,
                type="at_risk_alert",
                title=title,
                body=body,
                roles=_STAFF_ROLES,
            )

            # Tokens dos professores/gestores desta academia
            tokens_rows = (
                (
                    await db.execute(
                        select(UserDeviceToken.fcm_token)
                        .join(User, User.id == UserDeviceToken.user_id)
                        .where(
                            User.academy_id == academy_id,
                            User.role.in_(list(_STAFF_ROLES)),
                        )
                        .distinct()
                    )
                )
                .scalars()
                .all()
            )

            for token in tokens_rows:
                success, should_drop = await send_fcm_data_message(
                    project_id=settings.FIREBASE_PROJECT_ID,
                    service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                    device_token=token,
                    title=title,
                    body=body,
                    access_token=access_token,
                    data={"type": "at_risk_alert"},
                )
                if should_drop:
                    await delete_device_token(db, fcm_token=token)

        await db.commit()
