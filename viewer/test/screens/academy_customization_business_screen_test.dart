import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/academy/academy_customization_business_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// AcademyCustomizationBusinessScreen: sem chamadas de API no initState.
// O widget filho AcademyCustomizationBusinessSections lê apenas widget.academy.
// Academy(id, name) usa defaults (showTrophies=true, showPartners=true, etc.).

Widget _screen() => MaterialApp(
      home: AcademyCustomizationBusinessScreen(
        academy: Academy(id: 'ac1', name: 'Academia Teste'),
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AcademyCustomizationBusinessScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      when(() => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyCustomizationBusinessScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Personalização e Negócios"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      when(() => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Personalização'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator no init', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      when(() => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe nome da academia no subtítulo', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      when(() => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{}', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });
  });
}
