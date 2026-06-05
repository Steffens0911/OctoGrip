"""Tasks Celery de execuções de técnica: escalada de confirmações ignoradas para revisão do professor."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select

from app.database import SyncSessionLocal
from app.models.notification import Notification
from app.models.technique_execution import TechniqueExecution
from app.models.user import User
from celery_app import celery_app

ESCALATION_DAYS = 4
_NOTIF_TYPE = "pending_review_reminder"


@celery_app.task(bind=True, max_retries=1, time_limit=120)
def escalate_pending_executions_to_professor(self) -> None:
    """Move execuções com pending_confirmation ignoradas por 4+ dias para pending_professor_review."""
    cutoff = datetime.now(UTC) - timedelta(days=ESCALATION_DAYS)
    with SyncSessionLocal() as db:
        executions = (
            db.execute(
                select(TechniqueExecution).where(
                    TechniqueExecution.status == "pending_confirmation",
                    TechniqueExecution.created_at <= cutoff,
                )
            )
            .scalars()
            .all()
        )
        changed = 0
        for execution in executions:
            execution.status = "pending_professor_review"
            changed += 1
        if changed:
            db.commit()


@celery_app.task(bind=True, max_retries=1, time_limit=120)
def notify_professor_pending_reviews(self) -> None:
    """Notifica uma vez por dia professores/gerentes que têm indicações aguardando revisão."""
    today_utc = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0)

    with SyncSessionLocal() as db:
        # Academias com pelo menos uma execução pendente de revisão
        academy_ids = (
            db.execute(
                select(User.academy_id)
                .join(TechniqueExecution, TechniqueExecution.user_id == User.id)
                .where(TechniqueExecution.status == "pending_professor_review")
                .distinct()
            )
            .scalars()
            .all()
        )

        for academy_id in academy_ids:
            # Conta pendências da academia
            count = db.execute(
                select(func.count())
                .select_from(TechniqueExecution)
                .join(User, TechniqueExecution.user_id == User.id)
                .where(
                    TechniqueExecution.status == "pending_professor_review",
                    User.academy_id == academy_id,
                )
            ).scalar_one()

            # Professores e gerentes da academia
            staff = (
                db.execute(
                    select(User.id).where(
                        User.academy_id == academy_id,
                        User.role.in_(["professor", "gerente_academia"]),
                    )
                )
                .scalars()
                .all()
            )

            for user_id in staff:
                # Deduplicação: já foi notificado hoje?
                already = db.execute(
                    select(func.count())
                    .select_from(Notification)
                    .where(
                        Notification.user_id == user_id,
                        Notification.type == _NOTIF_TYPE,
                        Notification.created_at >= today_utc,
                    )
                ).scalar_one()
                if already:
                    continue

                label = "indicação" if count == 1 else "indicações"
                db.add(
                    Notification(
                        user_id=user_id,
                        type=_NOTIF_TYPE,
                        title="Revisão de indicações pendente",
                        body=f"Você tem {count} {label} aguardando revisão na sua academia.",
                    )
                )

        db.commit()
