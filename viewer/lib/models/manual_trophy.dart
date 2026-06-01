// Modelos para troféus manuais (templates, campeonatos e concessões).

class TrophyTemplate {
  final String id;
  final String academyId;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final String trophyType; // 'custom' | 'championship'
  final String? createdBy;
  final String createdAt;

  const TrophyTemplate({
    required this.id,
    required this.academyId,
    required this.name,
    this.description,
    this.icon,
    this.color,
    required this.trophyType,
    this.createdBy,
    required this.createdAt,
  });

  factory TrophyTemplate.fromJson(Map<String, dynamic> j) => TrophyTemplate(
        id: j['id'] as String,
        academyId: j['academy_id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        icon: j['icon'] as String?,
        color: j['color'] as String?,
        trophyType: j['trophy_type'] as String? ?? 'custom',
        createdBy: j['created_by'] as String?,
        createdAt: j['created_at'] as String? ?? '',
      );

  bool get isChampionship => trophyType == 'championship';
}

class ChampionshipEvent {
  final String id;
  final String academyId;
  final String name;
  final String? location;
  final String eventDate;
  final String createdAt;

  const ChampionshipEvent({
    required this.id,
    required this.academyId,
    required this.name,
    this.location,
    required this.eventDate,
    required this.createdAt,
  });

  factory ChampionshipEvent.fromJson(Map<String, dynamic> j) => ChampionshipEvent(
        id: j['id'] as String,
        academyId: j['academy_id'] as String,
        name: j['name'] as String,
        location: j['location'] as String?,
        eventDate: j['event_date'] as String,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class TrophyAward {
  final String id;
  final String templateId;
  final String templateName;
  final String? templateIcon;
  final String? templateColor;
  final String trophyType;
  final String userId;
  final String? awardedBy;
  final String awardedAt;
  final String? championshipEventId;
  final String? championshipEventName;
  final String? championshipEventDate;
  final String? medalType;
  final String? note;

  const TrophyAward({
    required this.id,
    required this.templateId,
    required this.templateName,
    this.templateIcon,
    this.templateColor,
    required this.trophyType,
    required this.userId,
    this.awardedBy,
    required this.awardedAt,
    this.championshipEventId,
    this.championshipEventName,
    this.championshipEventDate,
    this.medalType,
    this.note,
  });

  factory TrophyAward.fromJson(Map<String, dynamic> j) => TrophyAward(
        id: j['id'] as String,
        templateId: j['template_id'] as String,
        templateName: j['template_name'] as String,
        templateIcon: j['template_icon'] as String?,
        templateColor: j['template_color'] as String?,
        trophyType: j['trophy_type'] as String? ?? 'custom',
        userId: j['user_id'] as String,
        awardedBy: j['awarded_by'] as String?,
        awardedAt: j['awarded_at'] as String,
        championshipEventId: j['championship_event_id'] as String?,
        championshipEventName: j['championship_event_name'] as String?,
        championshipEventDate: j['championship_event_date'] as String?,
        medalType: j['medal_type'] as String?,
        note: j['note'] as String?,
      );
}

class UserTrophyAwardsResponse {
  final String userId;
  final List<TrophyAward> championshipAwards;
  final List<TrophyAward> customAwards;

  const UserTrophyAwardsResponse({
    required this.userId,
    required this.championshipAwards,
    required this.customAwards,
  });

  factory UserTrophyAwardsResponse.fromJson(Map<String, dynamic> j) =>
      UserTrophyAwardsResponse(
        userId: j['user_id'] as String,
        championshipAwards: (j['championship_awards'] as List<dynamic>)
            .map((e) => TrophyAward.fromJson(e as Map<String, dynamic>))
            .toList(),
        customAwards: (j['custom_awards'] as List<dynamic>)
            .map((e) => TrophyAward.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
