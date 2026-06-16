import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

void main() {
  group('userFacingMessage — ApiException', () {
    test('401 vira mensagem de credenciais inválidas', () {
      final msg = userFacingMessage(ApiException(401, 'Unauthorized'));
      expect(msg, 'E-mail ou senha inválidos.');
    });

    test('403 AccountFrozenError devolve a mensagem original da API', () {
      final msg = userFacingMessage(
        ApiException(403, 'Conta congelada: mensalidade em atraso',
            errorType: 'AccountFrozenError'),
      );
      expect(msg, 'Conta congelada: mensalidade em atraso');
    });

    test('outros ApiException devolvem a própria mensagem', () {
      final msg = userFacingMessage(ApiException(500, 'Erro interno'));
      expect(msg, 'Erro interno');
    });
  });

  group('userFacingMessage — TimeoutException', () {
    test('usa a mensagem quando presente', () {
      final msg = userFacingMessage(TimeoutException('Demorou demais'));
      expect(msg, 'Demorou demais');
    });

    test('fallback quando a mensagem é vazia', () {
      final msg = userFacingMessage(TimeoutException(''));
      expect(msg, contains('Tempo esgotado'));
    });
  });

  group('userFacingMessage — falhas de rede', () {
    test('SocketException é tratada como falha de conexão', () {
      final msg = userFacingMessage(Exception('SocketException: failed'));
      expect(msg, contains('Falha de conexão'));
    });

    test('ClientException "Failed to fetch" é falha de conexão', () {
      final msg = userFacingMessage(
        Exception('ClientException: Failed to fetch'),
      );
      expect(msg, contains('Falha de conexão'));
    });
  });

  group('userFacingMessage — fallback genérico', () {
    test('remove prefixo de exceção nomeada (ex.: AcademyServiceException:)', () {
      final msg = userFacingMessage(_NamedException('Algo quebrou'));
      expect(msg, 'Algo quebrou');
    });

    test('Exception genérica do Dart mantém o prefixo "Exception:"', () {
      // O regex exige uma palavra antes de "Exception", então "Exception:" puro
      // não é removido.
      final msg = userFacingMessage(Exception('Algo quebrou'));
      expect(msg, 'Exception: Algo quebrou');
    });
  });
}

/// Exceção com toString no formato "<Nome>Exception: <msg>", como as do app.
class _NamedException implements Exception {
  _NamedException(this.message);
  final String message;
  @override
  String toString() => 'AcademyServiceException: $message';
}
