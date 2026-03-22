/// Item da galeria de troféus e medalhas: premiação com tier conquistado (ouro/prata/bronze) ou nenhum.
class TrophyWithEarned {
  final String trophyId;
  final String techniqueId;
  final String? academyId;
  final String name;
  final String? techniqueName;
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
  /// Se o aluno já atingiu nível e faixa mínimos para poder competir por este troféu.
  final bool unlocked;
  final String? earnedTier; // 'gold' | 'silver' | 'bronze' | null
  final int goldCount;
  final int silverCount;
  final int bronzeCount;

  TrophyWithEarned({
    required this.trophyId,
    required this.techniqueId,
    this.academyId,
    required this.name,
    this.techniqueName,
    required this.startDate,
    required this.endDate,
    required this.targetCount,
    this.awardKind = 'trophy',
    this.minDurationDays,
    this.minRewardLevelToUnlock = 0,
    this.minGraduationToUnlock,
    this.unlocked = true,
    this.earnedTier,
    this.goldCount = 0,
    this.silverCount = 0,
    this.bronzeCount = 0,
  });

  factory TrophyWithEarned.fromJson(Map<String, dynamic> json) {
    return TrophyWithEarned(
      trophyId: json['trophy_id'] as String,
      techniqueId: json['technique_id'] as String,
      academyId: json['academy_id'] as String?,
      name: json['name'] as String,
      techniqueName: json['technique_name'] as String?,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      awardKind: json['award_kind'] as String? ?? 'trophy',
      minDurationDays: (json['min_duration_days'] as num?)?.toInt(),
      minRewardLevelToUnlock:
          (json['min_reward_level_to_unlock'] as num?)?.toInt() ?? 0,
      minGraduationToUnlock: json['min_graduation_to_unlock'] as String?,
      unlocked: json['unlocked'] as bool? ?? true,
      earnedTier: json['earned_tier'] as String?,
      goldCount: (json['gold_count'] as num?)?.toInt() ?? 0,
      silverCount: (json['silver_count'] as num?)?.toInt() ?? 0,
      bronzeCount: (json['bronze_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isTrophy => awardKind == 'trophy';
  bool get isMedal => awardKind == 'medal';
  String get awardKindLabel => isTrophy ? 'Troféu' : 'Medalha';

  String get tierLabel {
    if (earnedTier == null) return 'A conquistar';
    switch (earnedTier!) {
      case 'gold': return 'Ouro';
      case 'silver': return 'Prata';
      case 'bronze': return 'Bronze';
      default: return earnedTier!;
    }
  }

  /// Label em português da faixa mínima para desbloquear; null se não houver restrição.
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
