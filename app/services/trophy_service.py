"""Serviço de troféus: CRUD e cálculo de tier conquistado (ouro/prata/bronze) por execuções confirmadas."""
import logging
from datetime import date
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import AcademyNotFoundError, AppError, TechniqueNotFoundError
from app.models import Academy, Technique, TechniqueExecution, Trophy, User

logger = logging.getLogger(__name__)

# Tiers: ouro = roxa+/prata = azul/bronze = branca (sem repetir adversário)
GOLD_GRADUATIONS = ("purple", "brown", "black")
SILVER_GRADUATIONS = ("blue",)
BRONZE_GRADUATIONS = ("white",)


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


def create_trophy(
    db: Session,
    academy_id: UUID,
    technique_id: UUID,
    name: str,
    start_date: date,
    end_date: date,
    target_count: int,
) -> Trophy:
    """Cria troféu da academia. Valida técnica da academia e datas coerentes."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise AcademyNotFoundError("Academia não encontrada.")
    technique = db.query(Technique).filter(Technique.id == technique_id).first()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if technique.academy_id != academy_id:
        raise AppError("A técnica deve pertencer à academia.", status_code=400)
    if start_date > end_date:
        raise AppError("start_date deve ser anterior ou igual a end_date.", status_code=400)
    trophy = Trophy(
        academy_id=academy_id,
        technique_id=technique_id,
        name=name.strip(),
        start_date=start_date,
        end_date=end_date,
        target_count=target_count,
    )
    db.add(trophy)
    db.commit()
    db.refresh(trophy)
    return trophy


def list_trophies_by_academy(db: Session, academy_id: UUID) -> list[Trophy]:
    """Lista troféus da academia ordenados por nome."""
    return (
        db.query(Trophy)
        .options(joinedload(Trophy.technique))
        .filter(Trophy.academy_id == academy_id)
        .order_by(Trophy.name)
        .all()
    )


def _load_confirmed_executions_for_user(
    db: Session, user_id: UUID
) -> list[TechniqueExecution]:
    """Carrega todas as execuções confirmadas do usuário uma única vez (para reuso na galeria)."""
    return (
        db.query(TechniqueExecution)
        .options(
            joinedload(TechniqueExecution.opponent),
            joinedload(TechniqueExecution.mission),
            joinedload(TechniqueExecution.lesson),
        )
        .filter(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.confirmed_at.isnot(None),
        )
        .all()
    )


def _executions_in_period_for_trophy(
    db: Session, user_id: UUID, trophy: Trophy
) -> list[TechniqueExecution]:
    """Retorna execuções confirmadas do user na técnica e período do troféu (chamada única por user)."""
    executions = _load_confirmed_executions_for_user(db, user_id)
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
    """Retorna gold_count, silver_count, bronze_count a partir de lista de execuções em período."""
    gold_count = sum(
        1
        for e in in_period
        if e.opponent
        and e.opponent.graduation
        and e.opponent.graduation.strip().lower() in GOLD_GRADUATIONS
    )
    silver_count = sum(
        1
        for e in in_period
        if e.opponent
        and e.opponent.graduation
        and e.opponent.graduation.strip().lower() in SILVER_GRADUATIONS
    )
    white_opponent_ids = set()
    for e in in_period:
        if (
            e.opponent
            and e.opponent.graduation
            and e.opponent.graduation.strip().lower() in BRONZE_GRADUATIONS
        ):
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


def compute_trophy_counts(
    db: Session,
    user_id: UUID,
    trophy: Trophy,
) -> dict:
    """
    Retorna gold_count, silver_count, bronze_count para o usuário no troféu.
    Ouro: execuções em adversários roxa/marrom/preta.
    Prata: execuções em adversários azuis.
    Bronze: adversários brancos distintos.
    """
    in_period = _executions_in_period_for_trophy(db, user_id, trophy)
    gold_count = sum(
        1
        for e in in_period
        if e.opponent
        and e.opponent.graduation
        and e.opponent.graduation.strip().lower() in GOLD_GRADUATIONS
    )
    silver_count = sum(
        1
        for e in in_period
        if e.opponent
        and e.opponent.graduation
        and e.opponent.graduation.strip().lower() in SILVER_GRADUATIONS
    )
    white_opponent_ids = set()
    for e in in_period:
        if (
            e.opponent
            and e.opponent.graduation
            and e.opponent.graduation.strip().lower() in BRONZE_GRADUATIONS
        ):
            white_opponent_ids.add(e.opponent_id)
    bronze_count = len(white_opponent_ids)
    return {"gold_count": gold_count, "silver_count": silver_count, "bronze_count": bronze_count}


def compute_user_trophy_tier(
    db: Session,
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
    counts = compute_trophy_counts(db, user_id, trophy)
    target = trophy.target_count
    if counts["gold_count"] >= target:
        return "gold"
    if counts["silver_count"] >= target:
        return "silver"
    if counts["bronze_count"] >= target:
        return "bronze"
    return None


def list_user_trophies_with_earned(
    db: Session,
    user_id: UUID,
) -> list[dict]:
    """
    Lista troféus das academias do usuário com o tier conquistado (para galeria no perfil).
    Carrega execuções confirmadas uma única vez e reutiliza em memória (3 consultas no total).
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.academy_id:
        return []

    trophies = list_trophies_by_academy(db, user.academy_id)
    all_executions = _load_confirmed_executions_for_user(db, user_id)

    result = []
    for t in trophies:
        in_period = _executions_in_period_from_list(all_executions, t)
        counts = _compute_counts_from_executions(in_period)
        tier = _tier_from_counts(counts, t.target_count)
        technique_name = t.technique.name if t.technique else None
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
                "earned_tier": tier,
                "gold_count": counts["gold_count"],
                "silver_count": counts["silver_count"],
                "bronze_count": counts["bronze_count"],
            }
        )
    return result
