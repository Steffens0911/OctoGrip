// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ---------------------------------------------------------------------------
// Interface — usa Object nos parâmetros para permitir mock nos testes da VM
// ---------------------------------------------------------------------------

abstract class FaceDetector {
  Future<void> initialize();

  /// [videoElement] é um [web.HTMLVideoElement] em produção.
  Future<bool> hasFace(Object videoElement);

  /// [videoElement] é um [web.HTMLVideoElement] em produção.
  Future<Uint8List?> captureJpeg(Object videoElement);

  bool get isReady;
}

// ---------------------------------------------------------------------------
// Bridges para window.__faceDetect e window.__camera (definidos em index.html)
// ---------------------------------------------------------------------------

extension type _FaceDetectBridge._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> initialize();
  external JSPromise<JSBoolean> hasFace(JSObject video);
  external JSString? captureJpeg(JSObject video);
}

extension type _CameraBridge._(JSObject _) implements JSObject {
  external JSPromise<web.MediaStream> startCamera(
      web.HTMLVideoElement video, JSString facingMode);
  external void stopStream(web.MediaStream? stream);
}

// ---------------------------------------------------------------------------
// Implementação web
// ---------------------------------------------------------------------------

class WebFaceDetector implements FaceDetector {
  bool _ready = false;

  @override
  bool get isReady => _ready;

  _FaceDetectBridge get _bridge =>
      web.window.getProperty<_FaceDetectBridge>('__faceDetect'.toJS);

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await _bridge.initialize().toDart;
    _ready = true;
  }

  @override
  Future<bool> hasFace(Object videoElement) async {
    if (!_ready) return false;
    final video = videoElement as web.HTMLVideoElement;
    final result = await _bridge.hasFace(video).toDart;
    return result.toDart;
  }

  @override
  Future<Uint8List?> captureJpeg(Object videoElement) async {
    final video = videoElement as web.HTMLVideoElement;
    final dataUrl = _bridge.captureJpeg(video)?.toDart;
    if (dataUrl == null || !dataUrl.contains(',')) return null;
    return base64Decode(dataUrl.split(',').last);
  }
}

// ---------------------------------------------------------------------------
// Controlador de câmera
// ---------------------------------------------------------------------------

class CameraController {
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;

  /// VideoElement exposto como Object para não vazar tipos web na assinatura pública.
  Object? get videoElement => _video;

  _CameraBridge get _bridge =>
      web.window.getProperty<_CameraBridge>('__camera'.toJS);

  Future<void> start({String facingMode = 'user'}) async {
    final video = web.HTMLVideoElement();
    final stream = await _bridge.startCamera(video, facingMode.toJS).toDart;
    _video = video;
    _stream = stream;
  }

  /// Retoma o vídeo após o elemento ter sido removido e re-inserido no DOM.
  Future<void> resume() async {
    try {
      if (_video != null) await _video!.play().toDart;
    } catch (_) {}
  }

  void stop() {
    _bridge.stopStream(_stream);
    _stream = null;
    _video = null;
  }
}

// ---------------------------------------------------------------------------
// Mock para testes — não usa tipos web
// ---------------------------------------------------------------------------

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
