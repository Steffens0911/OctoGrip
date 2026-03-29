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
