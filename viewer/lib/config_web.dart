/// Implementação para web: lê a URL da API definida no index.html (mesmo host, porta 8000).
library;

import 'dart:html' as html;

String getApiBaseUrl() {
  try {
    final v = (html.window as dynamic)['__API_BASE_URL__'];
    if (v != null && v is String && v.isNotEmpty) return v;
  } catch (_) {}
  // Fallback: mesmo host da página
  return '${Uri.base.scheme}://${Uri.base.host}:8000';
}
