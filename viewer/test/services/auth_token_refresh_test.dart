import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

/// JWT com o payload dado (a assinatura não importa: o app só lê o payload).
String fakeJwt(Map<String, dynamic> payload) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.assinatura';
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

final _issuedAt = DateTime.utc(2026, 10, 1);
final _expiresAt = _issuedAt.add(const Duration(days: 30));

String _token30d() => fakeJwt({'sub': 'u1', 'iat': _secs(_issuedAt), 'exp': _secs(_expiresAt)});

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://fallback'));
  });

  group('AuthService.tokenNeedsRefresh', () {
    test('não renova na primeira metade da validade', () {
      final now = _issuedAt.add(const Duration(days: 14, hours: 23));
      expect(AuthService.tokenNeedsRefresh(_token30d(), now: now), isFalse);
    });

    test('renova a partir da metade da validade', () {
      final now = _issuedAt.add(const Duration(days: 15));
      expect(AuthService.tokenNeedsRefresh(_token30d(), now: now), isTrue);
    });

    test('token antigo sem validade é trocado', () {
      final legado = fakeJwt({'sub': 'u1'});
      expect(AuthService.tokenNeedsRefresh(legado, now: _issuedAt), isTrue);
    });

    test('token que não é JWT nunca é renovado', () {
      expect(AuthService.tokenNeedsRefresh('tok', now: _issuedAt), isFalse);
      expect(AuthService.tokenNeedsRefresh('a.%%%.c', now: _issuedAt), isFalse);
    });
  });

  group('AuthService.refreshTokenIfNeeded', () {
    late MockHttpClient client;
    final halfway = _issuedAt.add(const Duration(days: 16));

    void stubRefresh(Future<http.Response> Function() answer) {
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) => answer());
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({'auth_token': _token30d()});
      AuthService().setForTesting(token: _token30d(), user: stubStudent());
      client = MockHttpClient();
      ApiService().setHttpClientForTesting(client);
    });

    test('troca o token e grava o novo', () async {
      stubRefresh(() async => http.Response(jsonEncode({'access_token': 'novo-token'}), 200));

      await AuthService().refreshTokenIfNeeded(now: halfway);

      expect(AuthService().token, 'novo-token');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'novo-token');
      final captured = verify(() => client.post(captureAny(),
          headers: captureAny(named: 'headers'), body: any(named: 'body'))).captured;
      expect((captured[0] as Uri).path, endsWith('/auth/refresh'));
      expect((captured[1] as Map)['Authorization'], 'Bearer ${_token30d()}');
    });

    test('não chama a API antes da metade da validade', () async {
      await AuthService().refreshTokenIfNeeded(now: _issuedAt.add(const Duration(days: 1)));
      verifyNever(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
      expect(AuthService().token, _token30d());
    });

    test('requisições simultâneas disparam uma renovação só', () async {
      final response = Completer<http.Response>();
      stubRefresh(() => response.future);

      final a = AuthService().refreshTokenIfNeeded(now: halfway);
      final b = AuthService().refreshTokenIfNeeded(now: halfway);
      response.complete(http.Response(jsonEncode({'access_token': 'novo-token'}), 200));
      await Future.wait([a, b]);

      verify(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('falha mantém o token atual e espera antes de tentar de novo', () async {
      stubRefresh(() async => http.Response('', 503));

      await AuthService().refreshTokenIfNeeded(now: halfway);
      expect(AuthService().token, _token30d());
      expect(AuthService().isLoggedIn, isTrue);

      await AuthService().refreshTokenIfNeeded(now: halfway.add(const Duration(minutes: 1)));
      verify(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);

      await AuthService().refreshTokenIfNeeded(now: halfway.add(const Duration(minutes: 6)));
      verify(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('401 na renovação não desloga sozinho', () async {
      stubRefresh(() async => http.Response('{"detail":"Token inválido ou expirado."}', 401));

      await AuthService().refreshTokenIfNeeded(now: halfway);

      expect(AuthService().isLoggedIn, isTrue);
      expect(AuthService().token, _token30d());
    });

    test('novo login durante a renovação não é sobrescrito', () async {
      final response = Completer<http.Response>();
      stubRefresh(() => response.future);

      final pending = AuthService().refreshTokenIfNeeded(now: halfway);
      AuthService().setForTesting(token: 'token-do-novo-login', user: stubStudent());
      response.complete(http.Response(jsonEncode({'access_token': 'novo-token'}), 200));
      await pending;

      expect(AuthService().token, 'token-do-novo-login');
    });
  });
}
