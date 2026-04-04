import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/admin/academy_list_screen.dart';
import 'package:viewer/screens/admin/engagement_reports_screen.dart';
import 'package:viewer/screens/admin/execution_reports_screen.dart';
import 'package:viewer/screens/admin/audit_recovery_screen.dart';
import 'package:viewer/screens/admin/database_backup_screen.dart';
import 'package:viewer/screens/admin/training_video_list_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/role_guard.dart';

/// Tela principal da seção Administração — estilo Lovable.
class AdminSectionScreen extends StatelessWidget {
  const AdminSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.screenPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Admin',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apenas administradores globais. Gerencie academias e usuários',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 32),
          AppNavigationTile(
            icon: Icons.school_rounded,
            title: 'Academias',
            subtitle: 'Criar, editar e gerenciar academias',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AcademyListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.ondemand_video_rounded,
            title: 'Vídeos de treinamento',
            subtitle: 'Cadastrar vídeos do YouTube com pontos diários',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrainingVideoListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.people_rounded,
            title: 'Usuários',
            subtitle: 'Gerenciar usuários e suas faixas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.bar_chart_rounded,
            title: 'Relatórios de execuções',
            subtitle: 'Premeditadas vs naturais por academia',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExecutionReportsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.insights_rounded,
            title: 'Relatórios de engajamento',
            subtitle: 'Semana e mês · % de alunos ativos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EngagementReportsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.history_rounded,
            title: 'Auditoria e recuperação',
            subtitle: 'Histórico de alterações, reativar e restaurar versões',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AuditRecoveryScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppNavigationTile(
            icon: Icons.backup_rounded,
            title: 'Backup do banco de dados',
            subtitle: 'Baixar dump SQL completo (PostgreSQL)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DatabaseBackupScreen(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
