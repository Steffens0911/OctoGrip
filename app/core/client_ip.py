"""IP real do cliente atrás do proxy reverso (Traefik/Coolify).

Atrás do proxy, ``request.client.host`` é o IP do próprio proxy: usar esse valor juntaria todos
os usuários num único balde de rate limit. O IP real vem do ``X-Forwarded-For``, mas o cabeçalho
só é confiável quando a conexão chega de um proxy da rede interna (``TRUSTED_PROXY_CIDRS``).

O cabeçalho é lido da direita para a esquerda: cada proxy acrescenta ao fim o IP de quem se
conectou a ele, então o primeiro IP fora das redes confiáveis é o cliente. A parte da esquerda
pode ter sido escrita pelo próprio cliente e nunca é usada para escolher o IP.
"""

import ipaddress
from functools import lru_cache

from starlette.requests import HTTPConnection

from app.config import settings

_IPAddress = ipaddress.IPv4Address | ipaddress.IPv6Address
_IPNetwork = ipaddress.IPv4Network | ipaddress.IPv6Network


@lru_cache(maxsize=8)
def _networks(cidrs: tuple[str, ...]) -> tuple[_IPNetwork, ...]:
    return tuple(ipaddress.ip_network(c.strip(), strict=False) for c in cidrs if c.strip())


def _parse_ip(value: str | None) -> _IPAddress | None:
    if not value:
        return None
    try:
        return ipaddress.ip_address(value.strip())
    except ValueError:
        return None


def _is_trusted(ip: _IPAddress, networks: tuple[_IPNetwork, ...]) -> bool:
    return any(ip in net for net in networks)


def get_client_ip(request: HTTPConnection) -> str:
    """IP de origem da requisição (HTTP ou WebSocket), considerando só proxies confiáveis.

    O parâmetro precisa se chamar ``request``: é assim que o slowapi decide passar a requisição
    para o key_func (com outro nome ele chama sem argumentos e quebra).
    """
    peer = request.client.host if request.client else None
    peer_ip = _parse_ip(peer)
    if peer_ip is None:
        return peer or "unknown"

    networks = _networks(tuple(settings.TRUSTED_PROXY_CIDRS))
    if not _is_trusted(peer_ip, networks):
        return str(peer_ip)

    forwarded = request.headers.get("x-forwarded-for")
    if not forwarded:
        return str(peer_ip)

    hops = [hop.strip() for hop in forwarded.split(",") if hop.strip()]
    first_hop: _IPAddress | None = None
    for hop in reversed(hops):
        ip = _parse_ip(hop)
        if ip is None:
            # Valor inválido onde só um proxy confiável escreveria: não arrisca adivinhar.
            return str(peer_ip)
        if not _is_trusted(ip, networks):
            return str(ip)
        first_hop = ip
    # Toda a cadeia é interna (ex.: chamada de outro container): o mais à esquerda é a origem.
    return str(first_hop or peer_ip)
