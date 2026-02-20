class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? graduation;
  final String role;
  final String? academyId;
  final int pointsAdjustment;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.graduation,
    this.role = 'aluno',
    this.academyId,
    this.pointsAdjustment = 0,
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
      };
}
