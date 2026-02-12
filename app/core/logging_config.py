"""
Logs estruturados: formato consistente para facilitar leitura e filtro.
Uso nos services: logger.info("mensagem", extra={"chave": "valor"})
"""
import logging
import sys

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


def setup_logging(level: str = "INFO") -> None:
    """
    Configura logging da aplicação: stdout, formato estruturado.
    Chamar uma vez no startup (ex.: lifespan da FastAPI).
    """
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    if not root.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(root.level)
        fmt = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
        handler.setFormatter(StructuredFormatter(fmt, datefmt="%Y-%m-%d %H:%M:%S"))
        root.addHandler(handler)
