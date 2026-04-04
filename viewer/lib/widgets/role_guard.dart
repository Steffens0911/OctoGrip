import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viewer/screens/access_denied_screen.dart';
import 'package:viewer/services/auth_service.dart';

/// Protege conteúdo por roles do utilizador **efetivo** ([AuthService.currentUser]).
///
/// Com [allowWhenRealUserIsAdmin] / [allowWhenRealUserIsSupervisor]: durante **Atuar como**,
/// o papel efetivo muda mas o JWT continua a ser o da conta real; estes ecrãs podem usar
/// [AuthService.isRealUserAdmin] / [isRealUserSupervisor] (perfil reidratado sem `X-Impersonate-User`).
/// **Não** usar [allowWhenRealUserIsAdmin] na secção **Admin**: o acesso global deve seguir só o papel efetivo.
class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.allowWhenRealUserIsAdmin = false,
    this.allowWhenRealUserIsSupervisor = false,
  });

  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  /// Se true, administrador real passa mesmo com role efetivo de aluno/gestor (impersonação).
  final bool allowWhenRealUserIsAdmin;

  /// Se true, supervisor real passa na simulação (mesma lógica que admin).
  final bool allowWhenRealUserIsSupervisor;

  static String _norm(String? r) => (r ?? '').trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final raw = auth.currentUser?.role;
    final normalized = _norm(raw);
    final effectiveRole = normalized.isEmpty ? 'aluno' : normalized;

    if (allowWhenRealUserIsAdmin && auth.isRealUserAdmin) {
      return child;
    }
    if (allowWhenRealUserIsSupervisor && auth.isRealUserSupervisor) {
      return child;
    }

    final allowed = allowedRoles.map((r) => _norm(r)).toList();
    if (!allowed.contains(effectiveRole)) {
      return fallback ?? const AccessDeniedScreen();
    }

    return child;
  }
}
