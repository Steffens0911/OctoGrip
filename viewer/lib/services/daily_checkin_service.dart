import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

const _keyLastCheckinDate = 'daily_checkin_last_date';

/// Serviço de check-in diário silencioso.
///
/// Chama [POST /auth/daily-checkin] uma vez por dia calendário sempre que o
/// app abre ou volta ao primeiro plano. Garante que a sequência de presença
/// (streak) avance mesmo que o usuário nunca faça logout + login explícitos.
///
/// - Idempotente: chamadas duplicadas no mesmo dia não têm efeito negativo.
/// - Silencioso: erros de rede são ignorados (não interrompem o fluxo do app).
class DailyCheckinService {
  DailyCheckinService._();
  static final DailyCheckinService instance = DailyCheckinService._();

  /// Executa o check-in se ainda não foi feito hoje.
  ///
  /// Retorna os pontos de streak concedidos (0 se nenhum ou se já foi feito).
  /// Nunca lança exceção.
  Future<int> maybeCheckin() async {
    if (!AuthService().isLoggedIn) return 0;

    try {
      final today = _todayString();
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_keyLastCheckinDate);

      if (lastDate == today) return 0; // já fez hoje

      final bonus = await ApiService().postDailyCheckin();

      // Marca o dia independente de ter recebido bônus ou não.
      await prefs.setString(_keyLastCheckinDate, today);

      if (bonus > 0) {
        debugPrint('[DailyCheckin] Bônus de streak: +$bonus pontos');
        // Atualiza dados do usuário para refletir novos pontos/nível.
        await AuthService().refreshMe();
      }

      return bonus;
    } catch (e) {
      // Falha silenciosa — sem internet, token expirado etc.
      debugPrint('[DailyCheckin] Falha ignorada: $e');
      return 0;
    }
  }

  /// Limpa o registro local (útil após logout para não bloquear próximo login).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastCheckinDate);
  }

  /// Data de hoje no formato 'AAAA-MM-DD' (fuso local do dispositivo).
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
