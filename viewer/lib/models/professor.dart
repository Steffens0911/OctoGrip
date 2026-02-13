/// Modelo de professor (alinhado à API GET /professors).
class Professor {
  final String id;
  final String name;
  final String email;
  final String? academyId;

  const Professor({
    required this.id,
    required this.name,
    required this.email,
    this.academyId,
  });

  factory Professor.fromJson(Map<String, dynamic> json) {
    return Professor(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      academyId: json['academy_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'academy_id': academyId,
      };
}
