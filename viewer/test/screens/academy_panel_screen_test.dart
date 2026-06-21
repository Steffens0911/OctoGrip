import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/academy_panel_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// AcademyPanelScreen usa RoleGuard → precisa de ChangeNotifierProvider<AuthService>.
// Admin: GET /academies. Professor: GET /academies + /reviews + /enrollments.
// Vazio (admin): 'Nenhuma academia cadastrada'.
// Erro: 'Tentar novamente'.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _academyJson({String id = 'ac1', String name = 'Academia Teste'}) => {
      'id': id,
      'name': name,
      'weekly_multiplier_1': 1,
      'weekly_multiplier_2': 1,
      'weekly_multiplier_3': 1,
    };

Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: const MaterialApp(home: AcademyPanelScreen()),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AcademyPanelScreen — estrutura', () {
    testWidgets('renderiza sem crash (admin)', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyPanelScreen), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('AcademyPanelScreen — estado vazio', () {
    testWidgets('admin sem academias exibe mensagem adequada', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('academia'), findsWidgets);
    });
  });

  group('AcademyPanelScreen — com academia', () {
    testWidgets('exibe tiles de navegação ao carregar academia', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final path = (inv.positionalArguments[0] as Uri).path;
        if (path.contains('/academies') && !path.contains('/academies/')) {
          return _json([_academyJson()]);
        }
        return _json([], 404);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('treinamento'), findsWidgets);
    });
  });

  group('AcademyPanelScreen — erro de rede', () {
    testWidgets('erro 500 exibe botão tentar novamente', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
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
