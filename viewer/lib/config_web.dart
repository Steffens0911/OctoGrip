/// Implementação para web: build Docker/Coolify via `--dart-define=API_BASE_URL=`,
/// depois `?api_base=`, `index.html` / sessionStorage, e por fim localhost:8001 ou mesmo host:8001.
/// Em `*.trycloudflare.com` sem `api_base`, devolve string vazia: o browser bloqueia HTTPS→127.0.0.1 (PNA).
library;

import 'dart:html' as html;

/// Injertado em `flutter build web --dart-define=API_BASE_URL=...` (ver `viewer/Dockerfile`).
const String _kApiBaseFromBuild = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String _trimTrailingSlashes(String s) =>
    s.replaceAll(RegExp(r'/+$'), '');

bool _isBlockedLoopbackOnPublicTunnel(String stored, String host) {
  if (!host.endsWith('.trycloudflare.com')) return false;
  final s = stored.toLowerCase();
  return s.contains('127.0.0.1') || s.contains('localhost:');
}

String getApiBaseUrl() {
  final fromBuild = _kApiBaseFromBuild.trim();
  if (fromBuild.isNotEmpty) {
    return _trimTrailingSlashes(fromBuild);
  }

  final hostEarly = Uri.base.host;
  try {
    final qp = Uri.base.queryParameters['api_base'];
    if (qp != null && qp.isNotEmpty) {
      final u = _trimTrailingSlashes(qp.trim());
      if (u.isNotEmpty) {
        try {
          (html.window as dynamic)['__API_BASE_URL__'] = u;
          html.window.sessionStorage['jjb_api_base_url'] = u;
        } catch (_) {}
        return u;
      }
    }
  } catch (_) {}

  try {
    final v = (html.window as dynamic)['__API_BASE_URL__'];
    if (v != null && v is String && v.isNotEmpty) {
      return _trimTrailingSlashes(v);
    }
  } catch (_) {}

  try {
    final stored = html.window.sessionStorage['jjb_api_base_url'];
    if (stored != null &&
        stored.isNotEmpty &&
        !_isBlockedLoopbackOnPublicTunnel(stored, hostEarly)) {
      return _trimTrailingSlashes(stored);
    }
  } catch (_) {}

  // Porta no host: docker-compose mapeia API em 8001:8000.
  const localApiPort = 8001;

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return '${Uri.base.scheme}://$host:$localApiPort';
  }
  if (host.endsWith('.trycloudflare.com')) {
    return '';
  }
  return '${Uri.base.scheme}://$host:$localApiPort';
}
