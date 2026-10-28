// Stub para a web — o quiosque no navegador usa face_detection_service_impl.dart.
// Evita levar dart:io e o ML Kit para o build web. Mesma API pública que
// native_kiosk_camera.dart.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class NativeKioskCamera {
  Future<void> start() =>
      throw UnsupportedError('Câmera nativa indisponível na web.');
  Future<bool> detectFace() async => false;
  Future<Uint8List?> takeFrame() async => null;
  Widget buildPreview() => const SizedBox.shrink();
  Future<void> stop() async {}
}
