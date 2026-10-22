class QrTokenModel {
  final String token;
  final DateTime expiresAt;
  final String shortCode;

  QrTokenModel(
      {required this.token, required this.expiresAt, required this.shortCode});

  factory QrTokenModel.fromJson(Map<String, dynamic> json) {
    return QrTokenModel(
      token: (json['token'] as String? ?? ''),
      expiresAt: (DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0)),
      shortCode: (json['short_code'] as String? ?? ''),
    );
  }
}
