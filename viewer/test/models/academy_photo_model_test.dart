import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/academy_photo.dart';

Map<String, dynamic> _authorJson({String id = 'u1'}) => {
      'id': id,
      'name': 'João Silva',
      'avatar_url': 'https://example.com/avatar.png',
    };

Map<String, dynamic> _photoJson({String id = 'p1', String status = 'ready'}) => {
      'id': id,
      'academy_id': 'ac1',
      'author': _authorJson(),
      'image_url': 'https://example.com/photo.jpg',
      'thumbnail_url': 'https://example.com/thumb.jpg',
      'caption': 'Treino de hoje',
      'status': status,
      'likes_count': 3,
      'comments_count': 1,
      'liked_by_me': false,
      'is_system_post': false,
      'created_at': '2024-06-01T10:00:00Z',
    };

void main() {
  group('PhotoAuthor.fromJson', () {
    test('desserializa todos os campos', () {
      final a = PhotoAuthor.fromJson(_authorJson());

      expect(a.id, 'u1');
      expect(a.name, 'João Silva');
      expect(a.avatarUrl, 'https://example.com/avatar.png');
    });

    test('aceita campos opcionais nulos', () {
      final a = PhotoAuthor.fromJson({'id': 'u2'});

      expect(a.id, 'u2');
      expect(a.name, isNull);
      expect(a.avatarUrl, isNull);
    });
  });

  group('AcademyPhoto.fromJson', () {
    test('desserializa todos os campos', () {
      final p = AcademyPhoto.fromJson(_photoJson());

      expect(p.id, 'p1');
      expect(p.academyId, 'ac1');
      expect(p.author.id, 'u1');
      expect(p.status, 'ready');
      expect(p.likesCount, 3);
      expect(p.likedByMe, isFalse);
      expect(p.isSystemPost, isFalse);
    });

    test('isReady retorna true quando status é "ready"', () {
      final p = AcademyPhoto.fromJson(_photoJson(status: 'ready'));
      expect(p.isReady, isTrue);
    });

    test('isReady retorna false quando status não é "ready"', () {
      final p = AcademyPhoto.fromJson(_photoJson(status: 'processing'));
      expect(p.isReady, isFalse);
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final p = AcademyPhoto.fromJson({
        'id': 'p2',
        'academy_id': 'ac1',
        'author': _authorJson(),
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(p.status, 'processing');
      expect(p.likesCount, 0);
      expect(p.likedByMe, isFalse);
      expect(p.isSystemPost, isFalse);
    });
  });

  group('AcademyPhoto.copyWith', () {
    test('copia com likesCount alterado', () {
      final original = AcademyPhoto.fromJson(_photoJson());
      final copy = original.copyWith(likesCount: 10, likedByMe: true);

      expect(copy.likesCount, 10);
      expect(copy.likedByMe, isTrue);
      expect(copy.id, original.id);
    });
  });

  group('PhotoFeedPage.fromJson', () {
    test('desserializa página vazia', () {
      final page = PhotoFeedPage.fromJson({'items': [], 'next_cursor': null});

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('desserializa página com itens', () {
      final page = PhotoFeedPage.fromJson({
        'items': [_photoJson(id: 'p1'), _photoJson(id: 'p2')],
        'next_cursor': 'cursor-abc',
      });

      expect(page.items.length, 2);
      expect(page.nextCursor, 'cursor-abc');
    });
  });

  group('PhotoComment.fromJson', () {
    test('desserializa todos os campos', () {
      final c = PhotoComment.fromJson({
        'id': 'c1',
        'photo_id': 'p1',
        'author': _authorJson(),
        'body': 'Ótimo treino!',
        'created_at': '2024-06-01T11:00:00Z',
      });

      expect(c.id, 'c1');
      expect(c.photoId, 'p1');
      expect(c.body, 'Ótimo treino!');
      expect(c.author.id, 'u1');
    });
  });

  group('PhotoRestriction.fromJson', () {
    test('desserializa todos os campos', () {
      final r = PhotoRestriction.fromJson({
        'id': 'r1',
        'academy_id': 'ac1',
        'user_id': 'u1',
        'user_name': 'Pedro',
        'reason': 'Conteúdo inadequado',
        'expires_at': '2024-12-31T00:00:00Z',
        'active': true,
        'created_at': '2024-06-01T00:00:00Z',
      });

      expect(r.id, 'r1');
      expect(r.userName, 'Pedro');
      expect(r.active, isTrue);
      expect(r.expiresAt, isNotNull);
    });

    test('aceita expiresAt nulo', () {
      final r = PhotoRestriction.fromJson({
        'id': 'r2',
        'academy_id': 'ac1',
        'user_id': 'u2',
        'active': false,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(r.expiresAt, isNull);
      expect(r.active, isFalse);
    });
  });
}
