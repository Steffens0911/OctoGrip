"""Serviço de troféus: CRUD e cálculo de tier conquistado (ouro/prata/bronze) por execuções confirmadas."""
import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AcademyNotFoundError, AppError, TechniqueNotFoundError, TrophyNotFoundError
from app.core.graduation import meets_minimum_graduation
from app.models import Academy, MissionUsage, Technique, TechniqueExecution, Trophy, User
from app.services.execution_service import total_points_for_user

logger = logging.getLogger(__name__)

GOLD_GRADUATIONS = ("purple", "brown", "black", "roxa", "marrom", "preta")
SILVER_GRADUATIONS = ("blue", "azul")
BRONZE_GRADUATIONS = ("white", "branca")


def _graduation_to_tier(graduation: str | None) -> str | None:
    """Retorna 'bronze', 'silver' ou 'gold' conforme a faixa do adversário. None/vazio → bronze (conta)."""
    if not graduation or not graduation.strip():
        return "bronze"
    g = graduation.strip().lower()
    if g in GOLD_GRADUATIONS:
        return "gold"
    if g in SILVER_GRADUATIONS:
        return "silver"
    if g in BRONZE_GRADUATIONS:
        return "bronze"
    return "bronze"


def _execution_technique_id(execution: TechniqueExecution) -> UUID | None:
    """Retorna technique_id da execução (via technique, mission ou lesson)."""
    if execution.technique_id:
        return execution.technique_id
    if execution.mission_id and execution.mission and execution.mission.technique_id:
        return execution.mission.technique_id
    if execution.lesson_id and execution.lesson and execution.lesson.technique_id:
        return execution.lesson.technique_id
    return None


def _confirmed_at_date(execution: TechniqueExecution) -> date | None:
    """Retorna a data (sem hora) de confirmed_at."""
    if not execution.confirmed_at:
        return None
    return execution.confirmed_at.date()


def _mission_usages_count_in_period_for_technique(
    usages: list[MissionUsage],
    technique_id: UUID,
    start_date: date,
    end_date: date,
) -> int:
    """Conta MissionUsage do usuário cuja missão tem a mesma técnica e completed_at no período."""
    count = 0
    for u in usages:
        if not u.mission or u.mission.technique_id != technique_id:
            continue
        d = u.completed_at.date() if u.completed_at else None
        if d is None or d < start_date or d > end_date:
            continue
        count += 1
    return count


async def create_trophy(
    db: AsyncSession,
    academy_id: UUID,
    technique_id: UUID,
    name: str,
    start_date: date,
    end_date: date,
    target_count: int,
    award_kind: str = "trophy",
    min_duration_days: int | None = None,
    min_points_to_unlock: int = 0,
    min_graduation_to_unlock: str | None = None,
) -> Trophy:
    """Cria troféu ou medalha da academia. Valida técnica, datas e duração mínima para troféu."""
    logger.debug(
        "create_trophy",
        extra={
            "academy_id": str(academy_id),
            "technique_id": str(technique_id),
            "name": name,
            "award_kind": award_kind,
        },
    )
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        raise AcademyNotFoundError("Academia não encontrada.")
    technique = (await db.execute(select(Technique).where(Technique.id == technique_id))).scalar_one_or_none()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if technique.academy_id != academy_id:
        raise AppError("A técnica deve pertencer à academia.", status_code=400)
    if start_date > end_date:
        raise AppError("start_date deve ser anterior ou igual a end_date.", status_code=400)
    if award_kind == "trophy":
        min_days = min_duration_days if min_duration_days is not None else 30
        duration_days = (end_date - start_date).days
        if duration_days < min_days:
            raise AppError(
                f"Troféu exige duração mínima de {min_days} dias. Período informado: {duration_days} dias.",
                status_code=400,
            )
    trophy = Trophy(
        academy_id=academy_id,
        technique_id=technique_id,
        name=name.strip(),
        start_date=start_date,
        end_date=end_date,
        target_count=target_count,
        award_kind=award_kind,
        min_duration_days=min_duration_days if award_kind == "trophy" else None,
        min_points_to_unlock=max(0, min_points_to_unlock),
        min_graduation_to_unlock=(min_graduation_to_unlock.strip().lower() if min_graduation_to_unlock and min_graduation_to_unlock.strip() else None),
    )
    db.add(trophy)
    await db.commit()
    await db.refresh(trophy)
    logger.info(
        "create_trophy",
        extra={
            "trophy_id": str(trophy.id),
            "academy_id": str(academy_id),
            "technique_id": str(technique_id),
            "name": trophy.name,
        },
    )
    return trophy


async def list_trophies_by_academy(db: AsyncSession, academy_id: UUID) -> list[Trophy]:
    """Lista troféus ativos (não soft-deletados) da academia ordenados por nome."""
    return (
        await db.execute(
            select(Trophy)
            .options(selectinload(Trophy.technique))
            .where(Trophy.academy_id == academy_id, Trophy.deleted_at.is_(None))
            .order_by(Trophy.name)
        )
    ).unique().scalars().all()


async def get_trophy(db: AsyncSession, trophy_id: UUID) -> Trophy | None:
    """Obtém troféu por id (inclui soft-deletados)."""
    result = await db.execute(
        select(Trophy)
        .options(selectinload(Trophy.technique))
        .where(Trophy.id == trophy_id),
    )
    return result.scalar_one_or_none()


async def update_trophy(db: AsyncSession, trophy_id: UUID, updates: dict) -> Trophy:
    """Atualiza troféu com campos presentes em ``updates`` (model_dump exclude_unset). Valida como no create."""
    trophy = await get_trophy(db, trophy_id)
    if not trophy or trophy.deleted_at is not None:
        raise TrophyNotFoundError()
    academy_id = trophy.academy_id
    tid = updates["technique_id"] if "technique_id" in updates else trophy.technique_id
    nm = updates["name"].strip() if "name" in updates else trophy.name
    sd = updates["start_date"] if "start_date" in updates else trophy.start_date
    ed = updates["end_date"] if "end_date" in updates else trophy.end_date
    tc = updates["target_count"] if "target_count" in updates else trophy.target_count
    ak = updates["award_kind"] if "award_kind" in updates else trophy.award_kind
    mdd = updates["min_duration_days"] if "min_duration_days" in updates else trophy.min_duration_days
    mpu = updates["min_points_to_unlock"] if "min_points_to_unlock" in updates else trophy.min_points_to_unlock
    if "min_graduation_to_unlock" in updates:
        mgrad = updates["min_graduation_to_unlock"]
        if mgrad is not None and isinstance(mgrad, str) and not mgrad.strip():
            mgrad = None
    else:
        mgrad = trophy.min_graduation_to_unlock

    technique = (await db.execute(select(Technique).where(Technique.id == tid))).scalar_one_or_none()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if technique.academy_id != academy_id:
        raise AppError("A técnica deve pertencer à academia.", status_code=400)
    if sd > ed:
        raise AppError("start_date deve ser anterior ou igual a end_date.", status_code=400)
    if ak == "trophy":
        min_days = mdd if mdd is not None else 30
        duration_days = (ed - sd).days
        if duration_days < min_days:
            raise AppError(
                f"Troféu exige duração mínima de {min_days} dias. Período informado: {duration_days} dias.",
                status_code=400,
            )

    trophy.technique_id = tid
    trophy.name = nm if isinstance(nm, str) else trophy.name
    trophy.start_date = sd
    trophy.end_date = ed
    trophy.target_count = tc
    trophy.award_kind = ak
    trophy.min_duration_days = mdd if ak == "trophy" else None
    trophy.min_points_to_unlock = max(0, mpu)
    trophy.min_graduation_to_unlock = (
        mgrad.strip().lower() if mgrad and str(mgrad).strip() else None
    )

    await db.commit()
    await db.refresh(trophy)
    trophy = (await get_trophy(db, trophy_id)) or trophy
    logger.info(
        "update_trophy",
        extra={"trophy_id": str(trophy_id), "academy_id": str(academy_id)},
    )
    return trophy


async def soft_delete_trophy(db: AsyncSession, trophy_id: UUID) -> None:
    """Marca troféu como removido (soft delete)."""
    trophy = await get_trophy(db, trophy_id)
    if not trophy or trophy.deleted_at is not None:
        raise TrophyNotFoundError()
    trophy.deleted_at = datetime.now(timezone.utc)
    await db.commit()
    logger.info("soft_delete_trophy", extra={"trophy_id": str(trophy_id)})


async def _load_confirmed_executions_for_user(
    db: AsyncSession, user_id: UUID
) -> list[TechniqueExecution]:
    """Carrega todas as execuções confirmadas do usuário uma única vez (para reuso na galeria)."""
    return (
        await db.execute(
            select(TechniqueExecution)
            .options(
                selectinload(TechniqueExecution.opponent),
                selectinload(TechniqueExecution.mission),
                selectinload(TechniqueExecution.lesson),
            )
            .where(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.status == "confirmed",
                TechniqueExecution.confirmed_at.isnot(None),
            )
        )
    ).unique().scalars().all()


async def _executions_in_period_for_trophy(
    db: AsyncSession, user_id: UUID, trophy: Trophy
) -> list[TechniqueExecution]:
    """Retorna execuções confirmadas do user na técnica e período do troféu (chamada única por user)."""
    executions = await _load_confirmed_executions_for_user(db, user_id)
    return _executions_in_period_from_list(executions, trophy)


def _executions_in_period_from_list(
    executions: list[TechniqueExecution], trophy: Trophy
) -> list[TechniqueExecution]:
    """Filtra lista de execuções por técnica e período do troféu (em memória)."""
    in_period = []
    for e in executions:
        tid = _execution_technique_id(e)
        if tid != trophy.technique_id:
            continue
        d = _confirmed_at_date(e)
        if d is None or d < trophy.start_date or d > trophy.end_date:
            continue
        in_period.append(e)
    return in_period


def _compute_counts_from_executions(
    in_period: list[TechniqueExecution],
) -> dict:
    """Retorna gold_count, silver_count, bronze_count a partir de lista de execuções em período.
    Adversário sem faixa (graduation) é tratado como bronze para a execução contar.
    Aceita faixa em inglês (white, blue, ...) ou português (branca, azul, ...).
    """
    gold_count = 0
    silver_count = 0
    white_opponent_ids = set()
    for e in in_period:
        if not e.opponent:
            continue
        tier = _graduation_to_tier(e.opponent.graduation)
        if tier == "gold":
            gold_count += 1
        elif tier == "silver":
            silver_count += 1
        elif tier == "bronze":
            white_opponent_ids.add(e.opponent_id)
    bronze_count = len(white_opponent_ids)
    return {"gold_count": gold_count, "silver_count": silver_count, "bronze_count": bronze_count}


def _tier_from_counts(counts: dict, target: int) -> str | None:
    """Retorna tier conquistado (gold, silver, bronze) a partir dos counts e target."""
    if counts["gold_count"] >= target:
        return "gold"
    if counts["silver_count"] >= target:
        return "silver"
    if counts["bronze_count"] >= target:
        return "bronze"
    return None


async def compute_trophy_counts(
    db: AsyncSession,
    user_id: UUID,
    trophy: Trophy,
) -> dict:
    """
    Retorna gold_count, silver_count, bronze_count para o usuário no troféu.
    Ouro: execuções em adversários roxa/marrom/preta.
    Prata: execuções em adversários azuis.
    Bronze: adversários brancos distintos.
    """
    logger.debug(
        "compute_trophy_counts",
        extra={"user_id": str(user_id), "trophy_id": str(trophy.id)},
    )
    in_period = await _executions_in_period_for_trophy(db, user_id, trophy)
    counts = _compute_counts_from_executions(in_period)
    logger.debug(
        "compute_trophy_counts result",
        extra={"user_id": str(user_id), "trophy_id": str(trophy.id), "counts": counts},
    )
    return counts


async def compute_user_trophy_tier(
    db: AsyncSession,
    user_id: UUID,
    trophy: Trophy,
) -> str | None:
    """
    Calcula o tier conquistado (gold, silver, bronze) para o usuário no troféu.
    Ouro: N execuções confirmadas em adversários roxa/marrom/preta.
    Prata: N execuções em adversários azuis.
    Bronze: N execuções em adversários brancos com opponent_id distinto (não repetir adversário).
    Retorna o maior tier conquistado ou None.
    """
    logger.debug(
        "compute_user_trophy_tier",
        extra={"user_id": str(user_id), "trophy_id": str(trophy.id), "target_count": trophy.target_count},
    )
    counts = await compute_trophy_counts(db, user_id, trophy)
    target = trophy.target_count
    tier = None
    if counts["gold_count"] >= target:
        tier = "gold"
    elif counts["silver_count"] >= target:
        tier = "silver"
    elif counts["bronze_count"] >= target:
        tier = "bronze"
    logger.debug(
        "compute_user_trophy_tier result",
        extra={"user_id": str(user_id), "trophy_id": str(trophy.id), "tier": tier},
    )
    return tier


async def list_user_trophies_with_earned(
    db: AsyncSession,
    user_id: UUID,
) -> list[dict]:
    """
    Lista troféus das academias do usuário com o tier conquistado (para galeria no perfil).
    Carrega execuções confirmadas uma única vez e reutiliza em memória (3 consultas no total).
    """
    logger.debug("list_user_trophies_with_earned", extra={"user_id": str(user_id)})
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user or not user.academy_id:
        logger.debug("list_user_trophies_with_earned no_academy", extra={"user_id": str(user_id)})
        return []

    trophies = await list_trophies_by_academy(db, user.academy_id)
    user_points = await total_points_for_user(db, user_id)
    all_executions = await _load_confirmed_executions_for_user(db, user_id)
    all_mission_usages = (
        await db.execute(
            select(MissionUsage)
            .options(selectinload(MissionUsage.mission))
            .where(MissionUsage.user_id == user_id)
        )
    ).unique().scalars().all()

    logger.debug(
        "list_user_trophies_with_earned loaded",
        extra={
            "user_id": str(user_id),
            "trophies_count": len(trophies),
            "executions_count": len(all_executions),
            "mission_usages_count": len(all_mission_usages),
        },
    )

    result = []
    today = date.today()
    for t in trophies:
        in_period = _executions_in_period_from_list(all_executions, t)
        counts = _compute_counts_from_executions(in_period)
        # Conclusões da missão da semana (MissionUsage) com mesma técnica contam como bronze
        extra_bronze = _mission_usages_count_in_period_for_technique(
            all_mission_usages, t.technique_id, t.start_date, t.end_date
        )
        counts["bronze_count"] += extra_bronze
        tier = _tier_from_counts(counts, t.target_count)
        # Não exibir para o usuário se fora do prazo e não foi conquistado
        if t.end_date < today and tier is None:
            continue
        technique_name = t.technique.name if t.technique else None
        min_pts = getattr(t, "min_points_to_unlock", 0) or 0
        min_grad = getattr(t, "min_graduation_to_unlock", None) or None
        if min_grad and isinstance(min_grad, str) and not min_grad.strip():
            min_grad = None
        points_ok = user_points >= min_pts
        graduation_ok = meets_minimum_graduation(user.graduation, min_grad)
        unlocked = points_ok and graduation_ok
        result.append(
            {
                "trophy_id": str(t.id),
                "technique_id": str(t.technique_id),
                "academy_id": str(user.academy_id) if user.academy_id else None,
                "name": t.name,
                "technique_name": technique_name,
                "start_date": t.start_date.isoformat(),
                "end_date": t.end_date.isoformat(),
                "target_count": t.target_count,
                "award_kind": getattr(t, "award_kind", "trophy"),
                "min_duration_days": getattr(t, "min_duration_days", None),
                "min_points_to_unlock": min_pts,
                "min_graduation_to_unlock": min_grad,
                "unlocked": unlocked,
                "earned_tier": tier,
                "gold_count": counts["gold_count"],
                "silver_count": counts["silver_count"],
                "bronze_count": counts["bronze_count"],
            }
        )
    logger.info(
        "list_user_trophies_with_earned",
        extra={"user_id": str(user_id), "trophies_count": len(result)},
    )
    return result
