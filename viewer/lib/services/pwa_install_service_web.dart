/// Implementação web do serviço PWA — acessa o JS via dart:js.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class PwaInstallService {
  PwaInstallService._();
  static final PwaInstallService instance = PwaInstallService._();

  /// True se o app já está instalado como PWA (standalone ou appinstalled event).
  bool get isInstalled {
    try {
      return js.context.callMethod('isPwaInstalled') == true;
    } catch (_) {
      return false;
    }
  }

  /// True se o Chrome/Edge tem prompt de instalação disponível (Android).
  bool get canInstallNatively {
    try {
      return js.context['__pwaInstallPrompt'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Aciona o prompt nativo do browser. Retorna true se foi exibido.
  bool triggerInstall() {
    try {
      return js.context.callMethod('triggerPwaInstall') == true;
    } catch (_) {
      return false;
    }
  }
}
