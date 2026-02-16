class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? graduation;
  final String? academyId;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.graduation,
    this.academyId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      graduation: json['graduation'] as String?,
      academyId: json['academy_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'graduation': graduation,
        'academy_id': academyId,
      };
}
