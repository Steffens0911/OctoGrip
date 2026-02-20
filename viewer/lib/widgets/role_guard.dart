import 'package:flutter/material.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/access_denied_screen.dart';

/// Widget que protege conteúdo baseado em roles permitidos.
/// Se o usuário não tiver o role necessário, mostra fallback ou AccessDeniedScreen.
class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final userRole = auth.currentUser?.role ?? 'aluno';

    if (!allowedRoles.contains(userRole)) {
      return fallback ?? const AccessDeniedScreen();
    }

    return child;
  }
}
