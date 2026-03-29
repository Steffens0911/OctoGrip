"""Serviço de execuções de técnica: criar, listar pendentes, confirmar e calcular pontos."""
import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AppError, NotFoundError, UserNotFoundError
from app.core.graduation import calculate_points_awarded, graduation_label
from app.core.points_limits import clamp_reward_points
from app.models import (
    Academy,
    Lesson,
    LessonProgress,
    Mission,
    MissionUsage,
    Technique,
    TechniqueExecution,
    User,
)

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


async def _validate_execution_inputs(
    db: AsyncSession,
    user_id: UUID,
    opponent_id: UUID,
    mission_id: UUID | None = None,
    lesson_id: UUID | None = None,
    technique_id: UUID | None = None,
) -> tuple[User, User]:
    """Valida usuários e adversário para criação de execução."""
    filled = sum(1 for x in (mission_id, lesson_id, technique_id) if x is not None)
    if filled != 1:
        raise AppError("Informe exatamente um de mission_id, lesson_id ou technique_id.", status_code=400)

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise UserNotFoundError("Usuário não encontrado.")
    opponent = (await db.execute(select(User).where(User.id == opponent_id))).scalar_one_or_none()
    if not opponent:
        raise UserNotFoundError("Adversário não encontrado.")
    if user.academy_id is None or opponent.academy_id != user.academy_id:
        raise AppError("O adversário deve ser da mesma academia.", status_code=400)
    if user_id == opponent_id:
        raise AppError("Não pode aplicar a técnica em si mesmo.", status_code=400)
    
    return user, opponent


async def _create_technique_execution(
    db: AsyncSession,
    user_id: UUID,
    opponent_id: UUID,
    technique_id: UUID,
    academy_id: UUID,
    usage_type: str,
) -> TechniqueExecution:
    """Cria execução para technique_id."""
    technique = (
        await db.execute(
            select(Technique).where(
                Technique.id == technique_id,
                Technique.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not technique:
        raise NotFoundError("Técnica não encontrada.")
    if technique.academy_id != academy_id:
        raise AppError("A técnica deve pertencer à academia do usuário.", status_code=400)
    
    execution = TechniqueExecution(
        user_id=user_id,
        mission_id=None,
        lesson_id=None,
        technique_id=technique_id,
        opponent_id=opponent_id,
        usage_type=usage_type,
        status="pending_confirmation",
        outcome=None,
        points_awarded=None,
        confirmed_at=None,
        confirmed_by=None,
    )
    return execution


async def _create_mission_execution(
    db: AsyncSession,
    user_id: UUID,
    opponent_id: UUID,
    mission_id: UUID,
    usage_type: str,
    user_academy_id: UUID | None = None,
) -> TechniqueExecution:
    """Cria execução para mission_id."""
    mission = (
        await db.execute(
            select(Mission)
            .options(selectinload(Mission.technique))
            .where(Mission.id == mission_id, Mission.deleted_at.is_(None))
        )
    ).unique().scalars().first()
    if not mission:
        raise NotFoundError("Missão não encontrada.")
    if not _mission_active_today(mission):
        raise AppError("Missão não está ativa no período atual.", status_code=400)
    
    # Validar isolamento de academy: não-admins só podem executar missões da própria academy
    if user_academy_id is not None:
        if mission.academy_id is not None and mission.academy_id != user_academy_id:
            raise AppError("Você só pode executar missões da sua academia.", status_code=403)
    
    # Verificar se já existe execução confirmada
    existing_confirmed = (
        await db.execute(
            select(TechniqueExecution).where(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.mission_id == mission_id,
                TechniqueExecution.status == "confirmed",
            )
        )
    ).scalar_one_or_none()
    if existing_confirmed:
        raise AppError(
            "Você já concluiu esta posição; poderá concluir novamente quando a academia atualizar as missões.",
            status_code=400,
        )
    
    # Verificar se já existe execução pendente
    existing_pending = (
        await db.execute(
            select(TechniqueExecution).where(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.mission_id == mission_id,
                TechniqueExecution.status == "pending_confirmation",
            )
        )
    ).scalar_one_or_none()
    if existing_pending:
        raise AppError(
            "Já existe uma solicitação aguardando aceite do oponente para esta missão.",
            status_code=400,
        )
    
    execution = TechniqueExecution(
        user_id=user_id,
        mission_id=mission_id,
        lesson_id=None,
        technique_id=None,
        opponent_id=opponent_id,
        usage_type=usage_type,
        status="pending_confirmation",
        outcome=None,
        points_awarded=None,
        confirmed_at=None,
        confirmed_by=None,
    )
    return execution


async def _create_lesson_execution(
    db: AsyncSession,
    user_id: UUID,
    opponent_id: UUID,
    lesson_id: UUID,
    usage_type: str,
    user_academy_id: UUID | None = None,
) -> TechniqueExecution:
    """Cria execução para lesson_id."""
    lesson = (
        await db.execute(
            select(Lesson)
            .options(selectinload(Lesson.technique))
            .where(Lesson.id == lesson_id, Lesson.deleted_at.is_(None))
        )
    ).unique().scalars().first()
    if not lesson:
        raise NotFoundError("Lição não encontrada.")
    
    # Validar isolamento de academy: não-admins só podem executar lições da própria academy
    if user_academy_id is not None:
        lesson_academy_id = lesson.academy_id or (lesson.technique.academy_id if lesson.technique else None)
        if lesson_academy_id is not None and lesson_academy_id != user_academy_id:
            raise AppError("Você só pode executar lições da sua academia.", status_code=403)
    
    # Verificar se já existe execução pendente
    existing_pending_lesson = (
        await db.execute(
            select(TechniqueExecution).where(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.lesson_id == lesson_id,
                TechniqueExecution.status == "pending_confirmation",
            )
        )
    ).scalar_one_or_none()
    if existing_pending_lesson:
        raise AppError(
            "Já existe uma solicitação aguardando aceite do oponente para esta lição.",
            status_code=400,
        )
    
    execution = TechniqueExecution(
        user_id=user_id,
        mission_id=None,
        lesson_id=lesson_id,
        technique_id=None,
        opponent_id=opponent_id,
        usage_type=usage_type,
        status="pending_confirmation",
        outcome=None,
        points_awarded=None,
        confirmed_at=None,
        confirmed_by=None,
    )
    return execution


async def create_execution(
    db: AsyncSession,
    user_id: UUID,
    opponent_id: UUID,
    usage_type: str = "after_training",
    *,
    mission_id: UUID | None = None,
    lesson_id: UUID | None = None,
    technique_id: UUID | None = None,
    academy_id: UUID | None = None,
) -> TechniqueExecution:
    """
    Cria execução pendente de confirmação. Aceita exatamente um de mission_id, lesson_id ou technique_id.
    Valida: user e opponent da mesma academia; se technique_id, técnica existe e pertence à academia.
    """
    # Validar inputs
    user, opponent = await _validate_execution_inputs(
        db, user_id, opponent_id, mission_id, lesson_id, technique_id
    )
    
    if usage_type not in ("before_training", "after_training"):
        usage_type = "after_training"

    # Criar execução baseada no tipo
    if technique_id is not None:
        if academy_id is None:
            raise AppError("academy_id é obrigatório quando technique_id é informado.", status_code=400)
        # Validar que academy_id do usuário corresponde ao informado (não-admins)
        if user.role != "administrador" and user.academy_id != academy_id:
            raise AppError("A academia informada deve ser a sua academia.", status_code=403)
        execution = await _create_technique_execution(
            db, user_id, opponent_id, technique_id, academy_id, usage_type
        )
    elif mission_id is not None:
        execution = await _create_mission_execution(
            db, user_id, opponent_id, mission_id, usage_type, user_academy_id=user.academy_id
        )
    else:
        execution = await _create_lesson_execution(
            db, user_id, opponent_id, lesson_id, usage_type, user_academy_id=user.academy_id
        )

    db.add(execution)
    await db.commit()
    await db.refresh(execution)
    logger.info(
        "create_execution",
        extra={"execution_id": str(execution.id), "user_id": str(user_id), "opponent_id": str(opponent_id)},
    )
    return execution


async def count_pending_confirmations(db: AsyncSession, opponent_id: UUID) -> int:
    """Retorna o número de execuções pendentes de confirmação para o adversário (uma query)."""
    result = await db.scalar(
        select(func.count(TechniqueExecution.id)).where(
            TechniqueExecution.opponent_id == opponent_id,
            TechniqueExecution.status == "pending_confirmation",
        )
    )
    return result or 0


async def list_pending_confirmations(
    db: AsyncSession,
    opponent_id: UUID,
    offset: int = 0,
    limit: int = 100,
):
    """Lista execuções onde opponent_id é o usuário e status = pending_confirmation com paginação."""
    limit = min(max(1, limit), 500)  # Máximo 500 por página
    offset = max(0, offset)
    return (
        await db.execute(
            select(TechniqueExecution)
            .options(
                selectinload(TechniqueExecution.user),
                selectinload(TechniqueExecution.mission).selectinload(Mission.technique),
                selectinload(TechniqueExecution.lesson).selectinload(Lesson.technique),
                selectinload(TechniqueExecution.technique),
                selectinload(TechniqueExecution.opponent),
            )
            .where(
                TechniqueExecution.opponent_id == opponent_id,
                TechniqueExecution.status == "pending_confirmation",
            )
            .order_by(TechniqueExecution.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).unique().scalars().all()


async def list_my_executions(
    db: AsyncSession,
    user_id: UUID,
    offset: int = 0,
    limit: int = 100,
):
    """Lista execuções criadas pelo usuário (executor), todos os status, com paginação."""
    limit = min(max(1, limit), 500)  # Máximo 500 por página
    offset = max(0, offset)
    return (
        await db.execute(
            select(TechniqueExecution)
            .options(
                selectinload(TechniqueExecution.user),
                selectinload(TechniqueExecution.mission).selectinload(Mission.technique),
                selectinload(TechniqueExecution.lesson).selectinload(Lesson.technique),
                selectinload(TechniqueExecution.technique),
                selectinload(TechniqueExecution.opponent),
            )
            .where(TechniqueExecution.user_id == user_id)
            .order_by(TechniqueExecution.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).unique().scalars().all()


async def get_execution(db: AsyncSession, execution_id: UUID) -> TechniqueExecution | None:
    return (
        await db.execute(
            select(TechniqueExecution)
            .options(
                selectinload(TechniqueExecution.opponent),
                selectinload(TechniqueExecution.mission).selectinload(Mission.technique),
                selectinload(TechniqueExecution.mission).selectinload(Mission.lesson),
                selectinload(TechniqueExecution.lesson).selectinload(Lesson.technique),
                selectinload(TechniqueExecution.technique),
            )
            .where(TechniqueExecution.id == execution_id)
        )
    ).unique().scalars().first()


async def _get_base_points_for_execution(
    db: AsyncSession,
    execution: TechniqueExecution,
) -> int | None:
    """
    Retorna base_points da execução (technique, lesson ou mission).
    Para missions, considera multiplicadores da academia se aplicável.
    """
    # Técnica direta
    if execution.technique_id and execution.technique:
        return getattr(execution.technique, "base_points", None)
    
    # Lição
    if execution.lesson_id and execution.lesson:
        return getattr(execution.lesson, "base_points", None)
    
    # Missão (mais complexo - pode ter multiplicador da academia)
    if execution.mission_id and execution.mission:
        mission = execution.mission
        # Verificar multiplicador da academia se mission tem slot_index
        if mission.academy_id is not None and mission.slot_index is not None:
            slot_idx = mission.slot_index
            if 0 <= slot_idx <= 2:
                academy = (
                    await db.execute(select(Academy).where(Academy.id == mission.academy_id))
                ).scalar_one_or_none()
                if academy:
                    mults = (
                        academy.weekly_multiplier_1,
                        academy.weekly_multiplier_2,
                        academy.weekly_multiplier_3,
                    )
                    if slot_idx < len(mults):
                        return clamp_reward_points(mults[slot_idx] or 0)
        
        # Fallback: base_points da lição da missão
        if mission.lesson and getattr(mission.lesson, "base_points", None) is not None:
            return mission.lesson.base_points
        
        # Fallback: base_points da técnica da missão
        if mission.technique:
            return getattr(mission.technique, "base_points", None)
    
    return None


async def confirm_execution(
    db: AsyncSession,
    execution_id: UUID,
    outcome: str,
    confirmed_by_user_id: UUID,
) -> TechniqueExecution:
    """
    Confirma a execução (apenas o adversário). Calcula pontos e atualiza status.
    """
    execution = await get_execution(db, execution_id)
    if not execution:
        raise NotFoundError("Execução não encontrada.")
    if execution.status != "pending_confirmation":
        raise AppError("Esta execução já foi confirmada ou recusada.", status_code=400)
    if execution.opponent_id != confirmed_by_user_id:
        raise AppError("Apenas o adversário pode confirmar esta execução.", status_code=403)
    if outcome not in ("attempted_correctly", "executed_successfully"):
        raise AppError("Outcome deve ser attempted_correctly ou executed_successfully.", status_code=400)

    opponent = execution.opponent
    base_points = await _get_base_points_for_execution(db, execution)
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
    await db.commit()
    await db.refresh(execution)

    # Atualiza o level do usuário após conceder pontos.
    from app.services.leveling_service import refresh_user_level

    await refresh_user_level(db, execution.user_id)

    logger.info(
        "confirm_execution",
        extra={"execution_id": str(execution_id), "outcome": outcome, "points": points},
    )
    return execution


async def reject_execution(
    db: AsyncSession,
    execution_id: UUID,
    rejected_by_user_id: UUID,
    *,
    reason: str | None = None,
) -> TechniqueExecution:
    """Recusa a execução (apenas o adversário). reason='dont_remember' → status rejected_dont_remember."""
    execution = await get_execution(db, execution_id)
    if not execution:
        raise NotFoundError("Execução não encontrada.")
    if execution.status != "pending_confirmation":
        raise AppError("Esta execução já foi confirmada ou recusada.", status_code=400)
    if execution.opponent_id != rejected_by_user_id:
        raise AppError("Apenas o adversário pode recusar esta execução.", status_code=403)
    execution.status = "rejected_dont_remember" if reason == "dont_remember" else "rejected"
    await db.commit()
    await db.refresh(execution)
    return execution


async def total_points_for_user(db: AsyncSession, user_id: UUID) -> int:
    """Soma dos points_awarded de execuções confirmadas (apenas posições da semana, mission_id)
    + conclusões de missão (MissionUsage)
    + conclusões de lição (LessonProgress)
    + vídeos de treinamento diários
    + points_adjustment."""
    exec_points = await db.scalar(
        select(func.coalesce(func.sum(TechniqueExecution.points_awarded), 0)).where(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.mission_id.isnot(None),
        )
    )
    mission_points = await db.scalar(
        select(func.coalesce(func.sum(MissionUsage.points_awarded), 0)).where(
            MissionUsage.user_id == user_id,
        )
    )
    # Pontos de vídeos de treinamento diários
    from app.models import TrainingVideoDailyView

    training_video_points = await db.scalar(
        select(func.coalesce(func.sum(TrainingVideoDailyView.points_awarded), 0)).where(
            TrainingVideoDailyView.user_id == user_id,
        )
    )
    lesson_points = await db.scalar(
        select(func.coalesce(func.sum(LessonProgress.points_awarded), 0)).where(
            LessonProgress.user_id == user_id,
        )
    )
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    adjustment = (user.points_adjustment if user else 0) or 0
    return (
        int(exec_points or 0)
        + int(mission_points or 0)
        + int(training_video_points or 0)
        + int(lesson_points or 0)
        + adjustment
    )


async def batch_total_points_for_users(
    db: AsyncSession, user_ids: list[UUID]
) -> dict[UUID, int]:
    """Retorna mapa user_id -> total de pontos (execuções com mission_id confirmadas
    + MissionUsage + LessonProgress + vídeos de treinamento diários + adjustment)."""
    if not user_ids:
        return {}
    exec_rows = (
        await db.execute(
            select(
                TechniqueExecution.user_id,
                func.coalesce(func.sum(TechniqueExecution.points_awarded), 0).label("pts"),
            )
            .where(
                TechniqueExecution.user_id.in_(user_ids),
                TechniqueExecution.status == "confirmed",
                TechniqueExecution.mission_id.isnot(None),
            )
            .group_by(TechniqueExecution.user_id)
        )
    ).all()
    mission_rows = (
        await db.execute(
            select(
                MissionUsage.user_id,
                func.coalesce(func.sum(MissionUsage.points_awarded), 0).label("pts"),
            )
            .where(MissionUsage.user_id.in_(user_ids))
            .group_by(MissionUsage.user_id)
        )
    ).all()
    # Pontos de vídeos de treinamento diários
    from app.models import TrainingVideoDailyView

    training_rows = (
        await db.execute(
            select(
                TrainingVideoDailyView.user_id,
                func.coalesce(func.sum(TrainingVideoDailyView.points_awarded), 0).label("pts"),
            )
            .where(TrainingVideoDailyView.user_id.in_(user_ids))
            .group_by(TrainingVideoDailyView.user_id)
        )
    ).all()
    lesson_rows = (
        await db.execute(
            select(
                LessonProgress.user_id,
                func.coalesce(func.sum(LessonProgress.points_awarded), 0).label("pts"),
            )
            .where(LessonProgress.user_id.in_(user_ids))
            .group_by(LessonProgress.user_id)
        )
    ).all()
    user_rows = (
        await db.execute(
            select(User.id, func.coalesce(User.points_adjustment, 0).label("adj")).where(
                User.id.in_(user_ids)
            )
        )
    ).all()
    result = {uid: 0 for uid in user_ids}
    for uid, pts in exec_rows:
        result[uid] = result.get(uid, 0) + int(pts or 0)
    for uid, pts in mission_rows:
        result[uid] = result.get(uid, 0) + int(pts or 0)
    for uid, pts in training_rows:
        result[uid] = result.get(uid, 0) + int(pts or 0)
    for uid, pts in lesson_rows:
        result[uid] = result.get(uid, 0) + int(pts or 0)
    for uid, adj in user_rows:
        result[uid] = result.get(uid, 0) + int(adj or 0)
    return result


async def _get_execution_points_rows(
    db: AsyncSession,
    user_id: UUID,
    limit: int,
    offset: int,
) -> list:
    """Busca execuções confirmadas com pontos usando projeção direta."""
    from app.models import Lesson, Mission, Technique, User
    
    return (
        await db.execute(
            select(
                TechniqueExecution.confirmed_at,
                TechniqueExecution.created_at,
                TechniqueExecution.points_awarded,
                Technique.name.label("technique_name"),
                Mission.id.label("mission_id"),
                Mission.technique_id.label("mission_technique_id"),
                Lesson.id.label("lesson_id"),
                Lesson.technique_id.label("lesson_technique_id"),
                User.id.label("opponent_id"),
                User.name.label("opponent_name"),
                User.graduation.label("opponent_grad"),
            )
            .outerjoin(Technique, TechniqueExecution.technique_id == Technique.id)
            .outerjoin(Mission, TechniqueExecution.mission_id == Mission.id)
            .outerjoin(Lesson, TechniqueExecution.lesson_id == Lesson.id)
            .outerjoin(User, TechniqueExecution.opponent_id == User.id)
            .where(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.status == "confirmed",
                TechniqueExecution.points_awarded.isnot(None),
            )
            .order_by(TechniqueExecution.confirmed_at.desc().nullslast())
            .limit(limit)
            .offset(offset)
        )
    ).all()


async def _load_technique_names_for_executions(
    db: AsyncSession,
    mission_ids: list[UUID],
    lesson_ids: list[UUID],
) -> tuple[dict[UUID, str], dict[UUID, str]]:
    """Carrega nomes de técnicas para missões e lições."""
    from app.models import Lesson, Mission, Technique
    
    mission_techniques = {}
    if mission_ids:
        try:
            mission_rows = (
                await db.execute(
                    select(Mission.id, Technique.name.label("technique_name"))
                    .join(Technique, Mission.technique_id == Technique.id)
                    .where(Mission.id.in_(mission_ids))
                )
            ).all()
            mission_techniques = {r.id: r.technique_name for r in mission_rows}
        except Exception as e:
            logger.warning("Failed to load mission techniques", exc_info=e)
    
    lesson_techniques = {}
    if lesson_ids:
        try:
            lesson_rows = (
                await db.execute(
                    select(Lesson.id, Technique.name.label("technique_name"))
                    .join(Technique, Lesson.technique_id == Technique.id)
                    .where(Lesson.id.in_(lesson_ids))
                )
            ).all()
            lesson_techniques = {r.id: r.technique_name for r in lesson_rows}
        except Exception as e:
            logger.warning("Failed to load lesson techniques", exc_info=e)
    
    return mission_techniques, lesson_techniques


def _format_execution_entry(
    exec_row,
    mission_techniques: dict[UUID, str],
    lesson_techniques: dict[UUID, str],
) -> dict:
    """Formata entrada de execução para o log de pontos."""
    dt = exec_row.confirmed_at or exec_row.created_at
    technique_name = exec_row.technique_name
    if not technique_name and exec_row.mission_id:
        technique_name = mission_techniques.get(exec_row.mission_id)
    if not technique_name and exec_row.lesson_id:
        technique_name = lesson_techniques.get(exec_row.lesson_id)
    
    desc = f"Execução confirmada: {technique_name or 'técnica'}"
    if exec_row.opponent_name:
        faixa_label = graduation_label(exec_row.opponent_grad)
        desc += f" (em {exec_row.opponent_name}"
        if faixa_label:
            desc += f" – faixa {faixa_label}"
        desc += ")"
    
    return {
        "date": dt.isoformat() if dt else None,
        "points": exec_row.points_awarded or 0,
        "source": "execution",
        "description": desc,
    }


async def get_points_log(db: AsyncSession, user_id: UUID, limit: int = 100, offset: int = 0):
    """
    Retorna histórico de pontuação (apenas posições da semana: execuções com mission_id + MissionUsage)
    usando UNION ALL em SQL, ordenado por data.
    """
    from sqlalchemy import literal, union_all, text

    exec_query = (
        select(
            func.coalesce(TechniqueExecution.confirmed_at, TechniqueExecution.created_at).label("event_date"),
            TechniqueExecution.points_awarded.label("points"),
            literal("execution").label("source"),
            TechniqueExecution.id.label("ref_id"),
            TechniqueExecution.technique_id.label("technique_id"),
            TechniqueExecution.mission_id.label("mission_id"),
            TechniqueExecution.lesson_id.label("lesson_id"),
            TechniqueExecution.opponent_id.label("opponent_id"),
        )
        .where(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.points_awarded.isnot(None),
            TechniqueExecution.mission_id.isnot(None),
        )
    )

    usage_query = (
        select(
            MissionUsage.completed_at.label("event_date"),
            MissionUsage.points_awarded.label("points"),
            literal("mission").label("source"),
            MissionUsage.id.label("ref_id"),
            literal(None).label("technique_id"),
            literal(None).label("mission_id"),
            literal(None).label("lesson_id"),
            literal(None).label("opponent_id"),
        )
        .where(
            MissionUsage.user_id == user_id,
            MissionUsage.points_awarded.isnot(None),
        )
    )

    # Vídeos de treinamento diários
    from app.models import TrainingVideoDailyView

    training_query = (
        select(
            TrainingVideoDailyView.completed_at.label("event_date"),
            TrainingVideoDailyView.points_awarded.label("points"),
            literal("training_video").label("source"),
            TrainingVideoDailyView.id.label("ref_id"),
            literal(None).label("technique_id"),
            literal(None).label("mission_id"),
            literal(None).label("lesson_id"),
            literal(None).label("opponent_id"),
        )
        .where(
            TrainingVideoDailyView.user_id == user_id,
            TrainingVideoDailyView.points_awarded.isnot(None),
        )
    )

    combined = union_all(exec_query, usage_query, training_query).subquery()
    result = await db.execute(
        select(combined)
        .order_by(combined.c.event_date.desc().nullslast())
        .offset(offset)
        .limit(limit)
    )
    rows = result.all()

    mission_ids = [r.mission_id for r in rows if r.mission_id]
    lesson_ids = [r.lesson_id for r in rows if r.lesson_id]
    opponent_ids = [r.opponent_id for r in rows if r.opponent_id]

    mission_techniques, lesson_techniques = await _load_technique_names_for_executions(
        db, mission_ids, lesson_ids
    )

    technique_names: dict[UUID, str] = {}
    tech_ids = [r.technique_id for r in rows if r.technique_id]
    if tech_ids:
        tech_rows = (await db.execute(
            select(Technique.id, Technique.name).where(Technique.id.in_(tech_ids))
        )).all()
        technique_names = {r.id: r.name for r in tech_rows}

    opponent_info: dict[UUID, tuple[str | None, str | None]] = {}
    if opponent_ids:
        opp_rows = (await db.execute(
            select(User.id, User.name, User.graduation).where(User.id.in_(opponent_ids))
        )).all()
        opponent_info = {r.id: (r.name, r.graduation) for r in opp_rows}

    entries = []
    for r in rows:
        dt = r.event_date
        if r.source == "execution":
            tech_name = technique_names.get(r.technique_id) if r.technique_id else None
            if not tech_name and r.mission_id:
                tech_name = mission_techniques.get(r.mission_id)
            if not tech_name and r.lesson_id:
                tech_name = lesson_techniques.get(r.lesson_id)
            desc = f"Execução confirmada: {tech_name or 'técnica'}"
            if r.opponent_id and r.opponent_id in opponent_info:
                opp_name, opp_grad = opponent_info[r.opponent_id]
                if opp_name:
                    faixa_label = graduation_label(opp_grad)
                    desc += f" (em {opp_name}"
                    if faixa_label:
                        desc += f" – faixa {faixa_label}"
                    desc += ")"
            entries.append({
                "date": dt.isoformat() if dt else None,
                "points": r.points or 0,
                "source": "execution",
                "description": desc,
            })
        elif r.source == "mission":
            entries.append({
                "date": dt.isoformat() if dt else None,
                "points": r.points or 0,
                "source": "mission",
                "description": "Conclusão de missão",
            })
        else:
            entries.append({
                "date": dt.isoformat() if dt else None,
                "points": r.points or 0,
                "source": "training_video",
                "description": "Vídeo de campo de treinamento",
            })

    return entries
