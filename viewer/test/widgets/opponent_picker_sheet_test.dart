import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/opponent_picker_sheet.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// OpponentPickerSheet: StatefulWidget com API call em initState.
// GET /users → lista de alunos. Vazio → "Nenhum colega", Erro → "Tentar novamente".
// Montado direto como home (sem showModalBottomSheet) para facilitar o teste.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Widget _screen({bool allowSkip = false}) => MaterialApp(
      home: Scaffold(
        body: OpponentPickerSheet(
          academyId: 'ac1',
          currentUserId: 'u-self',
          allowSkip: allowSkip,
        ),
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
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('OpponentPickerSheet — lista vazia', () {
    testWidgets('exibe mensagem de lista vazia', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum colega'), findsWidgets);
    });

    testWidgets('exibe campo de busca', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('exibe filtros de faixa', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('Todas'), findsWidgets);
    });
  });

  group('OpponentPickerSheet — erro de rede', () {
    testWidgets('exibe botão tentar novamente em erro 500', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({'detail': 'Erro'}, 500));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Tentar novamente'), findsWidgets);
    });
  });

  group('OpponentPickerSheet — title customizado', () {
    testWidgets('exibe o título informado', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OpponentPickerSheet(
            academyId: 'ac1',
            currentUserId: 'u-self',
            title: 'Selecionar adversário',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Selecionar adversário'), findsWidgets);
    });
  });
}
