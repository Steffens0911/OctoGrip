/// Versão do app no formato do pubspec: `MAIOR.MENOR.CORREÇÃO+BUILD` (ex.: `1.3.0+12`).
///
/// Mesma regra da API (`app/core/app_version.py`): o `+BUILD` é opcional e vale 0,
/// então a mínima `1.3.0` aceita qualquer build 1.3.0.
library;

final RegExp _versionRe = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

/// `"1.3.0+12"` → `[1, 3, 0, 12]`; formato inválido → `null`.
List<int>? parseAppVersion(String? raw) {
  if (raw == null) return null;
  final match = _versionRe.firstMatch(raw.trim());
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4) ?? '0'),
  ];
}

/// `true` só quando as duas versões são válidas e [version] < [minimum].
/// Versão desconhecida nunca bloqueia (igual à API).
bool isAppVersionBelow(String? version, String? minimum) {
  final current = parseAppVersion(version);
  final required = parseAppVersion(minimum);
  if (current == null || required == null) return false;
  for (var i = 0; i < 4; i++) {
    if (current[i] != required[i]) return current[i] < required[i];
  }
  return false;
}
