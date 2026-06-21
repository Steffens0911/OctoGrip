import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/training_session_summary_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _person(String userId, String name) => {
      'user_id': userId,
      'name': name,
      'avatar_url': null,
    };

Map<String, dynamic> _summary({
  int totalPreConfirmed = 0,
  int totalAttended = 0,
  List<Map<String, dynamic>> confirmedAndAttended = const [],
  List<Map<String, dynamic>> furos = const [],
  List<Map<String, dynamic>> surpresas = const [],
}) =>
    {
      'training_session_id': 's1',
      'label': 'Adulto GI',
      'class_date': '2026-06-20',
      'start_time': '19:00',
      'total_pre_confirmed': totalPreConfirmed,
      'total_attended': totalAttended,
      'confirmed_and_attended': confirmedAndAttended,
      'furos': furos,
      'surpresas': surpresas,
    };

MockHttpClient _buildClient({required Map<String, dynamic> summaryData}) {
  final client = MockHttpClient();
  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => _json(summaryData));
  return client;
}

Widget _screen() => wrapApp(
      const TrainingSessionSummaryScreen(
        sessionId: 's1',
        sessionName: 'Adulto GI',
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
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('TrainingSessionSummaryScreen — exibição dos stat cards', () {
    testWidgets('exibe card "Confirmaram" com valor', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(totalPreConfirmed: 5, totalAttended: 4)),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Confirmaram'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('exibe card "Vieram" com valor', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(totalPreConfirmed: 5, totalAttended: 4)),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Vieram'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('exibe card "Furos" com valor', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(
          totalPreConfirmed: 2,
          totalAttended: 1,
          furos: [_person('u1', 'João')],
        )),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Furos'), findsOneWidget);
    });

    testWidgets('exibe data e horário no cabeçalho', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary()),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('20/06/2026'), findsOneWidget);
      expect(find.textContaining('19:00'), findsOneWidget);
    });
  });

  group('TrainingSessionSummaryScreen — seções de pessoas', () {
    testWidgets('exibe seção de furos quando há furos', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(
          totalPreConfirmed: 2,
          totalAttended: 1,
          furos: [_person('u1', 'João')],
          confirmedAndAttended: [_person('u2', 'Maria')],
        )),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmaram e não vieram'), findsOneWidget);
      expect(find.text('João'), findsOneWidget);
    });

    testWidgets('exibe seção de surpresas quando há surpresas', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(
          totalPreConfirmed: 1,
          totalAttended: 2,
          surpresas: [_person('u3', 'Carlos')],
          confirmedAndAttended: [_person('u2', 'Maria')],
        )),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Vieram sem confirmar'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
    });

    testWidgets('exibe seção "Confirmaram e vieram"', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(
          totalPreConfirmed: 1,
          totalAttended: 1,
          confirmedAndAttended: [_person('u2', 'Maria')],
        )),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmaram e vieram'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
    });

    testWidgets('exibe mensagem de estado vazio quando sem dados', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary()),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nenhum pré-checkin ou presença registrado'),
        findsOneWidget,
      );
    });

    testWidgets('não exibe seção de furos quando vazia', (tester) async {
      ApiService().setHttpClientForTesting(
        _buildClient(summaryData: _summary(
          totalPreConfirmed: 1,
          totalAttended: 1,
          confirmedAndAttended: [_person('u1', 'Ana')],
          furos: [],
        )),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmaram e não vieram'), findsNothing);
    });
  });

  group('TrainingSessionSummaryScreen — erro', () {
    testWidgets('exibe "Tentar novamente" em caso de erro', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Erro de rede'));
      ApiService().setHttpClientForTesting(client);
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });
}
