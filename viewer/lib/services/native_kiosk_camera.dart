// Câmera do quiosque facial no app nativo (Android): preview com o pacote
// camera e detecção local com ML Kit. Na web o quiosque usa
// face_detection_service_impl.dart (getUserMedia + face-api.js do index.html).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Margem ao redor do rosto e largura máxima do recorte — os mesmos valores do
/// window.__faceDetect (web/index.html), para o backend receber o mesmo tipo de frame.
const double kioskCropMargin = 0.4;
const int kioskCropMaxWidth = 320;

/// Sem um rosto confiável para recortar, manda o frame inteiro com esta largura.
const int kioskFullFrameMaxWidth = 640;

/// Prefere a câmera frontal; sem frontal, usa a primeira disponível.
CameraDescription? pickKioskCamera(List<CameraDescription> cameras) {
  if (cameras.isEmpty) return null;
  for (final c in cameras) {
    if (c.lensDirection == CameraLensDirection.front) return c;
  }
  return cameras.first;
}

/// Região do rosto com [margin] em volta, limitada à imagem.
///
/// Retorna null quando o rosto não cabe na imagem — sinal de que a caixa do
/// ML Kit e a imagem decodificada não concordam sobre a rotação.
@visibleForTesting
Rect? kioskCropRect(Rect face, Size image, {double margin = kioskCropMargin}) {
  final bounds = Offset.zero & image;
  // Tolerância de 10%: o ML Kit às vezes devolve a caixa um pouco fora da borda.
  if (!bounds.inflate(image.shortestSide * 0.1).contains(face.center)) return null;
  final mx = face.width * margin;
  final my = face.height * margin;
  final crop = Rect.fromLTRB(
    face.left - mx,
    face.top - my,
    face.right + mx,
    face.bottom + my,
  ).intersect(bounds);
  if (crop.width < 1 || crop.height < 1) return null;
  return crop;
}

/// Recorta [src] de [encoded] e reduz para no máximo [maxWidth] de largura, em PNG.
///
/// O decoder do Flutter já aplica a orientação EXIF da foto da câmera, então a
/// imagem enviada ao backend sai "em pé" (o worker não lê EXIF).
Future<Uint8List?> _cropAndEncode(
  Uint8List encoded,
  Rect? Function(Size image) region,
  int maxWidth,
) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final image = (await codec.getNextFrame()).image;
  try {
    final size = Size(image.width.toDouble(), image.height.toDouble());
    final src = region(size) ?? (Offset.zero & size);
    final scale = src.width > maxWidth ? maxWidth / src.width : 1.0;
    final dw = math.max(1, (src.width * scale).round());
    final dh = math.max(1, (src.height * scale).round());

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, dw.toDouble(), dh.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final out = await recorder.endRecording().toImage(dw, dh);
    try {
      final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      out.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}

class NativeKioskCamera with WidgetsBindingObserver {
  final ValueNotifier<CameraController?> _controller = ValueNotifier(null);
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  CameraDescription? _description;
  Future<void>? _opening;
  Uint8List? _lastFrame;
  bool _paused = false;
  bool _stopped = false;

  /// Abre a câmera frontal. Lança [CameraException] se não houver câmera ou a
  /// permissão for negada (códigos 'NoCamera' e 'CameraAccessDenied*').
  Future<void> start() async {
    final camera = pickKioskCamera(await availableCameras());
    if (camera == null) {
      throw CameraException('NoCamera', 'Nenhuma câmera encontrada.');
    }
    _description = camera;
    WidgetsBinding.instance.addObserver(this);
    await _openOnce();
  }

  Future<void> _openOnce() {
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    final controller = CameraController(
      _description!,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    // Saiu da tela (ou o app foi para segundo plano) enquanto abria.
    if (_stopped || _paused) {
      await controller.dispose();
      return;
    }
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {}
    _controller.value = controller;
  }

  /// Tira uma foto e procura rosto nela. Com rosto, guarda o recorte para
  /// [takeFrame] — o frame enviado é o mesmo em que o rosto foi detectado.
  Future<bool> detectFace() async {
    final controller = _controller.value;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return false;
    }
    XFile? shot;
    try {
      shot = await controller.takePicture();
      final faces = await _detector.processImage(InputImage.fromFilePath(shot.path));
      if (faces.isEmpty) return false;
      final face = faces
          .reduce((a, b) => _area(a.boundingBox) >= _area(b.boundingBox) ? a : b)
          .boundingBox;
      final bytes = await shot.readAsBytes();
      final crop = await _cropAndEncode(
        bytes,
        (size) => kioskCropRect(face, size),
        kioskCropMaxWidth,
      );
      // Caixa fora da imagem: manda o frame inteiro e deixa o backend achar o rosto.
      _lastFrame = crop ??
          await _cropAndEncode(bytes, (_) => null, kioskFullFrameMaxWidth);
      return _lastFrame != null;
    } catch (e) {
      debugPrint('NativeKioskCamera.detectFace: $e');
      return false;
    } finally {
      if (shot != null) unawaited(_deleteQuietly(shot.path));
    }
  }

  /// Frame recortado (PNG) da última detecção, consumido uma vez.
  Future<Uint8List?> takeFrame() async {
    final frame = _lastFrame;
    _lastFrame = null;
    return frame;
  }

  Widget buildPreview() {
    return ValueListenableBuilder<CameraController?>(
      valueListenable: _controller,
      builder: (context, controller, _) {
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38),
          );
        }
        return Center(child: CameraPreview(controller));
      },
    );
  }

  /// O Android libera a câmera quando o app vai para segundo plano: fecha ao
  /// pausar e reabre ao voltar (padrão recomendado pelo pacote camera).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stopped) return;
    if (state == AppLifecycleState.paused) {
      _paused = true;
      final controller = _controller.value;
      _controller.value = null;
      unawaited(controller?.dispose());
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (_controller.value == null) {
        unawaited(_openOnce().catchError((Object e) {
          debugPrint('NativeKioskCamera: falha ao reabrir a câmera: $e');
        }));
      }
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    WidgetsBinding.instance.removeObserver(this);
    _lastFrame = null;
    final controller = _controller.value;
    _controller.value = null;
    await controller?.dispose();
    await _detector.close();
  }

  static double _area(Rect r) => r.width * r.height;

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
