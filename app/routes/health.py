import logging
import os
import time

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

try:
    import psutil
except ImportError:
    psutil = None

from app.database import async_engine, get_db
from app.core.metrics import db_connections_active, db_pool_overflow, db_pool_size, memory_usage_bytes

logger = logging.getLogger(__name__)

router = APIRouter()

_IS_PRODUCTION = os.getenv("ENVIRONMENT", "").lower() == "production"


@router.get("")
async def health():
    """Health check simples (sem banco) com métricas básicas."""
    # Coletar métricas de memória
    memory_mb = None
    if psutil:
        try:
            process = psutil.Process()
            memory_info = process.memory_info()
            memory_usage_bytes.set(memory_info.rss)
            memory_mb = round(memory_info.rss / 1024 / 1024, 2)
        except Exception:
            pass  # Ignorar se não conseguir coletar
    
    return {
        "status": "ok",
        "memory_mb": memory_mb,
    }


@router.get("/db")
async def health_db(db: AsyncSession = Depends(get_db)):
    """Health check com verificação de conexão ao PostgreSQL e métricas."""
    start_time = time.time()
    db_latency_ms = None
    db_status = "unknown"
    pool_size = None
    pool_checked_out = None
    
    try:
        # Testar conexão e medir latência
        await db.execute(text("SELECT 1"))
        db_latency_ms = round((time.time() - start_time) * 1000, 2)
        db_status = "connected"
        
        pool = async_engine.pool
        current_pool_size = pool.size()
        pool_checked_out = pool.checkedout()
        current_overflow = pool.overflow()

        db_connections_active.set(pool_checked_out)
        db_pool_size.set(current_pool_size)
        db_pool_overflow.set(current_overflow)

        pool_utilization = pool_checked_out / max(current_pool_size, 1)
        if pool_utilization > 0.8:
            logger.warning(
                "Pool de conexões com alta utilização: %.0f%%",
                pool_utilization * 100,
                extra={
                    "pool_size": current_pool_size,
                    "pool_checked_out": pool_checked_out,
                    "pool_overflow": current_overflow,
                },
            )

        return {
            "status": "ok",
            "database": "connected",
            "db_latency_ms": db_latency_ms,
            "pool_size": current_pool_size,
            "pool_checked_out": pool_checked_out,
            "pool_overflow": current_overflow,
            "pool_utilization_pct": round(pool_utilization * 100, 1),
        }
    except Exception as e:
        db_latency_ms = round((time.time() - start_time) * 1000, 2)
        db_status = "disconnected"
        
        # Em produção, não expor detalhes do erro de conexão
        if _IS_PRODUCTION:
            return {
                "status": "error",
                "database": "disconnected",
                "db_latency_ms": db_latency_ms,
            }
        else:
            # Em desenvolvimento, mostrar detalhes para debug
            return {
                "status": "error",
                "database": str(e),
                "db_latency_ms": db_latency_ms,
            }
