import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/technique.dart';

void main() {
  group('Technique', () {
    test('fromJson mapeia campos e aceita opcionais nulos', () {
      final t = Technique.fromJson({
        'id': 't1',
        'name': 'Armlock',
        'slug': 'armlock',
        'description': null,
        'video_url': null,
      });
      expect(t.id, 't1');
      expect(t.name, 'Armlock');
      expect(t.slug, 'armlock');
      expect(t.description, isNull);
      expect(t.videoUrl, isNull);
    });

    test('round-trip toJson/fromJson preserva os dados', () {
      final original = Technique(
        id: 't1',
        name: 'Triângulo',
        slug: 'triangulo',
        description: 'Estrangulamento com as pernas',
        videoUrl: 'https://youtu.be/abcdefghijk',
      );

      final back = Technique.fromJson(original.toJson());

      expect(back.id, original.id);
      expect(back.name, original.name);
      expect(back.slug, original.slug);
      expect(back.description, original.description);
      expect(back.videoUrl, original.videoUrl);
    });

    test('toJson usa a chave snake_case video_url', () {
      final json = Technique(id: 't', name: 'n', slug: 's', videoUrl: 'u').toJson();
      expect(json.containsKey('video_url'), isTrue);
      expect(json['video_url'], 'u');
    });
  });
}
