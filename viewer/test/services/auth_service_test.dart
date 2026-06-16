import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/pump_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().setForTesting(token: null, user: null);
  });

  // -------------------------------------------------------------------------
  // Estado inicial e isLoggedIn
  // -------------------------------------------------------------------------
  group('AuthService — estado inicial', () {
    test('não está logado sem token', () {
      expect(AuthService().isLoggedIn, isFalse);
    });

    test('está logado com token não-vazio', () {
      AuthService().setForTesting(token: 'tok', user: stubStudent());
      expect(AuthService().isLoggedIn, isTrue);
    });

    test('currentUser retorna o usuário injetado', () {
      final user = stubStudent(id: 'u42', role: 'aluno');
      AuthService().setForTesting(token: 'tok', user: user);
      expect(AuthService().currentUser?.id, 'u42');
    });
  });

  // -------------------------------------------------------------------------
  // Role helpers
  // -------------------------------------------------------------------------
  group('AuthService — role helpers (usuário real)', () {
    test('isRealUserAdmin true para role administrador', () {
      AuthService().setForTesting(
        token: 'tok',
        user: stubStudent(role: 'administrador'),
      );
      expect(AuthService().isRealUserAdmin, isTrue);
    });

    test('isRealUserAdmin false para aluno', () {
      AuthService().setForTesting(token: 'tok', user: stubStudent(role: 'aluno'));
      expect(AuthService().isRealUserAdmin, isFalse);
    });

    test('isRealUserSupervisor true para role supervisor', () {
      AuthService().setForTesting(
        token: 'tok',
        user: stubStudent(role: 'supervisor'),
      );
      expect(AuthService().isRealUserSupervisor, isTrue);
    });

    test('isAdmin() verifica o usuário efetivo (impersonação)', () {
      AuthService().setForTesting(
        token: 'tok',
        user: stubStudent(role: 'administrador'),
        effectiveUser: stubStudent(role: 'aluno'), // "Atuar como" aluno
      );
      // currentUser retorna effectiveUser quando impersonando.
      expect(AuthService().isAdmin(), isFalse);
      // Mas isRealUserAdmin olha _currentUser (real).
      expect(AuthService().isRealUserAdmin, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Impersonação
  // -------------------------------------------------------------------------
  group('AuthService — isImpersonating', () {
    test('false sem userId', () {
      AuthService().setForTesting(token: 'tok', user: stubStudent());
      expect(AuthService().isImpersonating, isFalse);
    });

    test('true com impersonatedUserId', () {
      AuthService().setForTesting(
        token: 'tok',
        user: stubStudent(role: 'administrador'),
        impersonatedUserId: 'outro-user',
      );
      expect(AuthService().isImpersonating, isTrue);
      expect(AuthService().impersonatedUserId, 'outro-user');
    });
  });

  // -------------------------------------------------------------------------
  // authHeader
  // -------------------------------------------------------------------------
  group('AuthService.authHeader', () {
    test('retorna "Bearer <token>" quando logado', () {
      AuthService().setForTesting(token: 'abc123', user: stubStudent());
      expect(AuthService().authHeader, 'Bearer abc123');
    });

    test('retorna null quando não logado', () {
      AuthService().setForTesting(token: null, user: null);
      expect(AuthService().authHeader, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Persistência via SharedPreferences (init / setLoggedIn)
  // -------------------------------------------------------------------------
  group('AuthService.init — lê token do storage', () {
    test('carrega token e usuário do storage após init()', () async {
      final user = UserModel(id: 'u1', email: 'a@b.com', role: 'aluno');
      SharedPreferences.setMockInitialValues({
        'auth_token': 'stored-tok',
        'auth_user': jsonEncode(user.toJson()),
      });
      AuthService().setForTesting(token: null, user: null); // limpa estado

      await AuthService().init();

      expect(AuthService().isLoggedIn, isTrue);
      expect(AuthService().token, 'stored-tok');
      expect(AuthService().currentUser?.email, 'a@b.com');
    });

    test('fica deslogado quando storage está vazio', () async {
      SharedPreferences.setMockInitialValues({});
      AuthService().setForTesting(token: null, user: null);

      await AuthService().init();

      expect(AuthService().isLoggedIn, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Sinalizadores UI (loginNoticeShown, randomPartnerShown)
  // -------------------------------------------------------------------------
  group('AuthService — sinalizadores UI', () {
    test('randomPartnerShown começa false, vai a true após markRandomPartnerShown()', () {
      AuthService().setForTesting(token: 'tok', user: stubStudent());
      expect(AuthService().randomPartnerShown, isFalse);
      AuthService().markRandomPartnerShown();
      expect(AuthService().randomPartnerShown, isTrue);
    });

    test('loginNoticeShown começa false, vai a true após markLoginNoticeShown()', () {
      AuthService().setForTesting(token: 'tok', user: stubStudent());
      expect(AuthService().loginNoticeShown, isFalse);
      AuthService().markLoginNoticeShown();
      expect(AuthService().loginNoticeShown, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // notifyListeners ao setForTesting
  // -------------------------------------------------------------------------
  group('AuthService.setForTesting — notifica listeners', () {
    test('listeners são notificados quando o estado muda', () {
      int notifyCount = 0;
      void listener() => notifyCount++;

      AuthService().addListener(listener);
      AuthService().setForTesting(token: 'tok', user: stubStudent());
      AuthService().removeListener(listener);

      expect(notifyCount, 1);
    });
  });
}
