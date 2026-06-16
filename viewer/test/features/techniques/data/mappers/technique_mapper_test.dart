import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/data/mappers/technique_mapper.dart';
import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';

void main() {
  const dto = TechniqueDto(
    id: 'id1',
    academyId: 'ac1',
    name: 'Armlock',
    slug: 'armlock',
    description: 'Uma técnica de submissão',
    videoUrl: 'https://youtu.be/abc',
  );

  const entity = TechniqueEntity(
    id: 'id1',
    academyId: 'ac1',
    name: 'Armlock',
    slug: 'armlock',
    description: 'Uma técnica de submissão',
    videoUrl: 'https://youtu.be/abc',
  );

  group('TechniqueMapper.toEntity', () {
    test('mapeia todos os campos do DTO', () {
      final result = TechniqueMapper.toEntity(dto);
      expect(result.id, dto.id);
      expect(result.academyId, dto.academyId);
      expect(result.name, dto.name);
      expect(result.slug, dto.slug);
      expect(result.description, dto.description);
      expect(result.videoUrl, dto.videoUrl);
      expect(result.isOptimistic, isFalse);
    });

    test('isOptimistic=true quando especificado', () {
      final result = TechniqueMapper.toEntity(dto, isOptimistic: true);
      expect(result.isOptimistic, isTrue);
    });

    test('campos opcionais nulos são preservados', () {
      const minimal = TechniqueDto(
        id: 'id2',
        academyId: 'ac1',
        name: 'Triângulo',
        slug: 'triangulo',
      );
      final result = TechniqueMapper.toEntity(minimal);
      expect(result.description, isNull);
      expect(result.videoUrl, isNull);
    });
  });

  group('TechniqueMapper.fromEntity', () {
    test('mapeia todos os campos da entidade', () {
      final result = TechniqueMapper.fromEntity(entity);
      expect(result.id, entity.id);
      expect(result.academyId, entity.academyId);
      expect(result.name, entity.name);
      expect(result.slug, entity.slug);
      expect(result.description, entity.description);
      expect(result.videoUrl, entity.videoUrl);
    });

    test('round-trip toEntity→fromEntity preserva dados', () {
      final backToDto = TechniqueMapper.fromEntity(TechniqueMapper.toEntity(dto));
      expect(backToDto.id, dto.id);
      expect(backToDto.name, dto.name);
      expect(backToDto.videoUrl, dto.videoUrl);
    });
  });
}
