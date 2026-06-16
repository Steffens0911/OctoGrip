import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/models/user.dart';

/// Desabilita fetch de fontes em rede — evita timeouts nos testes.
void disableGoogleFontsFetch() => GoogleFonts.config.allowRuntimeFetching = false;

/// Usuário-stub para testes (aluno comum, sem conta congelada).
UserModel stubStudent({
  String id = 'u-test',
  String role = 'aluno',
  String? graduation,
  bool accountFrozen = false,
  String? accountFreezeReason,
}) =>
    UserModel(
      id: id,
      email: '$id@test.com',
      role: role,
      graduation: graduation,
      accountFrozen: accountFrozen,
      accountFreezeReason: accountFreezeReason,
    );

/// Configura o singleton [AuthService] para um estado controlado.
/// Deve ser chamado em setUp() para isolar testes (o singleton persiste entre tests).
void setAuthForTesting({
  String? token = 'tok',
  UserModel? user,
  String? impersonatedUserId,
  UserModel? effectiveUser,
}) {
  AuthService().setForTesting(
    token: token,
    user: user ?? stubStudent(),
    impersonatedUserId: impersonatedUserId,
    effectiveUser: effectiveUser,
  );
}

/// Limpa o estado do singleton [AuthService] (usuário deslogado).
void clearAuthForTesting() {
  AuthService().setForTesting(token: null, user: null);
}

/// Envolve [child] em [MaterialApp] + [ChangeNotifierProvider<AuthService>]
/// com o singleton pré-configurado via [setAuthForTesting].
Widget wrapApp(Widget child) => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<AuthService>.value(
          value: AuthService(),
          child: child,
        ),
      ),
    );
