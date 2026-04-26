import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/config/feature_flags.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/academy/academy_push_notification_screen.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';
import 'package:viewer/screens/admin/marketplace_list_screen.dart';
import 'package:viewer/screens/admin/training_video_list_screen.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
import 'package:viewer/screens/academy/attendance_frequency_screen.dart';
import 'package:viewer/screens/academy/attendance_history_screen.dart';
import 'package:viewer/screens/academy/attendance_session_screen.dart';
import 'package:viewer/screens/academy/academy_training_field_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/role_guard.dart';
import 'package:viewer/screens/admin/academy_active_students_screen.dart';
import 'package:viewer/screens/admin/academy_points_edit_screen.dart';

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
  String? _selectedAcademyId;

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
        final currentAcademyId = AuthService().currentUser?.academyId;
        final nextSelected = _selectedAcademyId ??
            (currentAcademyId != null &&
                    currentAcademyId.isNotEmpty &&
                    list.any((a) => a.id == currentAcademyId)
                ? currentAcademyId
                : (list.length == 1 ? list.first.id : null));
        setState(() {
          _academies = list;
          _selectedAcademyId = nextSelected;
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
    if (!mounted) return;
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
      // Cards fixos: usuários + chamada + histórico + frequência + técnicas + vídeos + loja (+ push)
      count += kPushNotificationsEnabled ? 8 : 7;
    }
    return count;
  }

  Academy? get _selectedAcademy {
    final id = _selectedAcademyId;
    if (id == null || id.isEmpty) return null;
    for (final a in _academies) {
      if (a.id == id) return a;
    }
    return null;
  }

  Academy? get _resolvedTrainingAcademy {
    if (_academies.length == 1) return _academies.first;
    final currentAcademyId = AuthService().currentUser?.academyId;
    if (currentAcademyId != null && currentAcademyId.isNotEmpty) {
      for (final a in _academies) {
        if (a.id == currentAcademyId) return a;
      }
    }
    return _selectedAcademy;
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
            child: const Icon(Icons.qr_code_rounded, color: AppTheme.primary),
          ),
          title: const Text('Chamada (QR)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Iniciar chamada e ver presenças em tempo real'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceSessionScreen()),
          ),
        ),
      );
    } else if (isManagerOrProfessor && index == 2) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.history_rounded, color: AppTheme.primary),
          ),
          title: const Text(
            'Histórico de chamadas',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Ver sessões, corrigir presenças (adicionar ou remover)',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
          ),
        ),
      );
    } else if (isManagerOrProfessor && index == 3) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.insights_rounded, color: AppTheme.primary),
          ),
          title: const Text(
            'Frequência',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Minhas sessões no período e frequência dos alunos da academia',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceFrequencyScreen()),
          ),
        ),
      );
    } else if (isManagerOrProfessor && index == 4) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.alt_route_rounded, color: AppTheme.primary),
          ),
          title: const Text(
            'Técnicas (para serem vinculadas aos troféus e posições da semana)',
            style: TextStyle(fontWeight: FontWeight.w600),
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
    } else if (isManagerOrProfessor && index == 5) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.ondemand_video_rounded,
                color: AppTheme.primary),
          ),
          title: const Text(
            'Vídeo da tarefa diária',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Cadastrar vídeos da tarefa diária da sua academia',
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
    } else if (isManagerOrProfessor && index == 6) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.storefront_rounded, color: AppTheme.primary),
          ),
          title: const Text(
            'Loja / anúncios',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Produtos da academia com preço e WhatsApp',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final academyId = AuthService().currentUser?.academyId;
            if (academyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Seu usuário não está vinculado a uma academia.',
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MarketplaceListScreen(
                  localOnly: true,
                ),
              ),
            );
          },
        ),
      );
    } else if (isManagerOrProfessor &&
        kPushNotificationsEnabled &&
        index == 7) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.notifications_active_rounded,
                color: AppTheme.primary),
          ),
          title: const Text(
            'Aviso à academia (push)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Enviar notificação para quem tem o app e está na sua academia',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final academyId = AuthService().currentUser?.academyId;
            if (academyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Seu usuário não está vinculado a uma academia.',
                  ),
                ),
              );
              return;
            }
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const AcademyPushNotificationScreen(),
              ),
            );
          },
        ),
      );
    }

    // Cards fixos no topo; academias após Usuários + chamada + histórico + frequência + técnicas + vídeos + Loja (+ push).
    final managerOffset =
        isManagerOrProfessor ? (kPushNotificationsEnabled ? 8 : 7) : 0;
    final academyIndex = isManagerOrProfessor ? index - managerOffset : index;
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
    final resolvedTrainingAcademy = _resolvedTrainingAcademy;
    return RoleGuard(
      allowedRoles: const [
        'administrador',
        'gerente_academia',
        'professor',
        'supervisor'
      ],
      allowWhenRealUserIsAdmin: true,
      allowWhenRealUserIsSupervisor: true,
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
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.emoji_events_rounded, color: AppTheme.primary),
                                ),
                                title: const Text(
                                  'Campo de treinamento',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  resolvedTrainingAcademy != null
                                      ? 'Posições e técnicas + troféus e missões semanais'
                                      : 'Selecione uma academia para liberar este atalho',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: resolvedTrainingAcademy != null,
                                onTap: resolvedTrainingAcademy == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AcademyTrainingFieldScreen(
                                              academy: resolvedTrainingAcademy,
                                            ),
                                          ),
                                        ),
                              ),
                            ),

                            // Cards “Editar pontos” e “Alunos ativos” ficam apenas na página inicial do Gestão.
                            if (AuthService().isAdmin() || AuthService().isManager() || AuthService().isSupervisor()) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedAcademyId,
                                decoration: const InputDecoration(
                                  labelText: 'Academia',
                                  border: OutlineInputBorder(),
                                ),
                                items: _academies
                                    .map(
                                      (a) => DropdownMenuItem<String>(
                                        value: a.id,
                                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedAcademyId = v),
                              ),
                              const SizedBox(height: 12),
                              if (_selectedAcademy != null) ...[
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
                                    subtitle: const Text(
                                      'Ajustar pontuação manual dos alunos desta academia',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AcademyPointsEditScreen(
                                          academyId: _selectedAcademy!.id,
                                          academyName: _selectedAcademy!.name,
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
                                    subtitle: const Text(
                                      'Ver quem está usando o app recentemente nesta academia',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AcademyActiveStudentsScreen(
                                          academy: _selectedAcademy!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],

                            // Lista existente (cards fixos + academias).
                            ...List.generate(_getItemCount(), (index) => _buildListItem(context, index)),
                          ],
                        ),
                      ),
      ),
    );
  }
}
