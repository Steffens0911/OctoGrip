import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:viewer/widgets/consent_gate.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

List<Map<String, dynamic>> _allUpToDate() => [
      {'consent_type': 'terms', 'up_to_date': true, 'granted': true},
      {'consent_type': 'privacy', 'up_to_date': true, 'granted': true},
      {'consent_type': 'biometric', 'up_to_date': true, 'granted': true},
    ];

List<Map<String, dynamic>> _termsOutdated() => [
      {'consent_type': 'terms', 'up_to_date': false, 'granted': false},
      {'consent_type': 'privacy', 'up_to_date': false, 'granted': false},
      {'consent_type': 'biometric', 'up_to_date': true, 'granted': true},
    ];

List<Map<String, dynamic>> _biometricPending() => [
      {'consent_type': 'terms', 'up_to_date': true, 'granted': true},
      {'consent_type': 'privacy', 'up_to_date': true, 'granted': true},
      {'consent_type': 'biometric', 'up_to_date': true, 'granted': false},
    ];

void main() {
  setUpAll(disableGoogleFontsFetch);

  late MockApiService api;

  setUp(() {
    api = MockApiService();
    when(() => api.legalDocumentViewUrl(any())).thenReturn('https://api/legal/x/view');
  });

  Widget gate({Widget child = const Text('app')}) =>
      MaterialApp(home: ConsentGate(testApiService: api, child: child));

  group('ConsentGate — carregamento', () {
    testWidgets('mostra spinner antes da resposta da API', (tester) async {
      final completer = Completer<List<Map<String, dynamic>>>();
      when(() => api.getMyConsents()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(gate());
      await tester.pump(); // 1 frame — future ainda não completou

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ConsentGate — consentimentos em dia', () {
    testWidgets('exibe o child quando todos os consentimentos estão atualizados',
        (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _allUpToDate());

      await tester.pumpWidget(gate(child: const Text('app ok')));
      await tester.pumpAndSettle();

      expect(find.text('app ok'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ConsentGate — fail-open (erro de rede)', () {
    testWidgets('exibe o child quando a API lança exceção', (tester) async {
      when(() => api.getMyConsents()).thenThrow(Exception('sem rede'));

      await tester.pumpWidget(gate(child: const Text('app failsafe')));
      await tester.pumpAndSettle();

      expect(find.text('app failsafe'), findsOneWidget);
    });
  });

  group('ConsentGate — Passo 1: termos pendentes', () {
    testWidgets('exibe view de aceite quando termos estão desatualizados', (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _termsOutdated());

      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.text('Aceitar e continuar'), findsOneWidget);
    });

    testWidgets('botão de aceite começa desabilitado (checkbox desmarcado)', (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _termsOutdated());

      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aceitar e continuar'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('habilita botão após marcar checkbox', (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _termsOutdated());

      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aceitar e continuar'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('links para documentos legais estão presentes', (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _termsOutdated());

      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      expect(find.text('Ler os Termos de Uso'), findsOneWidget);
      expect(find.text('Ler a Política de Privacidade'), findsOneWidget);
    });
  });

  group('ConsentGate — Passo 2: biometria pendente', () {
    testWidgets('exibe view de biometria quando termos ok mas biometria não concedida',
        (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _biometricPending());

      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      expect(find.text('Reconhecimento facial'), findsOneWidget);
      expect(find.text('Opcional — você pode pular'), findsOneWidget);
      expect(find.text('Agora não, usar QR Code'), findsOneWidget);
    });

    testWidgets('pular biometria exibe o child sem chamar a API', (tester) async {
      when(() => api.getMyConsents()).thenAnswer((_) async => _biometricPending());

      await tester.pumpWidget(gate(child: const Text('app ok')));
      await tester.pumpAndSettle();

      // O botão pode estar fora da área visível da tela de teste (800×600).
      await tester.ensureVisible(find.text('Agora não, usar QR Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agora não, usar QR Code'));
      await tester.pump();

      expect(find.text('app ok'), findsOneWidget);
      verifyNever(() => api.recordConsent(consentType: any(named: 'consentType')));
    });
  });
}
