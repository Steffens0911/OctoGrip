import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/data/models/technique_dto.dart';

void main() {
  group('TechniqueDto.fromJson', () {
    test('parseia todos os campos', () {
      final dto = TechniqueDto.fromJson({
        'id': 'id1',
        'name': 'Armlock',
        'slug': 'armlock',
        'description': 'Uma técnica',
        'video_url': 'https://youtu.be/abc',
      }, academyId: 'ac1');

      expect(dto.id, 'id1');
      expect(dto.academyId, 'ac1');
      expect(dto.name, 'Armlock');
      expect(dto.slug, 'armlock');
      expect(dto.description, 'Uma técnica');
      expect(dto.videoUrl, 'https://youtu.be/abc');
    });

    test('campos opcionais ficam null quando ausentes', () {
      final dto = TechniqueDto.fromJson(
        {'id': 'id2', 'name': 'Guarda', 'slug': 'guarda'},
        academyId: 'ac1',
      );
      expect(dto.description, isNull);
      expect(dto.videoUrl, isNull);
    });

    test('video_url (snake_case) mapeia para videoUrl', () {
      final dto = TechniqueDto.fromJson(
        {'id': 'x', 'name': 'X', 'slug': 'x', 'video_url': 'https://url'},
        academyId: 'ac1',
      );
      expect(dto.videoUrl, 'https://url');
    });

    test('academyId vem do parâmetro, não do JSON', () {
      final dto = TechniqueDto.fromJson(
        {'id': 'id1', 'name': 'A', 'slug': 'a'},
        academyId: 'academia-123',
      );
      expect(dto.academyId, 'academia-123');
    });
  });

  group('TechniqueDto.toJson', () {
    test('serializa todos os campos com chaves snake_case', () {
      const dto = TechniqueDto(
        id: 'id1',
        academyId: 'ac1',
        name: 'Armlock',
        slug: 'armlock',
        description: 'Desc',
        videoUrl: 'https://url',
      );
      final json = dto.toJson();
      expect(json['id'], 'id1');
      expect(json['academy_id'], 'ac1');
      expect(json['name'], 'Armlock');
      expect(json['slug'], 'armlock');
      expect(json['description'], 'Desc');
      expect(json['video_url'], 'https://url');
    });

    test('campos nulos ficam null no JSON', () {
      const dto = TechniqueDto(id: 'id2', academyId: 'ac1', name: 'G', slug: 'g');
      final json = dto.toJson();
      expect(json['description'], isNull);
      expect(json['video_url'], isNull);
    });
  });

  group('TechniqueDto fromHiveMap / toHiveMap', () {
    test('round-trip preserva todos os campos', () {
      const dto = TechniqueDto(
        id: 'id1',
        academyId: 'ac1',
        name: 'Armlock',
        slug: 'armlock',
        description: 'Desc',
        videoUrl: 'https://url',
      );
      final restored = TechniqueDto.fromHiveMap(dto.toHiveMap());
      expect(restored.id, dto.id);
      expect(restored.academyId, dto.academyId);
      expect(restored.name, dto.name);
      expect(restored.slug, dto.slug);
      expect(restored.description, dto.description);
      expect(restored.videoUrl, dto.videoUrl);
    });

    test('campos nulos preservados no round-trip', () {
      const dto = TechniqueDto(id: 'id2', academyId: 'ac1', name: 'Guarda', slug: 'guarda');
      final restored = TechniqueDto.fromHiveMap(dto.toHiveMap());
      expect(restored.description, isNull);
      expect(restored.videoUrl, isNull);
    });
  });
}
