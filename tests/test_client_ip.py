"""IP real do cliente atrás do proxy (rate limit, bloqueio de login, consentimento LGPD).

Sem o X-Forwarded-For, todo usuário aparece com o IP do Traefik e divide o mesmo balde de
rate limit. Mas o cabeçalho só vale quando a conexão vem de um proxy da rede interna.
"""

from starlette.requests import Request

from app.core.client_ip import get_client_ip


def _request(peer: str | None, forwarded: str | None = None) -> Request:
    headers = [(b"x-forwarded-for", forwarded.encode())] if forwarded is not None else []
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": headers,
        "client": (peer, 51234) if peer else None,
    }
    return Request(scope)


def test_via_proxy_interno_usa_ip_do_forwarded_for():
    assert get_client_ip(_request("10.0.1.5", "203.0.113.7")) == "203.0.113.7"


def test_sem_forwarded_for_usa_ip_da_conexao():
    assert get_client_ip(_request("10.0.1.5")) == "10.0.1.5"


def test_conexao_direta_de_fora_ignora_forwarded_for():
    """Quem chega sem passar pelo proxy não escolhe o próprio IP pelo cabeçalho."""
    assert get_client_ip(_request("198.51.100.20", "203.0.113.7")) == "198.51.100.20"


def test_valor_forjado_a_esquerda_e_ignorado():
    """O cliente manda X-Forwarded-For falso; o Traefik acrescenta o IP real no fim."""
    assert get_client_ip(_request("10.0.1.5", "1.2.3.4, 203.0.113.7")) == "203.0.113.7"


def test_pula_proxies_internos_na_cadeia():
    assert get_client_ip(_request("172.18.0.2", "203.0.113.7, 10.0.0.9")) == "203.0.113.7"


def test_cadeia_toda_interna_usa_o_mais_a_esquerda():
    assert get_client_ip(_request("172.18.0.2", "192.168.1.30, 10.0.0.9")) == "192.168.1.30"


def test_valor_invalido_numa_posicao_confiavel_cai_para_a_conexao():
    assert get_client_ip(_request("10.0.1.5", "203.0.113.7, lixo")) == "10.0.1.5"


def test_ipv6_publico_via_proxy():
    assert get_client_ip(_request("10.0.1.5", "2001:db8::1")) == "2001:db8::1"


def test_sem_cliente_na_conexao():
    assert get_client_ip(_request(None)) == "unknown"
