/// Implementação para web: **primeiro** `?api_base=` e sessionStorage (correcção sem rebuild),
/// depois `index.html`, **`--dart-define=API_BASE_URL`** (build Docker/Coolify), e por fim
/// localhost:8001 (dev local) ou mesma origem sem porta (produção).
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

/// Viewer em origem pública não pode usar API em loopback (Chrome PNA / CORS).
bool _storedApiBaseIncompatibleWithHost(String stored, String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '127.0.0.1') return false;
  final s = stored.toLowerCase();
  return s.contains('127.0.0.1') || s.contains('localhost');
}

String getApiBaseUrl() {
  final hostEarly = Uri.base.host;

  // 1) Query na URL — permite corrigir API em produção sem novo build (documentação Coolify).
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

  // 2) Sessão (gravada por ?api_base= anterior ou fluxo em index.html).
  try {
    final stored = html.window.sessionStorage['jjb_api_base_url'];
    if (stored != null &&
        stored.isNotEmpty &&
        !_storedApiBaseIncompatibleWithHost(stored, hostEarly)) {
      return _trimTrailingSlashes(stored);
    }
  } catch (_) {}

  // 3) Injeção síncrona do index.html antes do Flutter arrancar.
  try {
    final v = (html.window as dynamic)['__API_BASE_URL__'];
    if (v != null &&
        v is String &&
        v.isNotEmpty &&
        !_storedApiBaseIncompatibleWithHost(v, hostEarly)) {
      return _trimTrailingSlashes(v);
    }
  } catch (_) {}

  // 4) Build release (`--dart-define=API_BASE_URL`).
  // Ignora URL de loopback em domínio público (Coolify sem API_BASE_URL configurado bakes localhost:8001).
  final fromBuild = _kApiBaseFromBuild.trim();
  if (fromBuild.isNotEmpty &&
      !_storedApiBaseIncompatibleWithHost(fromBuild, hostEarly)) {
    return _trimTrailingSlashes(fromBuild);
  }

  // Porta no host: docker-compose mapeia API em 8001:8000.
  const localApiPort = 8001;

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return '${Uri.base.scheme}://$host:$localApiPort';
  }
  if (host.endsWith('.trycloudflare.com')) {
    return '';
  }
  // Viewer Docker expõe a UI frequentemente em :8080 no host; API no mesmo IP costuma estar em :8001.
  if (Uri.base.hasPort && Uri.base.port == 8080) {
    return '${Uri.base.scheme}://$host:$localApiPort';
  }
  // Em produção preferimos mesma origem (sem :8001) para evitar connection refused
  // quando a API está atrás de proxy (ex.: Caddy/Nginx/Cloudflare).
  return '${Uri.base.scheme}://$host';
}
