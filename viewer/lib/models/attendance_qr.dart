class QrTokenModel {
  final String token;
  final DateTime expiresAt;

  QrTokenModel({required this.token, required this.expiresAt});

  factory QrTokenModel.fromJson(Map<String, dynamic> json) {
    return QrTokenModel(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
