"""Schemas para documentos legais públicos (Termos, Política de Privacidade, Aviso de Biometria)."""

from pydantic import BaseModel, Field


class LegalDocumentResponse(BaseModel):
    """Documento legal versionado, servido publicamente pela API."""

    slug: str = Field(description="Identificador do documento (privacy | terms | biometric).")
    title: str
    version: str = Field(description="Versão vigente (data).")
    contact_email: str = Field(description="Contato do Encarregado de Dados (DPO).")
    content_markdown: str = Field(description="Conteúdo em Markdown para renderização no cliente.")
