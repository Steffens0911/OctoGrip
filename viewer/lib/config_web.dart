/// Implementação para web: `?api_base=` (ngrok / dois túneis), depois `index.html`,
/// depois mesmo host + porta 8000.
library;

import 'dart:html' as html;

String _trimTrailingSlashes(String s) =>
    s.replaceAll(RegExp(r'/+$'), '');

String getApiBaseUrl() {
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
    if (stored != null && stored.isNotEmpty) {
      return _trimTrailingSlashes(stored);
    }
  } catch (_) {}

  return '${Uri.base.scheme}://${Uri.base.host}:8000';
}
