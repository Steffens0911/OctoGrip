import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/face_checkin.dart';
import 'package:viewer/screens/academy/face_kiosk_screen.dart';

import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _fakeFrame = [0xFF, 0xD8, 0xFF, 0xE0]; // mini JPEG header

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

Widget _screen({
  required Future<Uint8List?> Function() captureFrame,
  required Future<FaceArriveResponse> Function(Uint8List) onFaceArrive,
}) =>
    wrapApp(
      FaceKioskScreen(
        sessionId: 'session-1',
        captureFrame: captureFrame,
        onFaceArrive: onFaceArrive,
      ),
    );

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
    testWidgets('exibe ícone e instrução de aguardar', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => null,
        onFaceArrive: (_) async => _noMatch(),
      ));
      expect(find.byIcon(Icons.face_outlined), findsOneWidget);
      expect(find.textContaining('câmera'), findsOneWidget);
    });

    testWidgets('exibe botão "Identificar"', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => null,
        onFaceArrive: (_) async => _noMatch(),
      ));
      expect(find.text('Identificar'), findsOneWidget);
    });

    testWidgets('exibe título do AppBar', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => null,
        onFaceArrive: (_) async => _noMatch(),
      ));
      expect(find.text('Quiosque de Entrada'), findsOneWidget);
    });
  });

  group('FaceKioskScreen — captura sem reconhecimento', () {
    testWidgets('exibe "Identificando…" durante processamento', (tester) async {
      final completer = <Completer<FaceArriveResponse>>[];
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) {
          final c = Completer<FaceArriveResponse>();
          completer.add(c);
          return c.future;
        },
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pump();

      expect(find.text('Identificando…'), findsOneWidget);

      completer.first.complete(_noMatch());
      await tester.pumpAndSettle();
    });

    testWidgets('exibe greeting de não reconhecido', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _noMatch(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('QR'), findsOneWidget);
    });
  });

  group('FaceKioskScreen — aluno pontual', () {
    testWidgets('exibe greeting de boas-vindas pontual', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchPontual(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bem-vindo'), findsOneWidget);
      expect(find.textContaining('Chegou na hora'), findsOneWidget);
    });

    testWidgets('exibe XP concedido', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchPontual(xp: 15),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('+15 XP'), findsOneWidget);
    });

    testWidgets('exibe streak quando > 1', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchPontual(streak: 5, xp: 15),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 treinos pontuais'), findsOneWidget);
    });

    testWidgets('não exibe streak quando streak = 1', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchPontual(streak: 1),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('treinos pontuais'), findsNothing);
    });
  });

  group('FaceKioskScreen — aluno atrasado', () {
    testWidgets('exibe greeting de atraso', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchAtrasado(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atrasado'), findsOneWidget);
    });

    testWidgets('não exibe XP quando atrasado', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchAtrasado(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('XP'), findsNothing);
    });
  });

  group('FaceKioskScreen — presença duplicada', () {
    testWidgets('exibe mensagem de presença já registrada', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => _matchDuplicate(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('já foi registrada'), findsOneWidget);
    });
  });

  group('FaceKioskScreen — erro', () {
    testWidgets('captura nula volta para estado de espera', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => null,
        onFaceArrive: (_) async => _noMatch(),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      // Volta ao estado de espera (não chama onFaceArrive com null)
      expect(find.text('Identificar'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando onFaceArrive lança exceção', (tester) async {
      await tester.pumpWidget(_screen(
        captureFrame: () async => Uint8List.fromList(_fakeFrame),
        onFaceArrive: (_) async => throw Exception('Sem conexão'),
      ));

      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Erro ao processar'), findsOneWidget);
    });
  });
}
