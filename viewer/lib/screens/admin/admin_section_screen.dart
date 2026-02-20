import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/admin/academy_list_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/widgets/role_guard.dart';

/// Tela principal da seção Administração — estilo Lovable.
class AdminSectionScreen extends StatelessWidget {
  const AdminSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: ['administrador'],
      child: SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.screenPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Administração',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gerencie academias e usuários',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 32),
          _AdminTile(
            icon: Icons.school_rounded,
            title: 'Academias',
            subtitle: 'Criar, editar e gerenciar academias',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AcademyListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            icon: Icons.people_rounded,
            title: 'Usuários',
            subtitle: 'Gerenciar usuários e suas faixas',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserListScreen(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryOf(context),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.textMutedOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
