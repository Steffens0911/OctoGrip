import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/attendance_qr.dart';
import 'package:viewer/models/face_checkin.dart';
import 'package:viewer/screens/academy/face_kiosk_screen.dart';

import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _fakeFrame = [0xFF, 0xD8, 0xFF, 0xE0]; // mini JPEG header

QrTokenModel _fakeQr() => QrTokenModel(
      token: 'token-abc',
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      shortCode: 'ABC123',
    );

FaceArriveResponse _noMatch() => const FaceArriveResponse(
      matched: false,
      confidence: 0.45,
      greeting: 'Não te reconheci. Use o QR Code.',
    );

FaceArriveResponse _matchPontual({int streak = 1, int xp = 15}) =>
    FaceArriveResponse(
      matched: true,
      confidence: 0.85,
      studentId: 'student-1',
      studentName: 'João Silva',
      wasPunctual: true,
      punctualityStreak: streak,
      xpAwarded: xp,
      greeting: 'Bem-vindo, João Silva! ✅ Chegou na hora!',
    );

FaceArriveResponse _matchAtrasado() => const FaceArriveResponse(
      matched: true,
      confidence: 0.82,
      studentId: 'student-2',
      studentName: 'Maria Santos',
      wasPunctual: false,
      punctualityStreak: 0,
      xpAwarded: 0,
      greeting: 'Bem-vindo, Maria Santos! ⏰ Atrasado hoje — bora focar!',
    );

FaceArriveResponse _matchDuplicate() => const FaceArriveResponse(
      matched: true,
      confidence: 0.88,
      studentId: 'student-1',
      studentName: 'João Silva',
      wasPunctual: true,
      punctualityStreak: 3,
      xpAwarded: 0,
      greeting: 'Olá, João Silva! Sua presença já foi registrada.',
      duplicate: true,
    );

/// Monta o widget com câmera e QR mockados.
///
/// [detectFaceResult] controla o que detectFace() retorna (padrão: false).
/// [onFaceArrive] é obrigatório para testes de resultado.
Widget _screen({
  bool detectFaceResult = false,
  required Future<FaceArriveResponse> Function(Uint8List) onFaceArrive,
  Future<Uint8List?> Function()? captureJpegOverride,
}) =>
    wrapApp(
      FaceKioskScreen(
        sessionId: 'session-1',
        setupCamera: (_) async {}, // no-op — sem câmera real nos testes
        detectFace: () async => detectFaceResult,
        captureJpeg: captureJpegOverride ?? () async => Uint8List.fromList(_fakeFrame),
        buildCameraView: (_) => const ColoredBox(color: Colors.grey), // placeholder
        fetchQr: () async => _fakeQr(),
        onFaceArrive: onFaceArrive,
      ),
    );

/// Avança até a tela estar em estado [ready] (setupCamera completo).
Future<void> _pumpToReady(WidgetTester tester) async {
  await tester.pump(); // build inicial (loading)
  await tester.pump(); // setupCamera completa (estado ready)
}

/// Dispara um ciclo de detecção: avança 800ms + processa resultado.
Future<void> _triggerDetection(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800)); // timer de detecção
  await tester.pump(); // captureJpeg + onFaceArrive
  await tester.pump(); // setState resultado
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('FaceKioskScreen — estado inicial', () {
    testWidgets('exibe loading enquanto câmera inicializa', (tester) async {
      var setupCompleter = Completer<void>();
      await tester.pumpWidget(wrapApp(FaceKioskScreen(
        sessionId: 'session-1',
        setupCamera: (_) => setupCompleter.future,
        detectFace: () async => false,
        captureJpeg: () async => null,
        buildCameraView: (_) => const SizedBox(),
        fetchQr: () async => _fakeQr(),
        onFaceArrive: (_) async => _noMatch(),
      )));
      await tester.pump();
      expect(find.text('Iniciando câmera…'), findsOneWidget);
      setupCompleter.complete();
    });

    testWidgets('exibe instrução de posicionamento após câmera pronta', (tester) async {
      await tester.pumpWidget(_screen(
        onFaceArrive: (_) async => _noMatch(),
      ));
      await _pumpToReady(tester);
      expect(find.textContaining('câmera'), findsOneWidget);
    });

    testWidgets('exibe título do AppBar', (tester) async {
      await tester.pumpWidget(_screen(onFaceArrive: (_) async => _noMatch()));
      await _pumpToReady(tester);
      expect(find.text('Quiosque de Entrada'), findsOneWidget);
    });

    testWidgets('exibe QR Code após câmera pronta', (tester) async {
      await tester.pumpWidget(_screen(onFaceArrive: (_) async => _noMatch()));
      await _pumpToReady(tester);
      await tester.pump(); // fetchQr completa
      expect(find.textContaining('Ou escaneie'), findsOneWidget);
    });
  });

  group('FaceKioskScreen — detecção automática', () {
    testWidgets('exibe "Rosto detectado" quando detectFace retorna true', (tester) async {
      // captureJpeg bloqueado com Completer para manter o estado "detected" visível.
      final captureCompleter = Completer<Uint8List?>();
      await tester.pumpWidget(wrapApp(FaceKioskScreen(
        sessionId: 'session-1',
        setupCamera: (_) async {},
        detectFace: () async => true,
        captureJpeg: () => captureCompleter.future,
        buildCameraView: (_) => const SizedBox(),
        fetchQr: () async => _fakeQr(),
        onFaceArrive: (_) async => _noMatch(),
      )));
      await _pumpToReady(tester);
      await tester.pump(const Duration(milliseconds: 800)); // timer dispara
      await tester.pump(); // detectFace completa → setState(detected) → captureJpeg inicia (bloqueado)
      expect(find.textContaining('Rosto detectado'), findsOneWidget);
      captureCompleter.complete(null); // libera para não vazar o timer
    });

    testWidgets('exibe "Identificando…" durante envio ao servidor', (tester) async {
      final completer = Completer<FaceArriveResponse>();
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) => completer.future,
      ));
      await _pumpToReady(tester);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(); // captura
      await tester.pump(); // sending state
      expect(find.textContaining('Identificando'), findsOneWidget);
      completer.complete(_noMatch());
    });

    testWidgets('não captura quando detectFace retorna false', (tester) async {
      var captureCount = 0;
      await tester.pumpWidget(wrapApp(FaceKioskScreen(
        sessionId: 'session-1',
        setupCamera: (_) async {},
        detectFace: () async => false,
        captureJpeg: () async {
          captureCount++;
          return Uint8List.fromList(_fakeFrame);
        },
        buildCameraView: (_) => const SizedBox(),
        fetchQr: () async => _fakeQr(),
        onFaceArrive: (_) async => _noMatch(),
      )));
      await _pumpToReady(tester);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(captureCount, 0);
    });
  });

  group('FaceKioskScreen — resultado: aluno pontual', () {
    testWidgets('exibe greeting de boas-vindas', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchPontual(),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('Bem-vindo'), findsOneWidget);
      expect(find.textContaining('Chegou na hora'), findsOneWidget);
    });

    testWidgets('exibe XP concedido', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchPontual(xp: 15),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('+15 XP'), findsOneWidget);
    });

    testWidgets('exibe streak quando > 1', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchPontual(streak: 5, xp: 15),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('5 treinos pontuais'), findsOneWidget);
    });

    testWidgets('não exibe streak quando streak = 1', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchPontual(streak: 1),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('treinos pontuais'), findsNothing);
    });
  });

  group('FaceKioskScreen — resultado: aluno atrasado', () {
    testWidgets('exibe greeting de atraso', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchAtrasado(),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('Atrasado'), findsOneWidget);
    });

    testWidgets('não exibe XP quando atrasado (xp = 0)', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchAtrasado(),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('XP'), findsNothing);
    });
  });

  group('FaceKioskScreen — resultado: presença duplicada', () {
    testWidgets('exibe mensagem de presença já registrada', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _matchDuplicate(),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('já foi registrada'), findsOneWidget);
    });
  });

  group('FaceKioskScreen — resultado: não reconhecido', () {
    testWidgets('exibe greeting de não reconhecido', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => _noMatch(),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('QR'), findsWidgets); // "Use o QR Code"
    });
  });

  group('FaceKioskScreen — erro', () {
    testWidgets('captura nula volta para estado de espera', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        captureJpegOverride: () async => null, // captura falha
        onFaceArrive: (_) async => _noMatch(),
      ));
      await _pumpToReady(tester);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      // Voltou ao estado ready — instrução de câmera volta
      expect(find.textContaining('câmera'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando onFaceArrive lança exceção', (tester) async {
      await tester.pumpWidget(_screen(
        detectFaceResult: true,
        onFaceArrive: (_) async => throw Exception('Sem conexão'),
      ));
      await _pumpToReady(tester);
      await _triggerDetection(tester);
      expect(find.textContaining('Erro ao processar'), findsOneWidget);
    });

    testWidgets('exibe erro de câmera quando setupCamera lança exceção', (tester) async {
      await tester.pumpWidget(wrapApp(FaceKioskScreen(
        sessionId: 'session-1',
        setupCamera: (_) async => throw Exception('NotAllowed'),
        detectFace: () async => false,
        captureJpeg: () async => null,
        buildCameraView: (_) => const SizedBox(),
        fetchQr: () async => _fakeQr(),
        onFaceArrive: (_) async => _noMatch(),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Permissão de câmera'), findsOneWidget);
    });
  });
}
