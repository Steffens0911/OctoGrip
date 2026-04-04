/// Valores de gamificação espelhados no viewer para copy da UI.
///
/// **Manter alinhado com** o backend (`app/config.py`: `LOGIN_STREAK_BONUS_INTERVAL_DAYS`,
/// `LOGIN_STREAK_BONUS_POINTS`). Se alterar no servidor, atualize aqui e faça rebuild do viewer.
const int kLoginStreakBonusIntervalDays = 7;
const int kLoginStreakBonusPoints = 50;
