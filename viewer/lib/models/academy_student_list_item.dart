/// Item de lista compacta — `GET /students/academy/{id}/list`.
class AcademyStudentListItem {
  final String id;
  final String? name;
  final String? belt;
  final String? avatarUrl;

  AcademyStudentListItem({
    required this.id,
    this.name,
    this.belt,
    this.avatarUrl,
  });

  factory AcademyStudentListItem.fromJson(Map<String, dynamic> json) {
    return AcademyStudentListItem(
      id: json['id'] as String,
      name: json['name'] as String?,
      belt: json['belt'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
