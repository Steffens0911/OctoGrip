import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/utils/form_utils.dart';

void main() {
  group('validateEmail', () {
    test('aceita e-mails válidos', () {
      expect(validateEmail('a@b.com'), isNull);
      expect(validateEmail('  fulano@octogrip.com.br  '), isNull); // faz trim
    });

    test('obrigatório quando nulo ou vazio', () {
      expect(validateEmail(null), 'E-mail é obrigatório');
      expect(validateEmail('   '), 'E-mail é obrigatório');
    });

    test('rejeita formatos inválidos', () {
      expect(validateEmail('semarroba'), 'Informe um e-mail válido');
      expect(validateEmail('a@b'), 'Informe um e-mail válido');
      expect(validateEmail('a b@c.com'), 'Informe um e-mail válido');
    });
  });

  group('toBrDate', () {
    test('formata dd/MM/aaaa com zero à esquerda', () {
      expect(toBrDate(DateTime(2026, 1, 5)), '05/01/2026');
      expect(toBrDate(DateTime(2026, 12, 31)), '31/12/2026');
    });
  });

  group('toApiDate', () {
    test('formata aaaa-MM-dd com zero à esquerda', () {
      expect(toApiDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(toApiDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('parseApiDate', () {
    test('parseia aaaa-MM-dd válido', () {
      final d = parseApiDate('2026-06-15');
      expect(d, DateTime(2026, 6, 15));
    });

    test('retorna null para nulo, vazio ou formato inválido', () {
      expect(parseApiDate(null), isNull);
      expect(parseApiDate(''), isNull);
      expect(parseApiDate('15/06/2026'), isNull); // formato errado
      expect(parseApiDate('2026-06'), isNull); // partes insuficientes
      expect(parseApiDate('aaaa-bb-cc'), isNull); // não numérico
    });

    test('round-trip toApiDate → parseApiDate', () {
      final original = DateTime(2026, 3, 9);
      expect(parseApiDate(toApiDate(original)), original);
    });
  });
}
