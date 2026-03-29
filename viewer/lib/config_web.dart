/// Implementação para web: `?api_base=` (ngrok / Cloudflare), depois `index.html`,
/// depois mesmo host + porta 8000.
/// Em `*.trycloudflare.com` sem `api_base`, devolve string vazia: o browser bloqueia HTTPS→127.0.0.1 (PNA).
library;

import 'dart:html' as html;

String _trimTrailingSlashes(String s) =>
    s.replaceAll(RegExp(r'/+$'), '');

bool _isBlockedLoopbackOnPublicTunnel(String stored, String host) {
  if (!host.endsWith('.trycloudflare.com')) return false;
  final s = stored.toLowerCase();
  return s.contains('127.0.0.1') || s.contains('localhost:');
}

String getApiBaseUrl() {
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

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return '${Uri.base.scheme}://$host:8000';
  }
  if (host.endsWith('.trycloudflare.com')) {
    return '';
  }
  return '${Uri.base.scheme}://$host:8000';
}
