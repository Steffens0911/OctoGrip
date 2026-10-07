import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/academy/attendance_session_detail_screen.dart';
import 'package:viewer/screens/academy/attendance_session_screen.dart';
import 'package:viewer/services/api_service.dart';

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

UserModel _gestor() => UserModel(
      id: 'u-test',
      email: 'gestor@test.com',
      role: 'gerente_academia',
      academyId: 'ac1',
    );

Map<String, dynamic> _academyJson({bool qrEnabled = true}) => {
      'id': 'ac1',
      'name': 'Academia Teste',
      'slug': 'acad-teste',
      'qr_attendance_enabled': qrEnabled,
      'face_recognition_enabled': false,
      'face_checkin_enabled': false,
    };

Map<String, dynamic> _sessionJson({String status = 'closed'}) => {
      'id': 's1',
      'academy_id': 'ac1',
      'created_by_user_id': 'u-test',
      'status': status,
      'title': 'Turma A',
      'starts_at': '2026-06-01T10:00:00Z',
      'ends_at': '2026-06-01T11:00:00Z',
      'expires_at': null,
      'present_count': 1,
    };

Map<String, dynamic> _recordJson({String userId = 'p1'}) => {
      'id': 'r1',
      'session_id': 's1',
      'user_id': userId,
      'checked_in_at': '2026-06-01T10:05:00Z',
      'method': 'manual',
      'face_recognition': false,
      'added_manually': true,
    };

Map<String, dynamic> _userJson({
  String id = 'p1',
  String name = 'Carlos Mestre',
  String role = 'professor',
}) =>
    {
      'id': id,
      'email': '$id@test.com',
      'name': name,
      'role': role,
      'academy_id': 'ac1',
      'graduation': 'black',
    };

/// Responde por padrão de URL — a tela faz várias chamadas em paralelo.
void _stubGets(MockHttpClient client) {
  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((invocation) async {
    final url = (invocation.positionalArguments.first as Uri).toString();
    if (url.contains('/attendance/sessions/s1/records')) {
      return _json([_recordJson()]);
    }
    if (url.contains('/attendance/sessions/s1')) {
      return _json(_sessionJson());
    }
    if (url.contains('/students/academy/')) {
      return _json([
        {
          'id': 'p1',
          'name': 'Carlos Mestre',
          'belt': 'black',
          'avatar_url': null,
          'role': 'professor',
        },
      ]);
    }
    if (url.contains('/users/')) {
      return _json(_userJson());
    }
    if (url.contains('/users')) {
      return _json([_userJson()]);
    }
    if (url.contains('/academies/')) {
      return _json(_academyJson());
    }
    return _json(<String, dynamic>{});
  });
}

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
    setAuthForTesting(user: _gestor());
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AttendanceSessionScreen — antes de iniciar a chamada', () {
    testWidgets('renderiza sem crash para gestor', (tester) async {
      final client = MockHttpClient();
      _stubGets(client);
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(const MaterialApp(home: AttendanceSessionScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceSessionScreen), findsOneWidget);
      expect(find.textContaining('Iniciar chamada'), findsWidgets);
    });

    testWidgets('texto do QR não presume que quem bate presença é aluno',
        (tester) async {
      final client = MockHttpClient();
      _stubGets(client);
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(const MaterialApp(home: AttendanceSessionScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Quem está no treino escaneia'), findsOneWidget);
      expect(find.textContaining('Os alunos escaneiam'), findsNothing);
    });
  });

  group('AttendanceSessionDetailScreen — presença manual', () {
    testWidgets('botão fala "Adicionar presença"', (tester) async {
      final client = MockHttpClient();
      _stubGets(client);
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceSessionDetailScreen(sessionId: 's1')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Adicionar presença'), findsOneWidget);
      expect(find.textContaining('Adicionar aluno'), findsNothing);

      // Dispensa a tela: cancela os timers do WebSocket pendentes.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('abre o modal de presença e lista staff', (tester) async {
      final client = MockHttpClient();
      _stubGets(client);
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceSessionDetailScreen(sessionId: 's1')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Adicionar presença'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Selecione uma ou mais pessoas'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
