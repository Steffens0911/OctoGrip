/// Item da galeria de troféus: troféu com tier conquistado (ouro/prata/bronze) ou nenhum.
class TrophyWithEarned {
  final String trophyId;
  final String techniqueId;
  final String? academyId;
  final String name;
  final String? techniqueName;
  final String startDate;
  final String endDate;
  final int targetCount;
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
      earnedTier: json['earned_tier'] as String?,
      goldCount: (json['gold_count'] as num?)?.toInt() ?? 0,
      silverCount: (json['silver_count'] as num?)?.toInt() ?? 0,
      bronzeCount: (json['bronze_count'] as num?)?.toInt() ?? 0,
    );
  }

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
