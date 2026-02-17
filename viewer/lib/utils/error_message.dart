import 'package:viewer/services/api_service.dart';

/// Retorna uma mensagem de erro amigável para exibir ao usuário.
/// Evita expor detalhes técnicos (ClientException, URI, etc.) em erros de rede.
String userFacingMessage(Object e) {
  if (e is ApiException) return e.message;
  final s = e.toString().toLowerCase();
  if (s.contains('timeoutexception') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('failed to fetch') ||
      s.contains('connection') ||
      s.contains('connection refused') ||
      s.contains('network')) {
    return 'Falha de conexão. Verifique a rede e tente novamente.';
  }
  final raw = e.toString().trim();
  if (raw.isEmpty) return 'Algo deu errado. Tente novamente.';
  // Remove prefixo tipo "ClientException: " ou "AcademyServiceException: "
  final withoutPrefix = raw.replaceFirst(RegExp(r'^[A-Za-z0-9_]+Exception:?\s*'), '').trim();
  return withoutPrefix.isEmpty ? 'Algo deu errado. Tente novamente.' : withoutPrefix;
}
