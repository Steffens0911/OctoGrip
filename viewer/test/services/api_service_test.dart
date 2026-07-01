import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// StreamedResponse JSON — usado para mockar `client.send` (faceArrive é multipart).
http.StreamedResponse streamedJson(Object body, int status) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

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
    registerFallbackValue(http.Request('POST', Uri.parse('http://fallback')));
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
  // Retry automático em GET após falha de conexão transiente
  // -------------------------------------------------------------------------
  group('ApiService — retry em GET transiente', () {
    test('getTrainingSessions refaz após ClientException e retorna sucesso', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw http.ClientException('Failed to fetch');
        }
        return jsonOk([
          {'id': 's1'},
        ]);
      });

      final result =
          await ApiService().getTrainingSessions('a1', classDate: '2026-06-29');

      expect(calls, 2, reason: 'deve ter tentado uma segunda vez');
      expect(result, hasLength(1));
      expect(result.first['id'], 's1');
    });

    test('getTrainingSessions propaga erro se todas as tentativas falham', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        throw http.ClientException('Failed to fetch');
      });

      await expectLater(
        ApiService().getTrainingSessions('a1'),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 3, reason: 'tenta uma vez e refaz duas vezes antes de desistir');
    });

    test('getNotifications refaz após ClientException e retorna sucesso', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        if (calls < 3) {
          throw http.ClientException('Failed to fetch');
        }
        return jsonOk([
          {'id': 'n1'},
        ]);
      });

      final result = await ApiService().getNotifications();

      expect(calls, 3, reason: 'duas falhas e sucesso na terceira tentativa');
      expect(result, hasLength(1));
      expect(result.first['id'], 'n1');
    });

    test('getUnreadNotificationsCount refaz após ClientException', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw http.ClientException('Failed to fetch');
        }
        return jsonOk({'count': 7});
      });

      final count = await ApiService().getUnreadNotificationsCount();

      expect(calls, 2, reason: 'deve ter tentado uma segunda vez');
      expect(count, 7);
    });

    test('GET refaz em resposta 502 transiente do proxy', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          return jsonError(502, 'Bad Gateway');
        }
        return jsonOk([
          {'id': 's1'},
        ]);
      });

      final result = await ApiService().getTrainingSessions('a1');

      expect(calls, 2, reason: '502 deve disparar nova tentativa');
      expect(result, hasLength(1));
    });

    test('GET propaga 502 se todas as tentativas retornam 502', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        return jsonError(502, 'Bad Gateway');
      });

      await expectLater(
        ApiService().getTrainingSessions('a1'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 3, reason: 'tenta uma vez e refaz duas vezes antes de desistir');
    });
  });

  // -------------------------------------------------------------------------
  // Retry em mutações (POST/PATCH/DELETE) na race de keep-alive
  // -------------------------------------------------------------------------
  group('ApiService — retry em mutação transiente', () {
    test('POST refaz após ClientException e conclui (login)', () async {
      final client = setUpApiService();
      var posts = 0;
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        final uri = invocation.positionalArguments.first as Uri;
        if (uri.path.endsWith('/auth/login')) {
          posts++;
          if (posts == 1) throw http.ClientException('Failed to fetch');
          return jsonOk({'access_token': 'tok', 'streak_bonus_points': 0});
        }
        return jsonOk({});
      });
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonOk({'id': 'u1', 'email': 'a@b.com'}));

      final res = await ApiService().login('a@b.com', 'senha');

      expect(posts, 2, reason: 'ClientException no POST deve disparar retry');
      expect(res.token, 'tok');
    });

    test('PATCH refaz após ClientException e retorna sucesso', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.patch(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('Failed to fetch');
        return jsonOk({'id': 'a1', 'name': 'Academia'});
      });

      final academy = await ApiService().updateAcademyTheme('a1', 'Guarda');

      expect(calls, 2, reason: 'PATCH deve retentar em falha de conexão');
      expect(academy.id, 'a1');
    });

    test('POST propaga ClientException se todas as tentativas falham', () async {
      final client = setUpApiService();
      var calls = 0;
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async {
        calls++;
        throw http.ClientException('Failed to fetch');
      });

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 3, reason: 'tenta uma vez e refaz duas vezes antes de desistir');
    });

    test('POST NÃO retenta em 5xx (evita duplicar efeito) e lança ApiException',
        () async {
      final client = setUpApiService();
      var calls = 0;
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async {
        calls++;
        return jsonError(502, 'Bad Gateway');
      });

      await expectLater(
        ApiService().forgotPassword('x@y.com'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
      );
      expect(calls, 1,
          reason: '502 numa mutação não é retentado: o servidor pode ter processado');
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

  // -------------------------------------------------------------------------
  // Quiosque facial — retry transiente no faceArrive (POST multipart idempotente)
  // -------------------------------------------------------------------------
  group('ApiService — faceArrive retry transiente', () {
    final frame = Uint8List.fromList(const [1, 2, 3, 4]);

    test('retenta após 503 do worker e retorna sucesso', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.send(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) return streamedJson({'detail': 'indisponível'}, 503);
        return streamedJson({
          'matched': true,
          'confidence': 0.9,
          'student_id': 's1',
          'student_name': 'Aluno',
          'greeting': 'Bem-vindo!',
          'xp_awarded': 10,
        }, 200);
      });

      final result = await ApiService().faceArrive('sess1', frame);

      expect(calls, 2, reason: '503 transiente deve disparar nova tentativa');
      expect(result.matched, true);
      expect(result.studentName, 'Aluno');
    });

    test('retenta após 502 e desiste após esgotar tentativas', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.send(any())).thenAnswer((_) async {
        calls++;
        return streamedJson({'detail': 'Bad Gateway'}, 502);
      });

      await expectLater(
        ApiService().faceArrive('sess1', frame),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
      );
      expect(calls, 3, reason: 'tenta uma vez e refaz duas antes de desistir');
    });

    test('retenta após ClientException e propaga se todas falham', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.send(any())).thenAnswer((_) async {
        calls++;
        throw http.ClientException('Failed to fetch');
      });

      await expectLater(
        ApiService().faceArrive('sess1', frame),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 3);
    });

    test('não retenta em erro não-transiente (ex.: 409 sessão inativa)', () async {
      final client = setUpApiService(token: 'tok');
      var calls = 0;
      when(() => client.send(any())).thenAnswer((_) async {
        calls++;
        return streamedJson({'detail': 'A chamada não está ativa.'}, 409);
      });

      await expectLater(
        ApiService().faceArrive('sess1', frame),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
      expect(calls, 1, reason: '409 não é transiente — falha na primeira tentativa');
    });
  });
}
