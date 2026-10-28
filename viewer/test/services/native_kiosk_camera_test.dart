import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/services/native_kiosk_camera.dart';

CameraDescription _cam(String name, CameraLensDirection dir) => CameraDescription(
      name: name,
      lensDirection: dir,
      sensorOrientation: 90,
    );

void main() {
  group('pickKioskCamera', () {
    test('prefere a câmera frontal', () {
      final picked = pickKioskCamera([
        _cam('0', CameraLensDirection.back),
        _cam('1', CameraLensDirection.front),
      ]);
      expect(picked?.name, '1');
    });

    test('sem frontal usa a primeira', () {
      final picked = pickKioskCamera([
        _cam('0', CameraLensDirection.back),
        _cam('2', CameraLensDirection.external),
      ]);
      expect(picked?.name, '0');
    });

    test('sem câmeras retorna null', () {
      expect(pickKioskCamera([]), isNull);
    });
  });

  group('kioskCropRect', () {
    const image = Size(480, 640);

    test('adiciona 40% de margem em volta do rosto', () {
      final crop = kioskCropRect(const Rect.fromLTWH(140, 200, 200, 200), image);
      expect(crop, const Rect.fromLTRB(60, 120, 420, 480));
    });

    test('limita o recorte às bordas da imagem', () {
      final crop = kioskCropRect(const Rect.fromLTWH(0, 0, 200, 200), image);
      expect(crop, const Rect.fromLTRB(0, 0, 280, 280));
    });

    test('rosto fora da imagem (rotação divergente) retorna null', () {
      // Caixa calculada sobre a imagem deitada (640x480) aplicada à imagem em pé.
      final crop = kioskCropRect(const Rect.fromLTWH(560, 100, 150, 150), image);
      expect(crop, isNull);
    });
  });
}
