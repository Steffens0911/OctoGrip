"""Tasks Celery de execuções de técnica: escalada de confirmações ignoradas para revisão do professor."""
from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from app.database import SyncSessionLocal
from app.models.technique_execution import TechniqueExecution
from celery_app import celery_app

ESCALATION_DAYS = 4


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
