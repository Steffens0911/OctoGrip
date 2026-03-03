/// Implementação para plataformas não-web (Android, iOS, desktop).
/// Emulador Android: 10.0.2.2 aponta para o localhost da máquina host.
/// Dispositivo físico: defina [kApiHostOverride] com o IP do seu PC (ex.: '192.168.0.14').
import 'dart:io' show Platform;

const String? kApiHostOverride = null;

String getApiBaseUrl() {
  if (kApiHostOverride != null && kApiHostOverride!.isNotEmpty) {
    return 'http://$kApiHostOverride:8000';
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
