/// Item de lista compacta — `GET /students/academy/{id}/list`.
///
/// A lista traz qualquer pessoa vinculada à academia (não só alunos): o mesmo
/// utilizador pode ser professor numa aula e aluno em outra. [role] diz qual.
class AcademyStudentListItem {
  final String id;
  final String? name;
  final String? belt;
  final String? avatarUrl;
  final String? role;

  AcademyStudentListItem({
    required this.id,
    this.name,
    this.belt,
    this.avatarUrl,
    this.role,
  });

  factory AcademyStudentListItem.fromJson(Map<String, dynamic> json) {
    return AcademyStudentListItem(
      id: json['id'] as String,
      name: json['name'] as String?,
      belt: json['belt'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
    );
  }
}
