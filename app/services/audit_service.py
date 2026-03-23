"""Auditoria: snapshots JSON, histórico e restauração (soft delete + versão por audit_log_id)."""
from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import Boolean, Date, DateTime, Integer, String, Text, and_, func, inspect, or_, select
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, NotFoundError
from app.models import AuditLog, Lesson, Mission, Technique, Trophy

logger = logging.getLogger(__name__)

# Nome exposto na API (case-insensitive) -> modelo ORM
_AUDIT_MODELS: dict[str, type] = {
    "mission": Mission,
    "lesson": Lesson,
    "technique": Technique,
    "trophy": Trophy,
}

_ENTITY_LABEL: dict[type, str] = {
    Mission: "Mission",
    Lesson: "Lesson",
    Technique: "Technique",
    Trophy: "Trophy",
}

AUDIT_ACTION_CREATE = "CREATE"
AUDIT_ACTION_UPDATE = "UPDATE"
AUDIT_ACTION_DELETE = "DELETE"
AUDIT_ACTION_RESTORE = "RESTORE"


def resolve_entity_model(entity: str) -> tuple[str, type]:
    """Retorna (rótulo canônico, classe ORM). Levanta AppError 400 se desconhecido."""
    key = (entity or "").strip().lower()
    model = _AUDIT_MODELS.get(key)
    if not model:
        allowed = ", ".join(sorted(_AUDIT_MODELS))
        raise AppError(f"Entidade não suportada: {entity}. Use uma de: {allowed}.", status_code=400)
    return _ENTITY_LABEL[model], model


def entity_snapshot_row(obj) -> dict:
    """Serializa apenas colunas mapeadas (sem relationships)."""
    mapper = inspect(obj).mapper
    out: dict = {}
    for col in mapper.column_attrs:
        key = col.key
        val = getattr(obj, key, None)
        out[key] = _json_safe(val)
    return out


def _json_safe(val):
    if val is None:
        return None
    if isinstance(val, UUID):
        return str(val)
    if isinstance(val, datetime):
        return val.isoformat()
    if isinstance(val, date):
        return val.isoformat()
    if isinstance(val, bool):
        return val
    if isinstance(val, (int, float, str)):
        return val
    return str(val)


def _deserialize_value(column, raw):
    if raw is None:
        return None
    t = column.type
    if isinstance(t, PG_UUID):
        return UUID(raw) if isinstance(raw, str) else raw
    if isinstance(t, DateTime):
        if isinstance(raw, str):
            s = raw.replace("Z", "+00:00")
            return datetime.fromisoformat(s)
        return raw
    if isinstance(t, Date):
        if isinstance(raw, str):
            return date.fromisoformat(raw[:10])
        return raw
    if isinstance(t, Integer):
        return int(raw)
    if isinstance(t, Boolean):
        return bool(raw)
    if isinstance(t, (String, Text)):
        return str(raw) if raw is not None else None
    return raw


def apply_snapshot_to_instance(instance, data: dict, *, skip_keys: frozenset[str] | None = None) -> None:
    """Aplica dict (ex.: old_data de um log) nas colunas do modelo."""
    skip = skip_keys or frozenset({"id"})
    mapper = inspect(instance).mapper
    for key, raw in data.items():
        if key in skip:
            continue
        if key not in mapper.columns:
            continue
        col = mapper.columns[key]
        setattr(instance, key, _deserialize_value(col, raw))


async def write_audit_log(
    db: AsyncSession,
    *,
    action: str,
    entity_label: str,
    entity_id: UUID,
    old_data: dict | None,
    new_data: dict | None,
    user_id: UUID | None,
) -> None:
    db.add(
        AuditLog(
            user_id=user_id,
            action=action,
            entity=entity_label,
            entity_id=entity_id,
            old_data=old_data,
            new_data=new_data,
        )
    )


async def list_audit_history(
    db: AsyncSession,
    *,
    entity_label: str,
    entity_id: UUID,
    limit: int = 50,
    offset: int = 0,
    action: str | None = None,
    order: str = "asc",
) -> tuple[list[AuditLog], int]:
    """Lista logs da entidade. order=asc: mais antigo primeiro; order=desc: mais recente primeiro."""
    limit = min(max(1, limit), 200)
    offset = max(0, offset)
    order_norm = (order or "asc").strip().lower()
    if order_norm not in ("asc", "desc"):
        order_norm = "asc"
    conditions = [
        AuditLog.entity == entity_label,
        AuditLog.entity_id == entity_id,
    ]
    if action:
        conditions.append(AuditLog.action == action.strip().upper())
    count_stmt = select(func.count()).select_from(AuditLog).where(*conditions)
    total = int((await db.scalar(count_stmt)) or 0)
    order_clause = (
        AuditLog.created_at.desc()
        if order_norm == "desc"
        else AuditLog.created_at.asc()
    )
    stmt = (
        select(AuditLog)
        .where(*conditions)
        .order_by(order_clause)
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return list(rows), total


def _academy_audit_filter(academy_id: UUID):
    """
    Restringe audit_logs a registros cuja entidade pertence à academia (via academy_id
    ou, para lição/missão globais, via técnica da academia).
    """
    techniques_of = select(Technique.id).where(Technique.academy_id == academy_id)
    lessons_of = select(Lesson.id).where(
        or_(
            Lesson.academy_id == academy_id,
            and_(Lesson.academy_id.is_(None), Lesson.technique_id.in_(techniques_of)),
        )
    )
    missions_of = select(Mission.id).where(
        or_(
            Mission.academy_id == academy_id,
            and_(Mission.academy_id.is_(None), Mission.technique_id.in_(techniques_of)),
        )
    )
    trophies_of = select(Trophy.id).where(Trophy.academy_id == academy_id)
    return or_(
        and_(AuditLog.entity == _ENTITY_LABEL[Technique], AuditLog.entity_id.in_(techniques_of)),
        and_(AuditLog.entity == _ENTITY_LABEL[Lesson], AuditLog.entity_id.in_(lessons_of)),
        and_(AuditLog.entity == _ENTITY_LABEL[Mission], AuditLog.entity_id.in_(missions_of)),
        and_(AuditLog.entity == _ENTITY_LABEL[Trophy], AuditLog.entity_id.in_(trophies_of)),
    )


async def list_audit_feed(
    db: AsyncSession,
    *,
    academy_id: UUID | None = None,
    entity_api_key: str | None = None,
    limit: int = 50,
    offset: int = 0,
    action: str | None = None,
    order: str = "desc",
) -> tuple[list[AuditLog], int]:
    """
    Lista logs de auditoria de todas as entidades suportadas, com filtros opcionais.
    academy_id: quando informado, apenas alterações ligadas a essa academia.
    entity_api_key: mission, lesson, technique, trophy (mesmo formato da API).
    """
    limit = min(max(1, limit), 200)
    offset = max(0, offset)
    order_norm = (order or "desc").strip().lower()
    if order_norm not in ("asc", "desc"):
        order_norm = "desc"
    conditions: list = []
    if academy_id is not None:
        conditions.append(_academy_audit_filter(academy_id))
    if entity_api_key:
        entity_label, _ = resolve_entity_model(entity_api_key)
        conditions.append(AuditLog.entity == entity_label)
    if action:
        conditions.append(AuditLog.action == action.strip().upper())

    count_stmt = select(func.count()).select_from(AuditLog)
    stmt = select(AuditLog)
    if conditions:
        combined = and_(*conditions)
        count_stmt = count_stmt.where(combined)
        stmt = stmt.where(combined)
    order_clause = (
        AuditLog.created_at.desc()
        if order_norm == "desc"
        else AuditLog.created_at.asc()
    )
    stmt = stmt.order_by(order_clause).offset(offset).limit(limit)
    total = int((await db.scalar(count_stmt)) or 0)
    rows = (await db.execute(stmt)).scalars().all()
    return list(rows), total


async def restore_entity(
    db: AsyncSession,
    *,
    entity: str,
    entity_id: UUID,
    audit_log_id: UUID | None,
    user_id: UUID | None,
) -> dict:
    """
    - Sem audit_log_id: limpa deleted_at (undelete).
    - Com audit_log_id: aplica snapshot old_data do log (deve ser UPDATE/DELETE da mesma entidade).
    """
    entity_label, model = resolve_entity_model(entity)
    obj = (
        await db.execute(select(model).where(model.id == entity_id))
    ).scalar_one_or_none()
    if not obj:
        raise NotFoundError("Registro não encontrado.")

    before = entity_snapshot_row(obj)

    if audit_log_id is None:
        if getattr(obj, "deleted_at", None) is None:
            raise AppError("Registro já está ativo (não está soft-deletado).", status_code=400)
        obj.deleted_at = None
        after = entity_snapshot_row(obj)
        await write_audit_log(
            db,
            action=AUDIT_ACTION_RESTORE,
            entity_label=entity_label,
            entity_id=entity_id,
            old_data=before,
            new_data=after,
            user_id=user_id,
        )
        await db.commit()
        await db.refresh(obj)
        logger.info(
            "restore_entity undelete",
            extra={"entity": entity_label, "entity_id": str(entity_id)},
        )
        return {"restored": True, "mode": "undelete", "entity": entity_label, "id": str(entity_id)}

    log = (
        await db.execute(
            select(AuditLog).where(
                AuditLog.id == audit_log_id,
                AuditLog.entity == entity_label,
                AuditLog.entity_id == entity_id,
            )
        )
    ).scalar_one_or_none()
    if not log:
        raise NotFoundError("Log de auditoria não encontrado para esta entidade.")
    if log.action not in (AUDIT_ACTION_UPDATE, AUDIT_ACTION_DELETE):
        raise AppError(
            "Só é possível restaurar versão a partir de logs UPDATE ou DELETE (old_data).",
            status_code=400,
        )
    snap = log.old_data
    if not snap:
        raise AppError("Este log não possui old_data para restaurar.", status_code=400)

    apply_snapshot_to_instance(obj, snap)
    obj.deleted_at = None
    after = entity_snapshot_row(obj)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_RESTORE,
        entity_label=entity_label,
        entity_id=entity_id,
        old_data=before,
        new_data=after,
        user_id=user_id,
    )
    await db.commit()
    await db.refresh(obj)
    logger.info(
        "restore_entity from_snapshot",
        extra={"entity": entity_label, "entity_id": str(entity_id), "audit_log_id": str(audit_log_id)},
    )
    return {
        "restored": True,
        "mode": "snapshot",
        "entity": entity_label,
        "id": str(entity_id),
        "from_audit_log_id": str(audit_log_id),
    }
