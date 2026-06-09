"""Envio de e-mails transacionais via Resend."""

import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_RESEND_API_URL = "https://api.resend.com/emails"


async def send_password_reset_email(to_email: str, reset_url: str) -> None:
    """Envia o e-mail de recuperação de senha via Resend.

    Lança exceção se o envio falhar (deixe o caller decidir o que fazer).
    Em modo de desenvolvimento (RESEND_API_KEY ausente), apenas loga a URL.
    """
    if not settings.RESEND_API_KEY:
        logger.warning(
            "RESEND_API_KEY não configurado — e-mail de reset não enviado (modo dev).",
            extra={"to": to_email, "reset_url": reset_url},
        )
        return

    html_body = f"""
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
      <h2 style="color: #1a1a2e;">Redefinição de senha — Octogrip</h2>
      <p>Recebemos uma solicitação para redefinir a sua senha.</p>
      <p>Clique no botão abaixo para criar uma nova senha. O link expira em
         <strong>{settings.PASSWORD_RESET_EXPIRE_MINUTES} minutos</strong>.</p>
      <p style="text-align: center; margin: 32px 0;">
        <a href="{reset_url}"
           style="background-color: #6c63ff; color: #fff; padding: 14px 28px;
                  border-radius: 8px; text-decoration: none; font-size: 16px;">
          Redefinir senha
        </a>
      </p>
      <p style="color: #666; font-size: 13px;">
        Se você não solicitou a redefinição, ignore este e-mail — sua senha permanece a mesma.
      </p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
      <p style="color: #aaa; font-size: 12px; text-align: center;">Octogrip &bull; Plataforma de Jiu-Jitsu</p>
    </div>
    """

    payload = {
        "from": settings.RESEND_FROM_EMAIL,
        "to": [to_email],
        "subject": "Redefinição de senha — Octogrip",
        "html": html_body,
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            _RESEND_API_URL,
            json=payload,
            headers={"Authorization": f"Bearer {settings.RESEND_API_KEY}"},
        )

    if response.status_code not in (200, 201):
        logger.error(
            "Falha ao enviar e-mail via Resend",
            extra={"status": response.status_code, "body": response.text, "to": to_email},
        )
        raise RuntimeError(f"Resend retornou {response.status_code}: {response.text}")

    logger.info("E-mail de reset enviado", extra={"to": to_email})
