/// Implementação para plataformas não-web (Android, iOS, desktop).
/// Emulador Android: 10.0.2.2 aponta para o localhost da máquina host.
/// Dispositivo físico: defina [kApiHostOverride] com o IP do seu PC (ex.: '192.168.0.14').
library;

import 'dart:io' show Platform;

const String? kApiHostOverride = null;
const String _kApiBaseFromBuild = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);
const String _kProdApiBaseDefault = 'https://octogrip.com.br';

String getApiBaseUrl() {
  final fromBuild = _kApiBaseFromBuild.trim();
  if (fromBuild.isNotEmpty) {
    return fromBuild.replaceAll(RegExp(r'/+$'), '');
  }

  const isRelease = bool.fromEnvironment('dart.vm.product');
  if (isRelease) {
    return _kProdApiBaseDefault;
  }

  if (kApiHostOverride != null && kApiHostOverride!.isNotEmpty) {
    return 'http://$kApiHostOverride:8000';
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
