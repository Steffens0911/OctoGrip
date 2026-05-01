import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/config/feature_flags.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/academy/academy_push_notification_screen.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/screens/academy/academy_training_field_screen.dart';
import 'package:viewer/screens/academy/academy_students_screen.dart';
import 'package:viewer/screens/academy/academy_attendance_hub_screen.dart';
import 'package:viewer/screens/academy/academy_customization_business_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/layout/memo_compact_tile_card.dart';
import 'package:viewer/widgets/layout/memo_section_label.dart';
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

  bool get _showPushItem =>
      (AuthService().isManager() || AuthService().isProfessor()) &&
      kPushNotificationsEnabled;

  Widget _academyNavigationTile({
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final tile = AppNavigationTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
    if (enabled) return tile;
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(child: tile),
    );
  }

  void _openPushScreen() {
    final academyId = AuthService().currentUser?.academyId;
    if (academyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seu usuário não está vinculado a uma academia.'),
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.m),
                          children: [
                            const MemoSectionLabel('CONTEÚDO'),
                            const SizedBox(height: AppSpacing.s),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MemoCompactTileCard(
                                    featured: true,
                                    enabled: resolvedAcademy != null,
                                    icon: Icons.fitness_center_rounded,
                                    title: 'Campo de treinamento',
                                    subtitle:
                                        'Técnicas, missões e troféus semanais',
                                    onTap: resolvedAcademy == null
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AcademyTrainingFieldScreen(
                                                  academy: resolvedAcademy,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: MemoCompactTileCard(
                                    featured: false,
                                    enabled: resolvedAcademy != null,
                                    icon: Icons.palette_rounded,
                                    title: 'Personalização e Negócios',
                                    subtitle:
                                        'Logo, horários, parceiros e avisos',
                                    onTap: resolvedAcademy == null
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AcademyCustomizationBusinessScreen(
                                                  academy: resolvedAcademy,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            const MemoSectionLabel('ALUNOS'),
                            const SizedBox(height: AppSpacing.s),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MemoCompactTileCard(
                                    featured: false,
                                    enabled: resolvedAcademy != null,
                                    icon: Icons.school_rounded,
                                    title: 'Alunos',
                                    subtitle: 'Usuários, pontos e alunos ativos',
                                    onTap: resolvedAcademy == null
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AcademyStudentsScreen(
                                                  academy: resolvedAcademy,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: MemoCompactTileCard(
                                    featured: false,
                                    enabled: true,
                                    icon: Icons.assignment_rounded,
                                    title: 'Chamada e frequência',
                                    subtitle:
                                        'Chamada (QR), histórico e frequência',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AcademyAttendanceHubScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            const MemoSectionLabel('DADOS'),
                            const SizedBox(height: AppSpacing.s),
                            ..._academies.map(
                              (academy) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.s),
                                child: _academyNavigationTile(
                                  enabled: true,
                                  icon: Icons.bar_chart_rounded,
                                  title: 'Relatórios',
                                  subtitle:
                                      'Exportar dados e métricas da academia',
                                  onTap: () => _openAcademy(academy),
                                ),
                              ),
                            ),
                            if (_showPushItem) ...[
                              _academyNavigationTile(
                                enabled: true,
                                icon: Icons.notifications_active_rounded,
                                title: 'Aviso à academia (push)',
                                subtitle:
                                    'Enviar notificação para quem tem o app e está na sua academia',
                                onTap: _openPushScreen,
                              ),
                            ],
                          ],
                        ),
                      ),
      ),
    );
  }
}
