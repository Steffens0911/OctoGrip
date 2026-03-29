import 'dart:async';

import 'package:viewer/services/api_service.dart';

/// Evita confundir 401/CORS com “API desligada”.
bool _looksLikeNetworkFailure(String s) {
  return s.contains('timeoutexception') ||
      s.contains('socketexception') ||
      (s.contains('clientexception') &&
          (s.contains('failed to fetch') ||
              s.contains('connection refused') ||
              s.contains('network is unreachable'))) ||
      s.contains('connection refused') ||
      s.contains('network is unreachable') ||
      (s.contains('failed to fetch') && s.contains('clientexception'));
}

/// Instrução quando o viewer está em *.trycloudflare.com sem `?api_base=` (Chrome bloqueia HTTPS → loopback).
const String kWebTrycloudflareMissingApiBaseMessage =
    'Este site está num túnel Cloudflare público: o Chrome não permite que a página chame a API em 127.0.0.1.\n\n'
    '1) Com a API na porta 8000, noutro terminal: cloudflared tunnel --url http://127.0.0.1:8000\n'
    '2) Copie a URL https://….trycloudflare.com desse túnel.\n'
    '3) Cole abaixo em “URL do túnel da API” e toque em Guardar (ou abra o viewer com ?api_base=URL na barra de endereço).\n\n'
    'O valor fica na sessão do navegador até fechar o separador.';

/// Retorna uma mensagem de erro amigável para exibir ao usuário.
/// Evita expor detalhes técnicos (ClientException, URI, etc.) em erros de rede.
String userFacingMessage(Object e) {
  if (e is TimeoutException) {
    final m = e.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return 'Tempo esgotado. Tente de novo ou verifique se a API ainda responde.';
  }
  if (e is ApiException) {
    if (e.statusCode == 401) {
      final base = e.message.trim().isEmpty ? 'Não autorizado.' : e.message.trim();
      return '$base\n\n'
          'Se acabou de restaurar um backup, use as credenciais desse banco. '
          'Ambiente Docker com seed típico: admin@jjb.com / saas';
    }
    return e.message;
  }
  final s = e.toString().toLowerCase();
  if (_looksLikeNetworkFailure(s)) {
    return 'Falha de conexão. Verifique se a API está em execução (porta 8000) e se o app está na mesma rede ou no emulador.';
  }
  final raw = e.toString().trim();
  if (raw.isEmpty) return 'Algo deu errado. Tente novamente.';
  // Remove prefixo tipo "ClientException: " ou "AcademyServiceException: "
  final withoutPrefix = raw.replaceFirst(RegExp(r'^[A-Za-z0-9_]+Exception:?\s*'), '').trim();
  return withoutPrefix.isEmpty ? 'Algo deu errado. Tente novamente.' : withoutPrefix;
}
