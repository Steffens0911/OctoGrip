"""Privacidade do titular (LGPD): consentimentos, exportação e eliminação de dados."""

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.database import get_db
from app.models import User
from app.models.user_consent import CONSENT_TYPES
from app.schemas.consent import (
    AccountDeletionResponse,
    ConsentRecordRequest,
    ConsentStatusItem,
    ConsentStatusResponse,
)
from app.services import consent_service, privacy_service

router = APIRouter()


def _client_meta(request: Request) -> tuple[str | None, str | None]:
    """Extrai IP e User-Agent de origem para comprovar consentimento."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        ip = forwarded.split(",")[0].strip()
    else:
        ip = request.client.host if request.client else None
    return ip, request.headers.get("user-agent")


def _build_status(current: dict) -> ConsentStatusResponse:
    items: list[ConsentStatusItem] = []
    for ctype in CONSENT_TYPES:
        row = current.get(ctype)
        current_version = consent_service.current_version_for(ctype)
        granted = bool(row and row.granted)
        doc_version = row.document_version if row else None
        items.append(
            ConsentStatusItem(
                consent_type=ctype,
                granted=granted,
                document_version=doc_version,
                current_version=current_version,
                up_to_date=bool(granted and doc_version == current_version),
                updated_at=row.created_at if row else None,
            )
        )
    return ConsentStatusResponse(items=items)


@router.get("/consents", response_model=ConsentStatusResponse)
async def get_my_consents(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estado vigente de cada consentimento (terms, privacy, biometric)."""
    current = await consent_service.get_current_consents(db, current_user.id)
    return _build_status(current)


@router.post("/consents", response_model=ConsentStatusResponse)
async def record_my_consent(
    body: ConsentRecordRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra a concessão (ou revogação) de um consentimento.

    Para revogar biometria, prefira `DELETE /me/consents/biometric` — além de registrar
    a revogação, ele apaga o dado biométrico já existente.
    """
    ip, ua = _client_meta(request)
    await consent_service.record_consent(
        db,
        user_id=current_user.id,
        consent_type=body.consent_type,
        granted=body.granted,
        document_version=body.document_version,
        ip_address=ip,
        user_agent=ua,
    )
    current = await consent_service.get_current_consents(db, current_user.id)
    return _build_status(current)


@router.delete("/consents/biometric", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_my_biometric_consent(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Revoga o consentimento biométrico e apaga embedding facial + foto facial."""
    ip, ua = _client_meta(request)
    await consent_service.record_consent(
        db,
        user_id=current_user.id,
        consent_type="biometric",
        granted=False,
        ip_address=ip,
        user_agent=ua,
        commit=False,
    )
    await consent_service.purge_biometric_data(db, current_user, commit=True)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/data-export")
async def export_my_data(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Exporta uma cópia dos dados pessoais do titular (direito de acesso/portabilidade)."""
    return await privacy_service.export_user_data(db, current_user)


@router.delete("/account", response_model=AccountDeletionResponse)
async def delete_my_account(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Atende ao direito de eliminação: anonimiza a conta e remove dado biométrico.

    A operação é irreversível. Identificadores (nome, e-mail, senha, avatar, biometria)
    são removidos; registros históricos permanecem de-identificados.
    """
    await privacy_service.anonymize_user(db, current_user)
    return AccountDeletionResponse(
        status="anonymized",
        user_id=str(current_user.id),
        message="Conta anonimizada com sucesso. Seus dados pessoais foram removidos.",
    )
