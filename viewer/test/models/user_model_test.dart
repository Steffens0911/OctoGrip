import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/user.dart';

void main() {
  group('UserModel.fromJson', () {
    test('mapeia todos os campos do payload completo da API', () {
      final json = {
        'id': 'u1',
        'email': 'aluno@octogrip.com.br',
        'name': 'Fulano de Tal',
        'graduation': 'blue',
        'role': 'aluno',
        'academy_id': 'acad-1',
        'points_adjustment': 15,
        'avatar_url': 'https://cdn/avatar.png',
        'facial_photo_url': 'https://cdn/face.png',
        'gallery_visible': false,
        'login_streak_days': 7,
        'account_frozen': true,
        'account_freeze_reason': 'Mensalidade em atraso',
      };

      final u = UserModel.fromJson(json);

      expect(u.id, 'u1');
      expect(u.email, 'aluno@octogrip.com.br');
      expect(u.name, 'Fulano de Tal');
      expect(u.graduation, 'blue');
      expect(u.role, 'aluno');
      expect(u.academyId, 'acad-1');
      expect(u.pointsAdjustment, 15);
      expect(u.avatarUrl, 'https://cdn/avatar.png');
      expect(u.facialPhotoUrl, 'https://cdn/face.png');
      expect(u.galleryVisible, isFalse);
      expect(u.loginStreakDays, 7);
      expect(u.accountFrozen, isTrue);
      expect(u.accountFreezeReason, 'Mensalidade em atraso');
    });

    test('aplica defaults quando campos opcionais ausentes', () {
      final u = UserModel.fromJson({
        'id': 'u2',
        'email': 'x@y.com',
      });

      expect(u.name, isNull);
      expect(u.role, 'aluno'); // default
      expect(u.pointsAdjustment, 0);
      expect(u.galleryVisible, isTrue); // default true
      expect(u.loginStreakDays, 0);
      expect(u.accountFrozen, isFalse);
      expect(u.accountFreezeReason, isNull);
    });

    test('role nulo cai no default "aluno"', () {
      final u = UserModel.fromJson({'id': 'u3', 'email': 'a@b.com', 'role': null});
      expect(u.role, 'aluno');
    });
  });

  group('UserModel round-trip', () {
    test('toJson preserva os campos e usa as chaves snake_case da API', () {
      final u = UserModel(
        id: 'u1',
        email: 'a@b.com',
        name: 'Nome',
        role: 'professor',
        academyId: 'acad',
        pointsAdjustment: 3,
        galleryVisible: false,
        loginStreakDays: 4,
        accountFrozen: true,
        accountFreezeReason: 'motivo',
      );

      final json = u.toJson();
      expect(json['academy_id'], 'acad');
      expect(json['points_adjustment'], 3);
      expect(json['gallery_visible'], isFalse);
      expect(json['login_streak_days'], 4);
      expect(json['account_frozen'], isTrue);
      expect(json['account_freeze_reason'], 'motivo');

      final back = UserModel.fromJson(json);
      expect(back.role, u.role);
      expect(back.accountFrozen, u.accountFrozen);
      expect(back.loginStreakDays, u.loginStreakDays);
    });
  });
}
