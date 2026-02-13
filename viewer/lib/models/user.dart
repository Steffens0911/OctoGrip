class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? academyId;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.academyId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      academyId: json['academy_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'academy_id': academyId,
      };
}
