import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/role_guard.dart';

import '../helpers/pump_app.dart';

Widget _wrap(Widget child, {UserModel? user, UserModel? effectiveUser}) =>
    MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<AuthService>.value(
          value: AuthService()
            ..setForTesting(
              token: 'tok',
              user: user,
              effectiveUser: effectiveUser,
            ),
          child: child,
        ),
      ),
    );

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('RoleGuard — papel efetivo', () {
    testWidgets('exibe child quando role está na lista permitida', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleGuard(allowedRoles: ['aluno'], child: Text('ok')),
        user: stubStudent(role: 'aluno'),
      ));
      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('exibe fallback quando role não está na lista', (tester) async {
      await tester.pumpWidget(_wrap(
        RoleGuard(
          allowedRoles: const ['professor'],
          child: const Text('protegido'),
          fallback: const Text('acesso negado'),
        ),
        user: stubStudent(role: 'aluno'),
      ));
      expect(find.text('acesso negado'), findsOneWidget);
      expect(find.text('protegido'), findsNothing);
    });

    testWidgets('normaliza role para lowercase antes de comparar', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleGuard(allowedRoles: ['professor'], child: Text('ok')),
        user: stubStudent(role: 'Professor'), // maiúscula
      ));
      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('role nulo trata como aluno', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleGuard(allowedRoles: ['aluno'], child: Text('ok')),
        user: null, // currentUser nulo → role '' → default 'aluno'
      ));
      expect(find.text('ok'), findsOneWidget);
    });
  });

  group('RoleGuard — allowWhenRealUserIsAdmin', () {
    testWidgets('admin real passa mesmo com role efetivo de aluno (impersonação)', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleGuard(
          allowedRoles: ['professor'],
          allowWhenRealUserIsAdmin: true,
          child: Text('admin ok'),
        ),
        user: stubStudent(role: 'administrador'),
        effectiveUser: stubStudent(role: 'aluno'), // impersonado
      ));
      // O currentUser efetivo é aluno, mas allowWhenRealUserIsAdmin verifica _currentUser
      // (real = administrador) → deve passar.
      expect(find.text('admin ok'), findsOneWidget);
    });

    testWidgets('aluno comum não passa com allowWhenRealUserIsAdmin=true', (tester) async {
      await tester.pumpWidget(_wrap(
        RoleGuard(
          allowedRoles: const ['professor'],
          allowWhenRealUserIsAdmin: true,
          child: const Text('ok'),
          fallback: const Text('negado'),
        ),
        user: stubStudent(role: 'aluno'),
      ));
      expect(find.text('negado'), findsOneWidget);
    });
  });

  group('RoleGuard — allowWhenRealUserIsSupervisor', () {
    testWidgets('supervisor real passa na simulação', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleGuard(
          allowedRoles: ['professor'],
          allowWhenRealUserIsSupervisor: true,
          child: Text('supervisor ok'),
        ),
        user: stubStudent(role: 'supervisor'),
        effectiveUser: stubStudent(role: 'aluno'),
      ));
      expect(find.text('supervisor ok'), findsOneWidget);
    });
  });
}
