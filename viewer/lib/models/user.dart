class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? graduation;
  final String role;
  final String? academyId;
  final int pointsAdjustment;
  final String? avatarUrl;
  final String? facialPhotoUrl;
  final bool galleryVisible;

  /// Dias seguidos com login (calendário horário de Brasília); vem de GET/PATCH /auth/me.
  final int loginStreakDays;

  /// Gestor/admin: bloqueia ações mutáveis para alunos (`account_frozen` na API).
  final bool accountFrozen;
  final String? accountFreezeReason;

  /// Sequência atual de check-ins pontuais em treinos lançados.
  final int punctualityStreak;

  /// Recorde pessoal de streak de pontualidade.
  final int punctualityStreakBest;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.graduation,
    this.role = 'aluno',
    this.academyId,
    this.pointsAdjustment = 0,
    this.avatarUrl,
    this.facialPhotoUrl,
    this.galleryVisible = true,
    this.loginStreakDays = 0,
    this.accountFrozen = false,
    this.accountFreezeReason,
    this.punctualityStreak = 0,
    this.punctualityStreakBest = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      graduation: json['graduation'] as String?,
      role: json['role'] as String? ?? 'aluno',
      academyId: json['academy_id'] as String?,
      pointsAdjustment: json['points_adjustment'] as int? ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      facialPhotoUrl: json['facial_photo_url'] as String?,
      galleryVisible: json['gallery_visible'] as bool? ?? true,
      loginStreakDays: json['login_streak_days'] as int? ?? 0,
      accountFrozen: json['account_frozen'] as bool? ?? false,
      accountFreezeReason: json['account_freeze_reason'] as String?,
      punctualityStreak: json['punctuality_streak'] as int? ?? 0,
      punctualityStreakBest: json['punctuality_streak_best'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'graduation': graduation,
        'role': role,
        'academy_id': academyId,
        'points_adjustment': pointsAdjustment,
        'avatar_url': avatarUrl,
        'facial_photo_url': facialPhotoUrl,
        'gallery_visible': galleryVisible,
        'login_streak_days': loginStreakDays,
        'account_frozen': accountFrozen,
        'account_freeze_reason': accountFreezeReason,
        'punctuality_streak': punctualityStreak,
        'punctuality_streak_best': punctualityStreakBest,
      };
}
