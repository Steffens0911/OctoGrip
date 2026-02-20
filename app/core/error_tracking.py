"""
Configuração opcional de Sentry para error tracking.
"""
import logging
import os

logger = logging.getLogger(__name__)

_sentry_initialized = False


def init_sentry(dsn: str | None = None) -> None:
    """
    Inicializa Sentry se DSN estiver configurado.
    
    Args:
        dsn: DSN do Sentry (opcional, pode vir de variável de ambiente SENTRY_DSN)
    """
    global _sentry_initialized
    
    if _sentry_initialized:
        return
    
    sentry_dsn = dsn or os.getenv("SENTRY_DSN")
    
    if not sentry_dsn:
        logger.debug("Sentry não configurado (SENTRY_DSN não definido)")
        return
    
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
        from sentry_sdk.integrations.logging import LoggingIntegration
        
        # Configurar nível de log para Sentry
        logging_level = os.getenv("LOG_LEVEL", "INFO").upper()
        sentry_logging_level = logging.ERROR  # Apenas erros por padrão
        
        if logging_level == "DEBUG":
            sentry_logging_level = logging.WARNING
        elif logging_level == "INFO":
            sentry_logging_level = logging.ERROR
        
        sentry_sdk.init(
            dsn=sentry_dsn,
            integrations=[
                FastApiIntegration(),
                SqlalchemyIntegration(),
                LoggingIntegration(level=sentry_logging_level),
            ],
            traces_sample_rate=0.1,  # 10% das transações
            environment=os.getenv("ENVIRONMENT", "development"),
            # Capturar apenas erros em produção
            before_send=lambda event, hint: event if os.getenv("ENVIRONMENT", "").lower() == "production" else None,
        )
        
        _sentry_initialized = True
        logger.info("Sentry inicializado com sucesso")
        
    except ImportError:
        logger.warning(
            "sentry-sdk não instalado. Instale com: pip install sentry-sdk[fastapi]"
        )
    except Exception as e:
        logger.error("Erro ao inicializar Sentry: %s", e, exc_info=True)
