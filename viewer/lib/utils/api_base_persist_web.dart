import 'dart:html' as html;

/// Grava a base da API na sessão do browser e recarrega para o Flutter reler [kApiBaseUrl].
void persistApiBaseAndReload(String base) {
  final t = base.trim().replaceAll(RegExp(r'/+$'), '');
  if (t.isEmpty) return;
  if (!t.startsWith('http://') && !t.startsWith('https://')) return;
  try {
    html.window.sessionStorage['jjb_api_base_url'] = t;
    html.window.location.reload();
  } catch (_) {}
}

/// Redireciona para a raiz do app (remove query params da URL).
void redirectToRoot() {
  try {
    html.window.location.assign('/');
  } catch (_) {}
}
