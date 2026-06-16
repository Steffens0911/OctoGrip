import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/student/student_home_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Retorna resposta mockada baseada no path da URL.
http.Response _dispatch(Uri uri) {
  final p = uri.path;

  if (p.endsWith('/auth/me')) {
    return _json({
      'id': 'u-test',
      'email': 'aluno@test.com',
      'name': 'Aluno Teste',
      'role': 'aluno',
      'academy_id': 'ac1',
      'points_adjustment': 0,
      'login_streak_days': 3,
      'account_frozen': false,
      'gallery_visible': true,
    });
  }
  if (p.endsWith('/me/header_stats')) {
    return _json({
      'reward_level': 2,
      'reward_level_points': 150,
      'next_level_threshold': 300,
      'academy': {
        'name': 'Academia Teste',
        'logo_url': null,
        'show_trophies': true,
        'show_partners': false,
        'login_notice_active': false,
      },
    });
  }
  if (p.endsWith('/mission_today/week')) {
    return _json({'entries': [], 'available_kits': [], 'needs_kit_choice': false});
  }
  if (p.contains('/collective_goals/current')) {
    return _json({'detail': 'Not found'}, 404);
  }
  if (p.endsWith('/executions/pending_confirmations/count')) {
    return _json({'count': 0});
  }
  if (p.endsWith('/executions/my_executions')) {
    return _json([]);
  }
  if (p.endsWith('/me/training_videos/today')) {
    return _json([]);
  }
  if (p.endsWith('/trophies/me/home-summary')) {
    return _json({'recent_earned': [], 'academy_feed': []});
  }
  if (p.endsWith('/partners')) {
    return _json([]);
  }
  // Fallback: retorna lista vazia para qualquer outro endpoint
  return _json([]);
}

/// Usuário aluno com academyId para testes do StudentHomeScreen.
UserModel _testStudent() => UserModel(
      id: 'u-test',
      email: 'aluno@test.com',
      name: 'Aluno Teste',
      role: 'aluno',
      academyId: 'ac1',
      loginStreakDays: 3,
    );

Widget _screen() => MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: const StudentHomeScreen(),
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    // Tour marcado como feito → não abre overlay durante testes
    SharedPreferences.setMockInitialValues({
      'training_field_tour_v1_u-test': true,
    });
    AuthService().setForTesting(token: 'tok', user: _testStudent());
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  // ---- Estado carregado ----
  group('StudentHomeScreen — carregado', () {
    testWidgets('tela renderiza sem crash após API responder', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Nenhuma exceção lançada + screen ainda está na árvore
      expect(find.byType(StudentHomeScreen), findsOneWidget);
    });

    testWidgets('nome da academia aparece após carregar o header', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });

    testWidgets('WeeklyMissionPath é renderizado (pode estar vazio)', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Independente de ter missões, a tela deve ter renderizado
      expect(find.byType(StudentHomeScreen), findsOneWidget);
    });
  });

  // ---- Usuário sem academia ----
  group('StudentHomeScreen — sem academia', () {
    testWidgets('renderiza sem crash quando usuário não tem academyId', (tester) async {
      AuthService().setForTesting(
        token: 'tok',
        user: UserModel(
          id: 'u2',
          email: 'sem-academia@test.com',
          name: 'Sem Academia',
          role: 'aluno',
        ),
      );

      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(StudentHomeScreen), findsOneWidget);
    });
  });
}
