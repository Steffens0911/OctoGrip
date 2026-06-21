import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/network_diagnostics_service.dart';

// Testes unitários para NetworkDiagnosticsService.recordError e properties.

void main() {
  group('NetworkDiagnosticsService.recordError', () {
    setUp(() {
      // Limpar estado entre testes
      NetworkDiagnosticsService.recordError(Exception('reset'));
    });

    test('registra erro genérico', () {
      final e = Exception('falha de rede');
      NetworkDiagnosticsService.recordError(e, context: 'login');

      expect(NetworkDiagnosticsService.lastErrorAt, isNotNull);
      expect(NetworkDiagnosticsService.lastErrorContext, 'login');
      expect(NetworkDiagnosticsService.lastErrorDetails, isNotNull);
      expect(NetworkDiagnosticsService.lastErrorDetails, contains('falha de rede'));
    });

    test('registra ApiException com status e mensagem', () {
      final e = ApiException(401, 'não autorizado', errorType: 'unauthorized');
      NetworkDiagnosticsService.recordError(e);

      final details = NetworkDiagnosticsService.lastErrorDetails!;
      expect(details, contains('401'));
      expect(details, contains('não autorizado'));
      expect(details, contains('unauthorized'));
    });

    test('registra TimeoutException', () {
      final e = TimeoutException('tempo esgotado', const Duration(seconds: 10));
      NetworkDiagnosticsService.recordError(e);

      final details = NetworkDiagnosticsService.lastErrorDetails!;
      expect(details, contains('timeout'));
      expect(details, contains('tempo esgotado'));
    });

    test('inclui stack trace no details quando fornecido', () {
      try {
        throw Exception('com stack');
      } catch (e, st) {
        NetworkDiagnosticsService.recordError(e, stackTrace: st);
      }

      expect(NetworkDiagnosticsService.lastErrorDetails, contains('Stack'));
    });
  });

  group('NetworkDiagnosticsService properties', () {
    test('runtimeEnv retorna debug ou release', () {
      final env = NetworkDiagnosticsService.runtimeEnv;
      expect(['debug', 'release'], contains(env));
    });

    test('platformName retorna string não-vazia', () {
      expect(NetworkDiagnosticsService.platformName.isNotEmpty, isTrue);
    });

    test('apiBase é string não-vazia', () {
      expect(NetworkDiagnosticsService.apiBase.isNotEmpty, isTrue);
    });
  });
}
