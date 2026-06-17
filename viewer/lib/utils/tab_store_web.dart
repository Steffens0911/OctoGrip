import 'dart:html' as html;

void saveTab(String name) {
  try {
    html.window.sessionStorage['og_tab'] = name;
  } catch (_) {}
}

String? loadTab() {
  try {
    return html.window.sessionStorage['og_tab'];
  } catch (_) {
    return null;
  }
}
