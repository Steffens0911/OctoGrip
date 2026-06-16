import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resposta JSON com status 200.
http.Response jsonOk(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

/// Resposta de erro com payload padrão FastAPI.
http.Response jsonError(int status, String detail, {String? errorType}) {
  final body = errorType != null
      ? {'error': {'type': errorType, 'message': detail}}
      : {'detail': detail};
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json'});
}

/// Configura SharedPreferences como mock e injeta um MockHttpClient no ApiService.
MockHttpClient setUpApiService({String? token}) {
  SharedPreferences.setMockInitialValues({
    if (token != null) 'auth_token': token,
  });
  // Reseta o AuthService singleton para o estado desejado.
  AuthService().setForTesting(
    token: token,
    user: token != null ? stubStudent() : null,
  );
  final client = MockHttpClient();
  ApiService().setHttpClientForTesting(client);
  return client;
}

void main() {
  setUpAll(() {
    // Registra fallbacks exigidos pelo mocktail para tipos Uri e BaseRequest.
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  tearDown(() {
    // Restaura o client padrão após cada teste.
    ApiService().setHttpClientForTesting(http.Client());
    AuthService().setForTesting(token: null, user: null);
  });

  // -------------------------------------------------------------------------
  // _throwIfNotOk — mapeamento de erros
  // -------------------------------------------------------------------------
  group('ApiService._throwIfNotOk — mapeamento de erros', () {
    test('lança ApiException(401) para resposta 401', () async {
      final client = setUpApiService();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{"detail":"Unauthorized"}', 401));

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('lança ApiException com errorType AccountFrozenError', () async {
      final client = setUpApiService();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonError(
                403,
                'Conta congelada',
                errorType: 'AccountFrozenError',
              ));

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorType, 'errorType', 'AccountFrozenError')
            .having((e) => e.message, 'message', 'Conta congelada')),
      );
    });

    test('lança ApiException(404) com mensagem padrão quando detail ausente', () async {
      final client = setUpApiService();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('', 404, reasonPhrase: 'Not Found'));

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Recurso não encontrado (404).')),
      );
    });

    test('não lança para status 2xx', () async {
      final client = setUpApiService();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonOk({'detail': 'ok'}));

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        completes,
      );
    });
  });

  // -------------------------------------------------------------------------
  // formatApiDetail
  // -------------------------------------------------------------------------
  group('ApiService.formatApiDetail', () {
    test('string passada direto', () {
      expect(ApiService.formatApiDetail('mensagem'), 'mensagem');
    });

    test('null retorna string vazia', () {
      expect(ApiService.formatApiDetail(null), '');
    });

    test('lista de erros FastAPI formata loc.msg', () {
      final detail = [
        {'loc': ['body', 'email'], 'msg': 'field required'}
      ];
      final result = ApiService.formatApiDetail(detail);
      expect(result, contains('email'));
      expect(result, contains('field required'));
    });

    test('lista com API antiga (from_position_id) retorna mensagem de migração', () {
      final detail = [
        {'loc': ['body', 'from_position_id'], 'msg': 'value is not a valid'}
      ];
      final result = ApiService.formatApiDetail(detail);
      expect(result, contains('desatualizada'));
    });
  });

  // -------------------------------------------------------------------------
  // Cache TTL / stale-while-revalidate
  // -------------------------------------------------------------------------
  group('ApiService — cache in-memory', () {
    test('invalidateCache() limpa todo o cache', () {
      final api = ApiService();
      // Chama invalidate para garantir que o cache começa limpo.
      api.invalidateCache();
      // Não há como inspecionar _getCache diretamente (privado), mas o método
      // não deve lançar exceção e a suíte de testes de integração cobre o comportamento.
      // Aqui verificamos que chamá-lo múltiplas vezes é seguro.
      api.invalidateCache();
      api.invalidateCache('GET:http://localhost:8000/mission_today');
    });

    test('legalDocumentViewUrl monta URL correta', () {
      final url = ApiService().legalDocumentViewUrl('terms');
      expect(url, endsWith('/legal/terms/view'));
    });
  });

  // -------------------------------------------------------------------------
  // Headers de autenticação
  // -------------------------------------------------------------------------
  group('ApiService — headers de auth', () {
    test('envia Authorization: Bearer <token> quando logado', () async {
      final client = setUpApiService(token: 'meu-token');

      final captured = <Uri>[];
      final capturedHeaders = <Map<String, String>>[];

      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        captured.add(inv.positionalArguments[0] as Uri);
        capturedHeaders.add(
            Map<String, String>.from(inv.namedArguments[#headers] as Map));
        return jsonOk({
          'id': 'u1',
          'email': 'x@y.com',
          'role': 'aluno',
        });
      });

      await ApiService().getAuthMe();

      expect(capturedHeaders.first['Authorization'], 'Bearer meu-token');
    });

    test('não envia Authorization quando não há token', () async {
      final client = setUpApiService(); // sem token

      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonOk({
                'id': 'u1',
                'email': 'x@y.com',
                'role': 'aluno',
              }));

      await ApiService().getAuthMe();

      final calls = verify(() => client.get(any(), headers: captureAny(named: 'headers')));
      final headers = calls.captured.first as Map;
      expect(headers.containsKey('Authorization'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Deserialização: getMyConsents
  // -------------------------------------------------------------------------
  group('ApiService.getMyConsents', () {
    test('retorna lista de consentimentos da API (payload {"items": [...]})', () async {
      final client = setUpApiService(token: 'tok');

      // A API retorna {"items": [...]}, não uma array direta.
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonOk({
                'items': [
                  {'consent_type': 'terms', 'up_to_date': true, 'granted': true},
                  {'consent_type': 'privacy', 'up_to_date': false, 'granted': false},
                ],
              }));

      final result = await ApiService().getMyConsents();

      expect(result, hasLength(2));
      expect(result.first['consent_type'], 'terms');
      expect(result.last['up_to_date'], isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Timeout
  // -------------------------------------------------------------------------
  group('ApiService — timeout', () {
    test('lança TimeoutException quando a resposta demora além do limite', () async {
      final client = setUpApiService(token: 'tok');

      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 31));
        return jsonOk({});
      });

      await expectLater(
        ApiService().getTrainingStats(),
        throwsA(isA<TimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 35)));
  });
}
