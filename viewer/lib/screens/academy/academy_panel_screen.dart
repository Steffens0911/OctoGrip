import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';
import 'package:viewer/screens/admin/training_video_list_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/role_guard.dart';

/// Painel da academia: lista academias; ao tocar abre o detalhe (tema, ranking, dificuldades, relatório).
class AcademyPanelScreen extends StatefulWidget {
  const AcademyPanelScreen({super.key});

  @override
  State<AcademyPanelScreen> createState() => _AcademyPanelScreenState();
}

class _AcademyPanelScreenState extends State<AcademyPanelScreen> {
  final ApiService _api = ApiService();
  List<Academy> _academies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getAcademies();
      if (mounted) {
        setState(() {
          _academies = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e
              .toString()
              .replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
        });
      }
    }
  }

  Future<void> _openAcademy(Academy academy) async {
    Academy effective = academy;
    try {
      effective = await _api.getAcademyFresh(academy.id);
    } catch (_) {
      // Em caso de erro de rede, cai para os dados em cache.
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyDetailScreen(
          academy: effective,
          onUpdated: _load,
          onDeleted: () {
            Navigator.pop(context);
            _load();
          },
        ),
      ),
    );
    _load();
  }

  int _getItemCount() {
    int count = _academies.length;
    if (AuthService().isManager() || AuthService().isProfessor()) {
      count += 3; // Cards extras: Usuários da academia + Técnicas da academia + Vídeos de treinamento
    }
    return count;
  }

  Widget _buildListItem(BuildContext context, int index) {
    final isManagerOrProfessor =
        AuthService().isManager() || AuthService().isProfessor();

    if (isManagerOrProfessor && index == 0) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.people_rounded, color: AppTheme.primary),
          ),
          title: const Text('Usuários da academia',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              const Text('Cadastrar e gerenciar usuários da sua academia'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserListScreen()),
          ),
        ),
      );
    } else if (isManagerOrProfessor && index == 1) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.alt_route_rounded, color: AppTheme.primary),
          ),
          title: const Text(
            'Técnicas da academia',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Cadastrar e gerenciar técnicas da sua academia',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final academyId = AuthService().currentUser?.academyId;
            if (academyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Seu usuário não está vinculado a uma academia. Peça ao administrador para vincular seu perfil.',
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TechniqueListScreen(
                  academyId: academyId,
                ),
              ),
            );
          },
        ),
      );
    } else if (isManagerOrProfessor && index == 2) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.ondemand_video_rounded,
                color: AppTheme.primary),
          ),
          title: const Text(
            'Vídeos de treinamento',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Cadastrar vídeos de campo de treinamento da sua academia',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TrainingVideoListScreen(
                localOnly: true,
              ),
            ),
          ),
        ),
      );
    }

    final academyIndex = isManagerOrProfessor ? index - 2 : index;
    if (academyIndex < 0 || academyIndex >= _academies.length) {
      return const SizedBox.shrink();
    }
    final academy = _academies[academyIndex];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: const Icon(Icons.school, color: AppTheme.primary),
        ),
        title: Text(
          academy.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        // Subtitle "Missão do dia" removido conforme solicitado.
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAcademy(academy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [
        'administrador',
        'gerente_academia',
        'professor',
        'supervisor'
      ],
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _academies.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AuthService().isAdmin()
                                ? 'Nenhuma academia cadastrada. Cadastre em Administração → Academias.'
                                : 'Nenhuma academia vinculada ao seu usuário. Peça ao administrador para vincular sua conta a uma academia.',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getItemCount(),
                          itemBuilder: (context, index) {
                            return _buildListItem(context, index);
                          },
                        ),
                      ),
      ),
    );
  }
}
