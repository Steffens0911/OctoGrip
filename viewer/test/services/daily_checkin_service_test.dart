import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/daily_checkin_service.dart';

import '../helpers/pump_app.dart';

// DailyCheckinService: singleton com lógica de check-in diário.
// Usa SharedPreferences para evitar chamadas duplicadas no mesmo dia.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('DailyCheckinService.clear', () {
    test('limpa o registro de check-in do SharedPreferences', () async {
      // Simula que o check-in foi feito hoje
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_checkin_last_date', '2024-01-01');

      await DailyCheckinService.instance.clear();

      final after = await SharedPreferences.getInstance();
      expect(after.getString('daily_checkin_last_date'), isNull);
    });

    test('não falha quando não há registro anterior', () async {
      // Não deve lançar exceção
      await expectLater(
        DailyCheckinService.instance.clear(),
        completes,
      );
    });
  });

  group('DailyCheckinService.maybeCheckin', () {
    test('retorna 0 quando usuário não está logado', () async {
      clearAuthForTesting();

      final bonus = await DailyCheckinService.instance.maybeCheckin();
      expect(bonus, 0);
    });

    test('retorna 0 quando já fez check-in hoje', () async {
      final today = DateTime.now();
      final todayStr = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'daily_checkin_last_date': todayStr,
        'auth_token': 'tok',
      });

      // Com a data de hoje já gravada, retorna 0 sem chamar HTTP
      final bonus = await DailyCheckinService.instance.maybeCheckin();
      expect(bonus, 0);
    });
  });
}
