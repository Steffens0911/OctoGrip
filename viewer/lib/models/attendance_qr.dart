class QrTokenModel {
  final String token;
  final DateTime expiresAt;
  final String shortCode;

  QrTokenModel({required this.token, required this.expiresAt, required this.shortCode});

  factory QrTokenModel.fromJson(Map<String, dynamic> json) {
    return QrTokenModel(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      shortCode: json['short_code'] as String,
    );
  }
}
