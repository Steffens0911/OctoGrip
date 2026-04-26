import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_active_students_screen.dart';
import 'package:viewer/screens/admin/academy_points_edit_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AcademyStudentsScreen extends StatelessWidget {
  const AcademyStudentsScreen({
    super.key,
    required this.academy,
  });

  final Academy academy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Alunos',
        subtitle: academy.name,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.people_rounded, color: AppTheme.primary),
              ),
              title: const Text(
                'Usuários da academia',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Cadastrar e gerenciar usuários da sua academia'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserListScreen()),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.edit_note, color: AppTheme.primary),
              ),
              title: const Text(
                'Editar pontos dos alunos',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ajustar pontuação manual dos alunos desta academia'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AcademyPointsEditScreen(
                    academyId: academy.id,
                    academyName: academy.name,
                  ),
                ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.insights_rounded, color: AppTheme.primary),
              ),
              title: const Text(
                'Alunos ativos (últimos 7 dias)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ver quem está usando o app recentemente nesta academia'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AcademyActiveStudentsScreen(academy: academy),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

