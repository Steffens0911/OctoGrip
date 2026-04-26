import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/config/feature_flags.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/academy/academy_push_notification_screen.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/screens/academy/academy_training_field_screen.dart';
import 'package:viewer/screens/academy/academy_students_screen.dart';
import 'package:viewer/screens/academy/academy_attendance_hub_screen.dart';
import 'package:viewer/screens/academy/academy_customization_business_screen.dart';
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
      // Cards fixos: push
      count += kPushNotificationsEnabled ? 1 : 0;
    }
    return count;
  }

  Academy? get _resolvedAcademy {
    if (_academies.length == 1) return _academies.first;
    final currentAcademyId = AuthService().currentUser?.academyId;
    if (currentAcademyId != null && currentAcademyId.isNotEmpty) {
      for (final a in _academies) {
        if (a.id == currentAcademyId) return a;
      }
    }
    return null;
  }

  Widget _buildListItem(BuildContext context, int index) {
    final isManagerOrProfessor =
        AuthService().isManager() || AuthService().isProfessor();

    if (isManagerOrProfessor &&
        kPushNotificationsEnabled &&
        index == 0) {
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
        isManagerOrProfessor ? (kPushNotificationsEnabled ? 1 : 0) : 0;
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
        title: const Text(
          'Relatórios',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        // Subtitle "Missão do dia" removido conforme solicitado.
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAcademy(academy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAcademy = _resolvedAcademy;
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
                                  resolvedAcademy != null
                                      ? 'Posições e técnicas + troféus e missões semanais'
                                      : 'Seu usuário não está vinculado a uma academia',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: resolvedAcademy != null,
                                onTap: resolvedAcademy == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AcademyTrainingFieldScreen(
                                              academy: resolvedAcademy,
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
                                  child: const Icon(Icons.palette_rounded, color: AppTheme.primary),
                                ),
                                title: const Text(
                                  'Personalização e Negócios',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  resolvedAcademy != null
                                      ? 'Logo, quadro de horários, parceiros, avisos e visibilidade'
                                      : 'Seu usuário não está vinculado a uma academia',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: resolvedAcademy != null,
                                onTap: resolvedAcademy == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AcademyCustomizationBusinessScreen(academy: resolvedAcademy),
                                          ),
                                        ),
                              ),
                            ),

                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.qr_code_rounded, color: AppTheme.primary),
                                ),
                                title: const Text(
                                  'Chamada e frequência',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Chamada (QR), histórico e frequência',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AcademyAttendanceHubScreen(),
                                  ),
                                ),
                              ),
                            ),

                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.school_rounded, color: AppTheme.primary),
                                ),
                                title: const Text(
                                  'Alunos',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  resolvedAcademy != null
                                      ? 'Usuários, pontos e alunos ativos'
                                      : 'Seu usuário não está vinculado a uma academia',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: resolvedAcademy != null,
                                onTap: resolvedAcademy == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AcademyStudentsScreen(academy: resolvedAcademy),
                                          ),
                                        ),
                              ),
                            ),

                            // Lista existente (cards fixos + academias).
                            ...List.generate(_getItemCount(), (index) => _buildListItem(context, index)),
                          ],
                        ),
                      ),
      ),
    );
  }
}
