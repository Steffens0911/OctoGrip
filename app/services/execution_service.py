"""Serviço de execuções de técnica: criar, listar pendentes, confirmar e calcular pontos."""
import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import AppError, NotFoundError, UserNotFoundError
from app.core.graduation import calculate_points_awarded, graduation_label
from app.models import Academy, Lesson, Mission, TechniqueExecution, User

logger = logging.getLogger(__name__)


def _mission_active_today(mission: Mission) -> bool:
    if not mission.is_active:
        return False
    if mission.slot_index is not None and mission.academy_id is not None:
        return True
    today = date.today()
    return (
        mission.start_date is not None
        and mission.end_date is not None
        and mission.start_date <= today <= mission.end_date
    )


def create_execution(
    db: Session,
    user_id: UUID,
    opponent_id: UUID,
    usage_type: str = "after_training",
    *,
    mission_id: UUID | None = None,
    lesson_id: UUID | None = None,
) -> TechniqueExecution:
    """
    Cria execução pendente de confirmação. Aceita mission_id ou lesson_id (exatamente um).
    Valida: user e opponent da mesma academia; se mission_id, missão ativa no período;
    se lesson_id, lição existe e (opcional) é a visível da academia.
    """
    if (mission_id is None) == (lesson_id is None):
        raise AppError("Informe exatamente um de mission_id ou lesson_id.", status_code=400)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise UserNotFoundError("Usuário não encontrado.")
    opponent = db.query(User).filter(User.id == opponent_id).first()
    if not opponent:
        raise UserNotFoundError("Adversário não encontrado.")
    if user.academy_id is None or opponent.academy_id != user.academy_id:
        raise AppError("O adversário deve ser da mesma academia.", status_code=400)
    if user_id == opponent_id:
        raise AppError("Não pode aplicar a técnica em si mesmo.", status_code=400)

    if usage_type not in ("before_training", "after_training"):
        usage_type = "after_training"

    if mission_id is not None:
        mission = (
            db.query(Mission)
            .options(joinedload(Mission.technique))
            .filter(Mission.id == mission_id)
            .first()
        )
        if not mission:
            raise NotFoundError("Missão não encontrada.")
        if not _mission_active_today(mission):
            raise AppError("Missão não está ativa no período atual.", status_code=400)
        existing_confirmed = (
            db.query(TechniqueExecution)
            .filter(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.mission_id == mission_id,
                TechniqueExecution.status == "confirmed",
            )
            .first()
        )
        if existing_confirmed:
            raise AppError(
                "Você já concluiu esta posição; poderá concluir novamente quando a academia atualizar as missões.",
                status_code=400,
            )
        existing_pending = (
            db.query(TechniqueExecution)
            .filter(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.mission_id == mission_id,
                TechniqueExecution.status == "pending_confirmation",
            )
            .first()
        )
        if existing_pending:
            raise AppError(
                "Já existe uma solicitação aguardando aceite do oponente para esta missão.",
                status_code=400,
            )
        now = datetime.now(timezone.utc)
        execution = TechniqueExecution(
            user_id=user_id,
            mission_id=mission_id,
            lesson_id=None,
            opponent_id=opponent_id,
            usage_type=usage_type,
            status="pending_confirmation",
            outcome=None,
            points_awarded=None,
            confirmed_at=None,
            confirmed_by=None,
        )
    else:
        lesson = (
            db.query(Lesson)
            .options(joinedload(Lesson.technique))
            .filter(Lesson.id == lesson_id)
            .first()
        )
        if not lesson:
            raise NotFoundError("Lição não encontrada.")
        existing_pending_lesson = (
            db.query(TechniqueExecution)
            .filter(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.lesson_id == lesson_id,
                TechniqueExecution.status == "pending_confirmation",
            )
            .first()
        )
        if existing_pending_lesson:
            raise AppError(
                "Já existe uma solicitação aguardando aceite do oponente para esta lição.",
                status_code=400,
            )
        now = datetime.now(timezone.utc)
        execution = TechniqueExecution(
            user_id=user_id,
            mission_id=None,
            lesson_id=lesson_id,
            opponent_id=opponent_id,
            usage_type=usage_type,
            status="pending_confirmation",
            outcome=None,
            points_awarded=None,
            confirmed_at=None,
            confirmed_by=None,
        )

    db.add(execution)
    db.commit()
    db.refresh(execution)
    logger.info(
        "create_execution",
        extra={"execution_id": str(execution.id), "user_id": str(user_id), "opponent_id": str(opponent_id)},
    )
    return execution


def list_pending_confirmations(db: Session, opponent_id: UUID):
    """Lista execuções onde opponent_id é o usuário e status = pending_confirmation."""
    return (
        db.query(TechniqueExecution)
        .options(
            joinedload(TechniqueExecution.user),
            joinedload(TechniqueExecution.mission).joinedload(Mission.technique),
            joinedload(TechniqueExecution.lesson).joinedload(Lesson.technique),
            joinedload(TechniqueExecution.opponent),
        )
        .filter(
            TechniqueExecution.opponent_id == opponent_id,
            TechniqueExecution.status == "pending_confirmation",
        )
        .order_by(TechniqueExecution.created_at.desc())
        .all()
    )


def list_my_executions(db: Session, user_id: UUID):
    """Lista execuções criadas pelo usuário (executor), todos os status."""
    return (
        db.query(TechniqueExecution)
        .options(
            joinedload(TechniqueExecution.user),
            joinedload(TechniqueExecution.mission).joinedload(Mission.technique),
            joinedload(TechniqueExecution.lesson).joinedload(Lesson.technique),
            joinedload(TechniqueExecution.opponent),
        )
        .filter(TechniqueExecution.user_id == user_id)
        .order_by(TechniqueExecution.created_at.desc())
        .all()
    )


def get_execution(db: Session, execution_id: UUID) -> TechniqueExecution | None:
    return (
        db.query(TechniqueExecution)
        .options(
            joinedload(TechniqueExecution.opponent),
            joinedload(TechniqueExecution.mission).options(
                joinedload(Mission.technique),
                joinedload(Mission.lesson),
            ),
            joinedload(TechniqueExecution.lesson).joinedload(Lesson.technique),
        )
        .filter(TechniqueExecution.id == execution_id)
        .first()
    )


def confirm_execution(
    db: Session,
    execution_id: UUID,
    outcome: str,
    confirmed_by_user_id: UUID,
) -> TechniqueExecution:
    """
    Confirma a execução (apenas o adversário). Calcula pontos e atualiza status.
    """
    execution = get_execution(db, execution_id)
    if not execution:
        raise NotFoundError("Execução não encontrada.")
    if execution.status != "pending_confirmation":
        from app.core.exceptions import AppError
        raise AppError("Esta execução já foi confirmada ou recusada.", status_code=400)
    if execution.opponent_id != confirmed_by_user_id:
        from app.core.exceptions import AppError
        raise AppError("Apenas o adversário pode confirmar esta execução.", status_code=403)
    if outcome not in ("attempted_correctly", "executed_successfully"):
        from app.core.exceptions import AppError
        raise AppError("Outcome deve ser attempted_correctly ou executed_successfully.", status_code=400)

    opponent = execution.opponent
    base_points = None
    if execution.lesson_id and execution.lesson:
        base_points = getattr(execution.lesson, "base_points", None)
    elif execution.mission_id and execution.mission:
        mission = execution.mission
        if mission.academy_id is not None and mission.slot_index is not None:
            slot_idx = mission.slot_index
            if 0 <= slot_idx <= 2:
                academy = db.query(Academy).filter(Academy.id == mission.academy_id).first()
                if academy:
                    mults = (
                        academy.weekly_multiplier_1,
                        academy.weekly_multiplier_2,
                        academy.weekly_multiplier_3,
                    )
                    if slot_idx < len(mults) and mults[slot_idx] >= 1:
                        base_points = mults[slot_idx]
        if base_points is None and mission.lesson and getattr(mission.lesson, "base_points", None) is not None:
            base_points = mission.lesson.base_points
        if base_points is None and mission.technique:
            base_points = getattr(mission.technique, "base_points", None)
    points = calculate_points_awarded(
        opponent.graduation if opponent else None,
        outcome,
        base_points=base_points,
    )
    now = datetime.now(timezone.utc)
    execution.status = "confirmed"
    execution.outcome = outcome
    execution.points_awarded = points
    execution.confirmed_at = now
    execution.confirmed_by = confirmed_by_user_id
    db.commit()
    db.refresh(execution)
    logger.info(
        "confirm_execution",
        extra={"execution_id": str(execution_id), "outcome": outcome, "points": points},
    )
    return execution


def reject_execution(
    db: Session,
    execution_id: UUID,
    rejected_by_user_id: UUID,
    *,
    reason: str | None = None,
) -> TechniqueExecution:
    """Recusa a execução (apenas o adversário). reason='dont_remember' → status rejected_dont_remember."""
    execution = get_execution(db, execution_id)
    if not execution:
        raise NotFoundError("Execução não encontrada.")
    if execution.status != "pending_confirmation":
        raise AppError("Esta execução já foi confirmada ou recusada.", status_code=400)
    if execution.opponent_id != rejected_by_user_id:
        raise AppError("Apenas o adversário pode recusar esta execução.", status_code=403)
    execution.status = "rejected_dont_remember" if reason == "dont_remember" else "rejected"
    db.commit()
    db.refresh(execution)
    return execution


def total_points_for_user(db: Session, user_id: UUID) -> int:
    """Soma dos points_awarded de execuções confirmadas + conclusões de missão (MissionUsage) + points_adjustment."""
    from sqlalchemy import func

    from app.models import MissionUsage

    exec_points = (
        db.query(func.coalesce(func.sum(TechniqueExecution.points_awarded), 0))
        .filter(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.status == "confirmed",
        )
        .scalar()
    )
    mission_points = (
        db.query(func.coalesce(func.sum(MissionUsage.points_awarded), 0))
        .filter(MissionUsage.user_id == user_id)
        .scalar()
    )
    user = db.query(User).filter(User.id == user_id).first()
    adjustment = (user.points_adjustment if user else 0) or 0
    return int(exec_points or 0) + int(mission_points or 0) + adjustment


def get_points_log(db: Session, user_id: UUID, limit: int = 100):
    """
    Retorna histórico de pontuação do usuário: execuções confirmadas e mission_usages,
    ordenados por data (mais recente primeiro). Cada item: date, points, source, description.
    """
    from app.models import Mission, MissionUsage

    rows = []
    for e in (
        db.query(TechniqueExecution)
        .options(
            joinedload(TechniqueExecution.opponent),
            joinedload(TechniqueExecution.mission).joinedload(Mission.technique),
            joinedload(TechniqueExecution.lesson).joinedload(Lesson.technique),
        )
        .filter(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.points_awarded.isnot(None),
        )
        .order_by(TechniqueExecution.confirmed_at.desc().nullslast())
        .limit(limit)
        .all()
    ):
        dt = e.confirmed_at or e.created_at
        technique_name = None
        if e.mission and e.mission.technique:
            technique_name = e.mission.technique.name
        elif e.lesson and e.lesson.technique:
            technique_name = e.lesson.technique.name
        opponent_name = e.opponent.name if e.opponent else None
        opponent_grad = e.opponent.graduation if e.opponent else None
        desc = f"Execução confirmada: {technique_name or 'técnica'}"
        if opponent_name:
            faixa_label = graduation_label(opponent_grad)
            desc += f" (em {opponent_name}"
            if faixa_label:
                desc += f" – faixa {faixa_label}"
            desc += ")"
        rows.append(
            {
                "date": dt.isoformat() if dt else None,
                "points": e.points_awarded or 0,
                "source": "execution",
                "description": desc,
            }
        )
    for u in (
        db.query(MissionUsage)
        .filter(MissionUsage.user_id == user_id, MissionUsage.points_awarded.isnot(None))
        .order_by(MissionUsage.completed_at.desc())
        .limit(limit)
        .all()
    ):
        rows.append(
            {
                "date": u.completed_at.isoformat() if u.completed_at else None,
                "points": u.points_awarded or 0,
                "source": "mission",
                "description": "Conclusão de missão",
            }
        )
    rows.sort(key=lambda r: (r["date"] or ""), reverse=True)
    return rows[:limit]
