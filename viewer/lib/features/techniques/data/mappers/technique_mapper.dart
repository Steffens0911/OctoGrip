import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';

/// Mapeamento explícito DTO ↔ Entity (evita vazar detalhes de API no domínio).
class TechniqueMapper {
  const TechniqueMapper._();

  static TechniqueEntity toEntity(TechniqueDto dto, {bool isOptimistic = false}) {
    return TechniqueEntity(
      id: dto.id,
      academyId: dto.academyId,
      name: dto.name,
      slug: dto.slug,
      description: dto.description,
      videoUrl: dto.videoUrl,
      isOptimistic: isOptimistic,
    );
  }

  static TechniqueDto fromEntity(TechniqueEntity e) {
    return TechniqueDto(
      id: e.id,
      academyId: e.academyId,
      name: e.name,
      slug: e.slug,
      description: e.description,
      videoUrl: e.videoUrl,
    );
  }
}
