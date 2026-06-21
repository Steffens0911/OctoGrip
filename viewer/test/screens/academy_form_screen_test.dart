import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_form_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// AcademyFormScreen:
//  - Novo (academy: null): sem chamadas de API no init.
//  - Editar (academy != null): chama GET /techniques + GET /lessons em paralelo (catch silencia).
// Academy NOT const — sempre instanciar inline.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _techJson({String id = 't1', String name = 'Arm Lock'}) =>
    {'id': id, 'name': name, 'slug': 'arm-lock', 'description': null, 'video_url': null};

Map<String, dynamic> _lessonJson({String id = 'ls1', String title = 'Lição 1'}) => {
      'id': id,
      'title': title,
      'slug': 'licao-1',
      'order_index': 0,
      'technique_id': 't1',
      'academy_id': 'ac1',
      'video_url': null,
      'content': null,
      'technique_name': null,
      'position_name': null,
      'technique_video_url': null,
    };

http.Response _dispatch(Uri uri) {
  final path = uri.path;
  if (path.contains('/lessons')) return _json([]);
  if (path.contains('/techniques')) return _json([]);
  return _json({}, 404);
}

Widget _newScreen() => const MaterialApp(home: AcademyFormScreen());

Widget _editScreen() => MaterialApp(
      home: AcademyFormScreen(
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

  group('AcademyFormScreen — novo', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_newScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Nova academia"', (tester) async {
      await tester.pumpWidget(_newScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('academia'), findsWidgets);
    });

    testWidgets('exibe campo Nome', (tester) async {
      await tester.pumpWidget(_newScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nome'), findsWidgets);
    });

    testWidgets('exibe botão Salvar', (tester) async {
      await tester.pumpWidget(_newScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Salvar'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator no modo novo', (tester) async {
      await tester.pumpWidget(_newScreen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('AcademyFormScreen — editar', () {
    testWidgets('renderiza modo edição sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_editScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyFormScreen), findsOneWidget);
    });

    testWidgets('pré-preenche nome da academia existente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_editScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });

    testWidgets('erro ao carregar técnicas/lições não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_editScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyFormScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe dropdown de Tema da semana após carregar técnicas', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final path = (inv.positionalArguments[0] as Uri).path;
        if (path.contains('/techniques')) return _json([_techJson()]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_editScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Tema'), findsWidgets);
    });
  });
}
