// Stub para VM/testes — sem imports web. Mesma API pública que face_detection_service_impl.dart.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

abstract class FaceDetector {
  Future<void> initialize();
  Future<bool> hasFace(Object videoElement);
  Future<Uint8List?> captureJpeg(Object videoElement);
  bool get isReady;
}

class WebFaceDetector implements FaceDetector {
  @override
  bool get isReady => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasFace(Object v) async => false;
  @override
  Future<Uint8List?> captureJpeg(Object v) async => null;
}

class CameraController {
  Object? get videoElement => null;
  bool get hasActiveFrame => false;
  Future<void> start({String facingMode = 'user'}) async {}
  void registerViewFactory(String viewId) {}
  Future<void> resume() async {}
  void stop() {}
}

@visibleForTesting
class MockFaceDetector implements FaceDetector {
  bool _ready = false;
  bool nextHasFace = false;
  Uint8List? nextFrame;

  @override
  bool get isReady => _ready;
  @override
  Future<void> initialize() async => _ready = true;
  @override
  Future<bool> hasFace(Object videoElement) async => nextHasFace;
  @override
  Future<Uint8List?> captureJpeg(Object videoElement) async =>
      nextFrame ?? Uint8List(0);
}
