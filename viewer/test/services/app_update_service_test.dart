import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/app_update_service.dart';
import 'package:viewer/utils/app_version.dart';
import 'package:viewer/widgets/app_update_gate.dart';

Map<String, dynamic> _config({
  String min = '0.0.0',
  String latest = '0.0.0',
  Map<String, dynamic> flags = const {},
}) =>
    {
      'platform': 'android',
      'min_version': min,
      'latest_version': latest,
      'update_message': null,
      'store_url':
          'https://play.google.com/store/apps/details?id=br.com.octogrip.app',
      'feature_flags': flags,
    };

void main() {
  final service = AppUpdateService.instance;

  setUp(() {
    AppClientInfo.setForTesting(version: '1.3.0+12', platform: 'android');
    service.resetForTesting();
  });

  tearDown(() => AppClientInfo.setForTesting());

  group('comparação de versões (mesma regra da API)', () {
    test('parse', () {
      expect(parseAppVersion('1.3.0+12'), [1, 3, 0, 12]);
      expect(parseAppVersion('1.3.0'), [1, 3, 0, 0]);
      expect(parseAppVersion('1.3'), isNull);
      expect(parseAppVersion(null), isNull);
    });

    test('abaixo da mínima', () {
      expect(isAppVersionBelow('1.2.9+40', '1.3.0'), isTrue);
      expect(isAppVersionBelow('1.3.0+1', '1.3.0'), isFalse);
      expect(isAppVersionBelow('1.3.0+11', '1.3.0+12'), isTrue);
      expect(isAppVersionBelow('1.10.0', '1.9.0'), isFalse);
      expect(isAppVersionBelow('lixo', '1.3.0'), isFalse);
      expect(isAppVersionBelow(null, '1.3.0'), isFalse);
    });
  });

  group('AppClientInfo.headers', () {
    test('app de loja se identifica', () {
      expect(AppClientInfo.headers, {
        'X-App-Version': '1.3.0+12',
        'X-App-Platform': 'android',
      });
    });

    test('web/sem versão não manda nada', () {
      AppClientInfo.setForTesting();
      expect(AppClientInfo.headers, isEmpty);
    });
  });

  group('status a partir de /app/config', () {
    test('abaixo da mínima bloqueia', () {
      service.applyConfig(_config(min: '1.4.0', latest: '1.4.0'));
      expect(service.status, AppUpdateStatus.required);
    });

    test('abaixo só da mais recente sugere', () {
      service.applyConfig(_config(min: '1.0.0', latest: '1.4.0'));
      expect(service.status, AppUpdateStatus.optional);
      expect(service.showOptionalPrompt, isTrue);
      service.dismissOptional();
      expect(service.showOptionalPrompt, isFalse);
    });

    test('em dia não mostra nada', () {
      service.applyConfig(_config(min: '1.0.0', latest: '1.3.0'));
      expect(service.status, AppUpdateStatus.none);
    });

    test('checkForUpdate consulta a API com a plataforma', () async {
      Uri? called;
      service.setHttpClientForTesting(MockClient((request) async {
        called = request.url;
        return http.Response(jsonEncode(_config(min: '2.0.0')), 200);
      }));
      await service.checkForUpdate(force: true);
      expect(called?.path, endsWith('/app/config'));
      expect(called?.queryParameters['platform'], 'android');
      expect(service.status, AppUpdateStatus.required);
    });

    test('falha de rede nunca bloqueia', () async {
      service.setHttpClientForTesting(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      await service.checkForUpdate(force: true);
      expect(service.status, AppUpdateStatus.none);
    });

    test('na web não consulta', () async {
      AppClientInfo.setForTesting();
      var calls = 0;
      service.setHttpClientForTesting(MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      await service.checkForUpdate(force: true);
      expect(calls, 0);
    });
  });

  group('feature flags', () {
    test('respeita enabled e min_app_version', () {
      service.applyConfig(_config(flags: {
        'ligada': {'enabled': true},
        'desligada': {'enabled': false},
        'versao_futura': {'enabled': true, 'min_app_version': '1.4.0'},
        'versao_atual': {'enabled': true, 'min_app_version': '1.3.0'},
        'booleana': true,
      }));
      expect(service.isFeatureEnabled('ligada'), isTrue);
      expect(service.isFeatureEnabled('desligada'), isFalse);
      expect(service.isFeatureEnabled('versao_futura'), isFalse);
      expect(service.isFeatureEnabled('versao_atual'), isTrue);
      expect(service.isFeatureEnabled('booleana'), isTrue);
      expect(service.isFeatureEnabled('inexistente'), isFalse);
    });
  });

  group('cliente HTTP da ApiService', () {
    test('manda a versão do app e trata 426 como atualização obrigatória',
        () async {
      Map<String, String>? sentHeaders;
      ApiService().setHttpClientForTesting(MockClient((request) async {
        sentHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'detail': 'Atualize para continuar.',
            'error': {'type': 'AppUpdateRequiredError'},
            'update': {
              'min_version': '1.4.0',
              'store_url': 'https://play.google.com/x',
            },
          }),
          426,
          headers: {'content-type': 'application/json'},
        );
      }));

      await expectLater(ApiService().getAuthMe('token'), throwsA(anything));

      expect(sentHeaders?['X-App-Version'], '1.3.0+12');
      expect(sentHeaders?['X-App-Platform'], 'android');
      expect(service.status, AppUpdateStatus.required);
      expect(service.minVersion, '1.4.0');
      expect(service.message, 'Atualize para continuar.');
    });
  });

  group('AppUpdateGate', () {
    Widget app() => MaterialApp(
          home: AppUpdateGate(
            service: service,
            child: const Scaffold(body: Text('conteúdo do app')),
          ),
        );

    testWidgets('em dia mostra o app', (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('conteúdo do app'), findsOneWidget);
      expect(find.byKey(const Key('update-required-button')), findsNothing);
    });

    testWidgets('versão obrigatória bloqueia o app', (tester) async {
      await tester.pumpWidget(app());
      service.applyConfig(_config(min: '2.0.0', latest: '2.0.0'));
      await tester.pump();
      expect(find.text('conteúdo do app'), findsNothing);
      expect(find.text('Atualização necessária'), findsOneWidget);
      expect(find.byKey(const Key('update-required-button')), findsOneWidget);
    });

    testWidgets('versão opcional mostra aviso dispensável', (tester) async {
      await tester.pumpWidget(app());
      service.applyConfig(_config(min: '1.0.0', latest: '2.0.0'));
      await tester.pump();
      expect(find.text('conteúdo do app'), findsOneWidget);
      expect(find.byKey(const Key('update-optional-button')), findsOneWidget);
      await tester.tap(find.text('Agora não'));
      await tester.pump();
      expect(find.byKey(const Key('update-optional-button')), findsNothing);
    });
  });
}
