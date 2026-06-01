import 'package:viewer/models/manual_trophy.dart';

/// Item da galeria de troféus e medalhas: premiação com tier conquistado (ouro/prata/bronze) ou nenhum.
class TrophyWithEarned {
  final String trophyId;
  final String techniqueId;
  final String? academyId;
  final String name;
  final String? techniqueName;
  final String? techniqueVideoUrl;
  final String startDate;
  final String endDate;
  final int targetCount;
  /// 'medal' = premiação ordinária; 'trophy' = premiação especial (longo prazo).
  final String awardKind;
  final int? minDurationDays;
  /// Nível mínimo (reward_level) para desbloquear; 0 = sem requisito.
  final int minRewardLevelToUnlock;
  /// Faixa mínima para desbloquear (white, blue, purple, brown, black); null = todos.
  final String? minGraduationToUnlock;
  /// Limite de execuções que contam por adversário no período; null = regras padrão.
  final int? maxCountPerOpponent;
  /// Se o aluno já atingiu nível e faixa mínimos para poder competir por este troféu.
  final bool unlocked;
  final String? earnedTier; // 'gold' | 'silver' | 'bronze' | 'participation' | null
  final int goldCount;
  final int silverCount;
  final int bronzeCount;
  /// true quando veio de uma concessão manual (professor concedeu), não de execuções.
  final bool isManualAward;
  /// Observação livre do professor ao conceder o troféu manualmente.
  final String? awardNote;
  /// Nome do campeonato (para concessões de campeonato).
  final String? championshipEventName;

  TrophyWithEarned({
    required this.trophyId,
    required this.techniqueId,
    this.academyId,
    required this.name,
    this.techniqueName,
    this.techniqueVideoUrl,
    required this.startDate,
    required this.endDate,
    required this.targetCount,
    this.awardKind = 'trophy',
    this.minDurationDays,
    this.minRewardLevelToUnlock = 0,
    this.minGraduationToUnlock,
    this.maxCountPerOpponent,
    this.unlocked = true,
    this.earnedTier,
    this.goldCount = 0,
    this.silverCount = 0,
    this.bronzeCount = 0,
    this.isManualAward = false,
    this.awardNote,
    this.championshipEventName,
  });

  factory TrophyWithEarned.fromJson(Map<String, dynamic> json) {
    return TrophyWithEarned(
      trophyId: json['trophy_id'] as String,
      techniqueId: json['technique_id'] as String,
      academyId: json['academy_id'] as String?,
      name: json['name'] as String,
      techniqueName: json['technique_name'] as String?,
      techniqueVideoUrl: json['technique_video_url'] as String?,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      awardKind: json['award_kind'] as String? ?? 'trophy',
      minDurationDays: (json['min_duration_days'] as num?)?.toInt(),
      minRewardLevelToUnlock:
          (json['min_reward_level_to_unlock'] as num?)?.toInt() ?? 0,
      minGraduationToUnlock: json['min_graduation_to_unlock'] as String?,
      maxCountPerOpponent: (json['max_count_per_opponent'] as num?)?.toInt(),
      unlocked: json['unlocked'] as bool? ?? true,
      earnedTier: json['earned_tier'] as String?,
      goldCount: (json['gold_count'] as num?)?.toInt() ?? 0,
      silverCount: (json['silver_count'] as num?)?.toInt() ?? 0,
      bronzeCount: (json['bronze_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory TrophyWithEarned.fromManualAward(TrophyAward award) {
    final isChampionship = award.trophyType == 'championship';
    return TrophyWithEarned(
      trophyId: award.id,
      techniqueId: '',
      name: award.templateName,
      startDate: award.awardedAt,
      endDate: award.awardedAt,
      targetCount: 0,
      awardKind: isChampionship ? 'medal' : 'trophy',
      unlocked: true,
      earnedTier: award.medalType,
      isManualAward: true,
      awardNote: award.note,
      championshipEventName: award.championshipEventName,
    );
  }

  bool get isTrophy => awardKind == 'trophy';
  bool get isMedal => awardKind == 'medal';
  String get awardKindLabel => isTrophy ? 'Troféu' : 'Medalha';

  static String tierEmoji(String? tier) {
    switch (tier) {
      case 'gold': return '🥇';
      case 'silver': return '🥈';
      case 'bronze': return '🥉';
      case 'participation': return '🎖️';
      default: return '🏆';
    }
  }

  String get tierLabel {
    if (isManualAward && earnedTier == null) return 'Concedido';
    if (earnedTier == null) return 'A conquistar';
    switch (earnedTier!) {
      case 'gold': return 'Ouro';
      case 'silver': return 'Prata';
      case 'bronze': return 'Bronze';
      case 'participation': return 'Participação';
      default: return earnedTier!;
    }
  }

  static String? graduationLabel(String? graduation) {
    if (graduation == null || graduation.isEmpty) return null;
    switch (graduation.toLowerCase()) {
      case 'white': return 'Branca';
      case 'blue': return 'Azul';
      case 'purple': return 'Roxa';
      case 'brown': return 'Marrom';
      case 'black': return 'Preta';
      default: return graduation;
    }
  }
}

class TrophyHomeSummaryItem {
  final String trophyId;
  final String name;
  final String awardKind;
  final String tier;

  TrophyHomeSummaryItem({
    required this.trophyId,
    required this.name,
    required this.awardKind,
    required this.tier,
  });

  factory TrophyHomeSummaryItem.fromJson(Map<String, dynamic> json) =>
      TrophyHomeSummaryItem(
        trophyId: json['trophy_id'] as String,
        name: json['name'] as String,
        awardKind: json['award_kind'] as String? ?? 'trophy',
        tier: json['tier'] as String,
      );

  String get emoji => TrophyWithEarned.tierEmoji(tier);
}

class AcademyRecentItem {
  final String userId;
  final String userName;
  final String tier;
  final String trophyName;
  final String awardKind;

  AcademyRecentItem({
    required this.userId,
    required this.userName,
    required this.tier,
    required this.trophyName,
    required this.awardKind,
  });

  factory AcademyRecentItem.fromJson(Map<String, dynamic> json) =>
      AcademyRecentItem(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        tier: json['tier'] as String,
        trophyName: json['trophy_name'] as String,
        awardKind: json['award_kind'] as String? ?? 'trophy',
      );

  String get tierEmoji => TrophyWithEarned.tierEmoji(tier);
  String get firstName => userName.split(' ').first;
  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class AcademyUserEarnedItem {
  final String trophyId;
  final String name;
  final String tier;
  final String awardKind;

  AcademyUserEarnedItem({
    required this.trophyId,
    required this.name,
    required this.tier,
    required this.awardKind,
  });

  factory AcademyUserEarnedItem.fromJson(Map<String, dynamic> json) =>
      AcademyUserEarnedItem(
        trophyId: json['trophy_id'] as String,
        name: json['name'] as String,
        tier: json['tier'] as String,
        awardKind: json['award_kind'] as String? ?? 'trophy',
      );

  String get emoji => TrophyWithEarned.tierEmoji(tier);
}

class AcademyUserEarned {
  final String userId;
  final List<AcademyUserEarnedItem> items;

  AcademyUserEarned({required this.userId, required this.items});

  factory AcademyUserEarned.fromJson(Map<String, dynamic> json) =>
      AcademyUserEarned(
        userId: json['user_id'] as String,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AcademyUserEarnedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TrophyHomeSummary {
  final int myEarnedCount;
  final List<TrophyHomeSummaryItem> myRecent;
  final List<AcademyRecentItem> academyRecent;

  TrophyHomeSummary({
    required this.myEarnedCount,
    required this.myRecent,
    required this.academyRecent,
  });

  factory TrophyHomeSummary.fromJson(Map<String, dynamic> json) =>
      TrophyHomeSummary(
        myEarnedCount: (json['my_earned_count'] as num?)?.toInt() ?? 0,
        myRecent: (json['my_recent'] as List<dynamic>? ?? [])
            .map((e) => TrophyHomeSummaryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        academyRecent: (json['academy_recent'] as List<dynamic>? ?? [])
            .map((e) => AcademyRecentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
