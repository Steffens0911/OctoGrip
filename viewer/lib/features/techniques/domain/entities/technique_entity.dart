import 'package:equatable/equatable.dart';

/// Entidade imutável de domínio (independente de JSON / Hive).
/// [isOptimistic] indica linha criada localmente antes da confirmação da API.
class TechniqueEntity extends Equatable {
  const TechniqueEntity({
    required this.id,
    required this.academyId,
    required this.name,
    required this.slug,
    this.description,
    this.videoUrl,
    this.isOptimistic = false,
  });

  final String id;
  final String academyId;
  final String name;
  final String slug;
  final String? description;
  final String? videoUrl;
  final bool isOptimistic;

  TechniqueEntity copyWith({
    String? id,
    String? academyId,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
    bool? isOptimistic,
  }) {
    return TechniqueEntity(
      id: id ?? this.id,
      academyId: academyId ?? this.academyId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  @override
  List<Object?> get props =>
      [id, academyId, name, slug, description, videoUrl, isOptimistic];
}
