class Confirmant {
  final String userId;
  final String name;
  final String? avatarUrl;

  Confirmant({
    required this.userId,
    required this.name,
    this.avatarUrl,
  });

  factory Confirmant.fromJson(Map<String, dynamic> json) => Confirmant(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class PreCheckinStatus {
  final String? preCheckinId;
  final String? status;
  final String? confirmedAt;
  final String? cancelledAt;
  final List<Confirmant> confirmants;
  final int totalConfirmed;

  PreCheckinStatus({
    this.preCheckinId,
    this.status,
    this.confirmedAt,
    this.cancelledAt,
    this.confirmants = const [],
    this.totalConfirmed = 0,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get hasConfirmed => status != null;

  factory PreCheckinStatus.fromJson(Map<String, dynamic> json) => PreCheckinStatus(
        preCheckinId: json['pre_checkin_id'] as String?,
        status: json['status'] as String?,
        confirmedAt: json['confirmed_at'] as String?,
        cancelledAt: json['cancelled_at'] as String?,
        confirmants: (json['confirmants'] as List<dynamic>? ?? [])
            .map((e) => Confirmant.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalConfirmed: json['total_confirmed'] as int? ?? 0,
      );
}
