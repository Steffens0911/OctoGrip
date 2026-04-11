import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:viewer/models/mission_today.dart';

/// Persiste o último snapshot da home do aluno (header agregado + semana de missões)
/// para **web e mobile**: após reload da página ou cold start, a UI pode hidratar
/// antes da rede responder (alinhado a stale-while-revalidate no cliente).
///
/// Chave por utilizador efetivo; em **logout** chamar [clearAll].
class StudentHomeSnapshotStore {
  static const _prefix = 'student_home_snap_v1_';
  static const _maxAge = Duration(days: 7);

  String _key(String userId) => '$_prefix$userId';

  /// Lê snapshot se existir, não estiver expirado e coincidir com academia/nível atuais.
  Future<StudentHomeSnapshot?> read({
    required String userId,
    required String? academyId,
    required String levelKey,
  }) async {
    if (userId.isEmpty) return null;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAtStr = map['saved_at'] as String?;
      if (savedAtStr == null) return null;
      final savedAt = DateTime.tryParse(savedAtStr);
      if (savedAt == null) return null;
      if (DateTime.now().difference(savedAt) > _maxAge) {
        await sp.remove(_key(userId));
        return null;
      }
      final snapAcademy = map['academy_id'] as String?;
      final snapLevel = map['level'] as String? ?? 'beginner';
      final normAcademy = academyId?.trim() ?? '';
      final normSnapAcademy = snapAcademy?.trim() ?? '';
      if (normAcademy != normSnapAcademy) return null;
      if (levelKey != snapLevel) return null;

      final header = map['header'] as Map<String, dynamic>?;
      final weekMap = map['week'] as Map<String, dynamic>?;
      if (header == null || weekMap == null) return null;

      return StudentHomeSnapshot(
        header: header,
        week: MissionWeek.fromJson(weekMap),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String userId,
    required String? academyId,
    required String levelKey,
    required Map<String, dynamic> header,
    required MissionWeek week,
  }) async {
    if (userId.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'academy_id': academyId?.trim() ?? '',
      'level': levelKey,
      'header': header,
      'week': week.toJson(),
    };
    await sp.setString(_key(userId), jsonEncode(payload));
  }

  /// Remove todos os snapshots (ex.: logout neste dispositivo).
  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    final toRemove =
        sp.getKeys().where((k) => k.startsWith(_prefix)).toList(growable: false);
    for (final k in toRemove) {
      await sp.remove(k);
    }
  }
}

class StudentHomeSnapshot {
  final Map<String, dynamic> header;
  final MissionWeek week;
  final DateTime savedAt;

  StudentHomeSnapshot({
    required this.header,
    required this.week,
    required this.savedAt,
  });
}
