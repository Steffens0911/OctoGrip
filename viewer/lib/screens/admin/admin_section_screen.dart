import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/admin/academy_list_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/screens/admin/lesson_list_screen.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';
import 'package:viewer/screens/admin/position_list_screen.dart';
import 'package:viewer/screens/admin/mission_list_screen.dart';

/// Tela principal da seção Administração: menu com os CRUDs.
class AdminSectionScreen extends StatelessWidget {
  const AdminSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text(
            'Escolha o que administrar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            icon: Icons.school,
            title: 'Academias',
            subtitle: 'Criar, editar e excluir academias',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AcademyListScreen(),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.people,
            title: 'Usuários',
            subtitle: 'Gerenciar usuários',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserListScreen(),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.menu_book,
            title: 'Lições',
            subtitle: 'Conteúdo das aulas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LessonListScreen(),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.sports_martial_arts,
            title: 'Técnicas',
            subtitle: 'Técnicas (de/para posição)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TechniqueListScreen(),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.accessibility_new,
            title: 'Posições',
            subtitle: 'Posições do jiu-jitsu',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PositionListScreen(),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.flag,
            title: 'Missões',
            subtitle: 'Missões (período, lição, nível)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MissionListScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
