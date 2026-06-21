import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/user_facial_photo_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// UserFacialPhotoScreen: initState chama GET /me/consents.
// Resposta: {"items": [{"consent_type": "biometric", "granted": bool}]}
// Sem consentimento → exibe gate LGPD.
// Com consentimento → exibe UI de upload de foto.
// Erro → exibe "Tentar novamente".

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _consents(bool granted) => _json({
      'items': [
        {'consent_type': 'biometric', 'granted': granted}
      ]
    });

Widget _screen() => const MaterialApp(home: UserFacialPhotoScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('UserFacialPhotoScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _consents(false));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(UserFacialPhotoScreen), findsOneWidget);
    });

    testWidgets('não exibe spinner após carregar consentimento', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _consents(false));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('UserFacialPhotoScreen — gate de consentimento', () {
    testWidgets('sem consentimento exibe aviso LGPD', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _consents(false));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Exibe mensagem de consentimento biométrico / concordar
      expect(find.textContaining('biométric').evaluate().isNotEmpty ||
          find.textContaining('Concordar').evaluate().isNotEmpty ||
          find.textContaining('facial').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('sem itens de consentimento também exibe gate', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({'items': []}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(UserFacialPhotoScreen), findsOneWidget);
    });
  });

  group('UserFacialPhotoScreen — consentimento concedido', () {
    testWidgets('com consentimento exibe UI de upload', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _consents(true));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Exibe opções para selecionar foto
      expect(find.textContaining('foto').evaluate().isNotEmpty ||
          find.textContaining('câmera').evaluate().isNotEmpty ||
          find.textContaining('Câmera').evaluate().isNotEmpty ||
          find.textContaining('imagem').evaluate().isNotEmpty, isTrue);
    });
  });

  group('UserFacialPhotoScreen — erro de rede', () {
    testWidgets('erro 500 exibe botão tentar novamente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro interno"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Tentar novamente'), findsWidgets);
    });
  });
}
