import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
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
      if (mounted) setState(() {
        _academies = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
      });
    }
  }

  Future<void> _openAcademy(Academy academy) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyDetailScreen(
          academy: academy,
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

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: ['administrador', 'gerente_academia', 'professor', 'supervisor'],
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
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (AuthService().isManager() || AuthService().isProfessor())
                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.people_rounded, color: AppTheme.primary),
                                ),
                                title: const Text('Usuários da academia', style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Cadastrar e gerenciar usuários da sua academia'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserListScreen()),
                                ),
                              ),
                            ),
                          ...List.generate(_academies.length, (i) {
                            final a = _academies[i];
                            return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.school, color: AppTheme.primary),
                              ),
                              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: (a.weeklyTechniqueName != null && a.weeklyTechniqueName!.isNotEmpty) ||
                                      (a.weeklyTheme != null && a.weeklyTheme!.isNotEmpty)
                                  ? Text(
                                      'Missão do dia: ${a.weeklyTechniqueName ?? a.weeklyTheme}',
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openAcademy(a),
                            ),
                          );
                          }),
                        ],
                      ),
                    ),
      ),
    );
  }
}
