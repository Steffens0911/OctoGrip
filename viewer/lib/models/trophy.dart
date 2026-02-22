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
      targetCount: json['target_count'] as int,
      awardKind: json['award_kind'] as String? ?? 'trophy',
      minDurationDays: (json['min_duration_days'] as num?)?.toInt(),
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
}
