"""
Métricas Prometheus para monitoramento da aplicação.
"""
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# Métricas HTTP
http_requests_total = Counter(
    "http_requests_total",
    "Total de requisições HTTP",
    ["method", "path", "status_code"],
)

http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "Duração de requisições HTTP em segundos",
    ["method", "path"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

http_errors_total = Counter(
    "http_errors_total",
    "Total de erros HTTP",
    ["method", "path", "status_code", "error_type"],
)

# Métricas de banco de dados
db_query_duration_seconds = Histogram(
    "db_query_duration_seconds",
    "Duração de queries do banco de dados em segundos",
    ["operation"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)

# Métricas de negócio
active_users_total = Gauge(
    "active_users_total",
    "Número total de usuários ativos",
)

# Métricas de sistema
memory_usage_bytes = Gauge(
    "memory_usage_bytes",
    "Uso de memória em bytes",
)

db_connections_active = Gauge(
    "db_connections_active",
    "Número de conexões ativas do pool de banco de dados",
)

db_pool_size = Gauge(
    "db_pool_size",
    "Tamanho total do pool de conexões",
)

db_pool_overflow = Gauge(
    "db_pool_overflow",
    "Conexões em overflow do pool",
)

security_events_total = Counter(
    "security_events_total",
    "Total de eventos de segurança (login falhado, acesso negado, etc.)",
    ["event_type"],
)


def get_metrics_response():
    """Retorna resposta HTTP com métricas Prometheus."""
    return generate_latest(), CONTENT_TYPE_LATEST
