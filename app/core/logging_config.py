"""
Logs estruturados: formato consistente para facilitar leitura e filtro.
Uso nos services: logger.info("mensagem", extra={"chave": "valor"})
"""
import json
import logging
import sys
from datetime import datetime

# Atributos padrão do LogRecord; o resto vem de extra={}
_STANDARD_ATTRS = {
    "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
    "module", "lineno", "funcName", "created", "msecs", "relativeCreated",
    "thread", "threadName", "process", "processName", "message",
    "exc_info", "exc_text", "stack_info", "taskName",
}


class StructuredFormatter(logging.Formatter):
    """Formato: timestamp | level | logger | message | key=value ..."""

    def format(self, record: logging.LogRecord) -> str:
        base = super().format(record)
        extra = [f"{k}={v}" for k, v in record.__dict__.items() if k not in _STANDARD_ATTRS]
        if extra:
            return f"{base} | {' '.join(extra)}"
        return base


class JSONFormatter(logging.Formatter):
    """Formato JSON estruturado para logs."""

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Adicionar campos extras
        for k, v in record.__dict__.items():
            if k not in _STANDARD_ATTRS:
                log_data[k] = v

        # Adicionar informações de exceção se houver
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        if record.exc_text:
            log_data["exc_text"] = record.exc_text

        # Adicionar informações de stack se houver
        if record.stack_info:
            log_data["stack"] = record.stack_info

        return json.dumps(log_data, ensure_ascii=False, default=str)


def setup_logging(level: str = "INFO", format_type: str = "text") -> None:
    """
    Configura logging da aplicação: stdout, formato estruturado.
    
    Args:
        level: Nível de log (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format_type: Formato de log ("text" ou "json")
    """
    from app.core.middleware import ContextFilter
    
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    if not root.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(root.level)
        
        if format_type.lower() == "json":
            handler.setFormatter(JSONFormatter())
        else:
            fmt = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
            handler.setFormatter(StructuredFormatter(fmt, datefmt="%Y-%m-%d %H:%M:%S"))
        
        # Adicionar filter para contexto (request_id, user_id, academy_id)
        handler.addFilter(ContextFilter())
        
        root.addHandler(handler)
