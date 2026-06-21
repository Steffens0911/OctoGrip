import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/services/pwa_install_service_stub.dart';

// Testes para PwaInstallService stub (plataformas não-web).

void main() {
  group('PwaInstallService stub', () {
    test('singleton retorna a mesma instância', () {
      expect(PwaInstallService.instance, same(PwaInstallService.instance));
    });

    test('isInstalled retorna false', () {
      expect(PwaInstallService.instance.isInstalled, isFalse);
    });

    test('canInstallNatively retorna false', () {
      expect(PwaInstallService.instance.canInstallNatively, isFalse);
    });

    test('triggerInstall retorna false', () {
      expect(PwaInstallService.instance.triggerInstall(), isFalse);
    });
  });
}
