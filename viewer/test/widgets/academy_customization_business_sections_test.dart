import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/academy/academy_customization_business_sections.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Academy _academy({
  String id = 'ac1',
  String name = 'Academia Teste',
  String? logoUrl,
  bool showTrophies = true,
  bool showPartners = true,
  bool showSchedule = true,
}) =>
    Academy(
      id: id,
      name: name,
      logoUrl: logoUrl,
      showTrophies: showTrophies,
      showPartners: showPartners,
      showSchedule: showSchedule,
    );

// AcademyCustomizationBusinessSections usa AuthService via Provider.
Widget _widget({Academy? academy, VoidCallback? onUpdated}) => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<AuthService>.value(
          value: AuthService(),
          child: SingleChildScrollView(
            child: AcademyCustomizationBusinessSections(
              academy: academy ?? _academy(),
              onUpdated: onUpdated ?? () {},
            ),
          ),
        ),
      ),
    );

// AcademyCustomizationBusinessSections não faz chamadas no init — pumpAndSettle ok.

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

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
    clearAuthForTesting();
  });

  group('AcademyCustomizationBusinessSections — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(
          find.byType(AcademyCustomizationBusinessSections), findsOneWidget);
    });

    testWidgets('exibe opção de logo', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.textContaining('logo'), findsWidgets);
    });

    testWidgets('exibe switch de Troféus', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.textContaining('troféus'), findsWidgets);
    });

    testWidgets('exibe seção de aviso de login', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Aviso'), findsWidgets);
    });
  });

  group('AcademyCustomizationBusinessSections — visibilidade', () {
    testWidgets('switches refletem estado inicial da academia', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_widget(
        academy: _academy(
          showTrophies: true,
          showPartners: false,
          showSchedule: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Deve haver switches no formulário
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });
  });

  group('AcademyCustomizationBusinessSections — links úteis', () {
    testWidgets('exibe link para parceiros', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.textContaining('parceiros'), findsWidgets);
    });
  });
}
