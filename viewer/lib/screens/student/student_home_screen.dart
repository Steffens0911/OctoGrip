import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/screens/student/my_executions_screen.dart';
import 'package:viewer/screens/student/pending_confirmations_screen.dart';
import 'package:viewer/screens/student/points_log_screen.dart';
import 'package:viewer/screens/student/report_difficulty_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Tela inicial da área do aluno: seletor de usuário (MVP), missões da semana e atalhos.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  final _api = ApiService();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  MissionWeek? _missionWeek;
  int? _userPoints;
  Map<String, dynamic>? _collectiveGoal;
  int _pendingConfirmationsCount = 0;
  bool _loading = true;
  String? _error;

  /// Mapeia faixa do usuário para level da API (beginner/intermediate).
  static String _levelFromGraduation(String? g) {
    if (g == null || g.isEmpty) return 'beginner';
    switch (g.toLowerCase()) {
      case 'purple':
      case 'brown':
      case 'black':
        return 'intermediate';
      default:
        return 'beginner';
    }
  }

  /// Label da faixa para exibição (nome – faixa).
  static String _faixaLabel(String? g) {
    if (g == null || g.isEmpty) return '';
    switch (g.toLowerCase()) {
      case 'white': return 'Branca';
      case 'blue': return 'Azul';
      case 'purple': return 'Roxa';
      case 'brown': return 'Marrom';
      case 'black': return 'Preta';
      default: return g;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedUser != null) {
      _loadMissionWeek();
      _loadUserPoints();
      _loadCollectiveGoal();
      _loadPendingConfirmationsWith(_selectedUser!.id);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missionWeek = null;
    });
    try {
      final users = await _api.getUsers();
      if (!mounted) return;
      final selected = users.isNotEmpty ? users.first : null;
      setState(() {
        _users = users;
        _selectedUser = selected;
        _loading = false;
        if (selected == null) _pendingConfirmationsCount = 0;
      });
      if (selected != null) {
        final level = _levelFromGraduation(selected.graduation);
        await Future.wait([
          _loadMissionWeekWith(selected.id, selected.academyId, level),
          _loadUserPointsWith(selected.id),
          _loadCollectiveGoalWith(selected.academyId),
          _loadPendingConfirmationsWith(selected.id),
        ]);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _loadMissionWeekWith(String userId, String? academyId, String level) async {
    try {
      final week = await _api.getMissionWeek(userId: userId, academyId: academyId, level: level);
      if (mounted) setState(() => _missionWeek = week);
    } catch (e) {
      if (mounted) setState(() => _missionWeek = null);
      if (!e.toString().contains('404') && mounted) setState(() => _error = userFacingMessage(e));
    }
  }

  Future<void> _loadUserPointsWith(String userId) async {
    try {
      final res = await _api.getUserPoints(userId);
      if (mounted) setState(() => _userPoints = res['points'] as int?);
    } catch (_) {
      if (mounted) setState(() => _userPoints = null);
    }
  }

  Future<void> _loadCollectiveGoalWith(String? academyId) async {
    if (academyId == null || academyId.isEmpty) {
      if (mounted) setState(() => _collectiveGoal = null);
      return;
    }
    try {
      final res = await _api.getCollectiveGoalCurrent(academyId);
      if (mounted) setState(() => _collectiveGoal = res);
    } catch (_) {
      if (mounted) setState(() => _collectiveGoal = null);
    }
  }

  Future<void> _loadPendingConfirmationsWith(String userId) async {
    try {
      final list = await _api.getPendingConfirmations(userId);
      if (mounted) setState(() => _pendingConfirmationsCount = list.length);
    } catch (_) {
      if (mounted) setState(() => _pendingConfirmationsCount = 0);
    }
  }

  Future<void> _loadMissionWeek() async {
    if (_selectedUser == null) return;
    setState(() => _error = null);
    try {
      final level = _levelFromGraduation(_selectedUser!.graduation);
      final week = await _api.getMissionWeek(
        userId: _selectedUser!.id,
        academyId: _selectedUser!.academyId,
        level: level,
      );
      if (mounted) setState(() => _missionWeek = week);
    } catch (e) {
      if (mounted) setState(() => _missionWeek = null);
      if (e.toString().contains('404')) return;
      if (mounted) setState(() => _error = userFacingMessage(e));
    }
  }

  Future<void> _loadUserPoints() async {
    if (_selectedUser == null) return;
    try {
      final res = await _api.getUserPoints(_selectedUser!.id);
      if (mounted) setState(() => _userPoints = res['points'] as int?);
    } catch (_) {
      if (mounted) setState(() => _userPoints = null);
    }
  }

  Future<void> _loadCollectiveGoal() async {
    final academyId = _selectedUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      setState(() => _collectiveGoal = null);
      return;
    }
    try {
      final res = await _api.getCollectiveGoalCurrent(academyId);
      if (mounted) setState(() => _collectiveGoal = res);
    } catch (_) {
      if (mounted) setState(() => _collectiveGoal = null);
    }
  }

  void _openLesson(LessonViewData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewScreen(data: data),
      ),
    );
    _loadMissionWeek();
    _loadUserPoints();
    _loadCollectiveGoal();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              _selectedUser != null
                  ? 'Olá, ${_selectedUser!.name ?? _selectedUser!.email}'
                  : 'Olá',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Suas missões e atividades da semana',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 24),
            _buildUserSelector(),
            const SizedBox(height: 20),
            if (_collectiveGoal != null) _buildCollectiveGoalCard(),
            if (_collectiveGoal != null) const SizedBox(height: 16),
            if (_selectedUser != null &&
                (_selectedUser!.academyId == null || _selectedUser!.academyId!.isEmpty))
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vincule este usuário a uma academia em Administração → Usuários para ver as missões semanais.',
                        style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedUser != null &&
                (_selectedUser!.academyId == null || _selectedUser!.academyId!.isEmpty))
              const SizedBox(height: 16),
            if (_missionWeek != null) _buildMissionWeekSection(),
            if (_missionWeek == null && !_loading && _selectedUser != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Text(
                  _selectedUser!.academyId == null || _selectedUser!.academyId!.isEmpty
                      ? 'Configure a academia do usuário para ver as missões.'
                      : 'Nenhuma missão da semana no momento.',
                  style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            if (_missionWeek == null && _selectedUser != null) const SizedBox(height: 16),
            if (_selectedUser != null) ...[
              Text(
                'Atalhos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 12),
              _buildShortcuts(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Usuário (MVP)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                Text(
                  'Pontos: ${_userPoints ?? '—'}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<UserModel>(
              value: _selectedUser,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _users
                  .map((u) {
                    final displayName = u.name ?? u.email;
                    final faixa = _faixaLabel(u.graduation);
                    return DropdownMenuItem(
                      value: u,
                      child: Text(faixa.isNotEmpty ? '$displayName – $faixa' : displayName),
                    );
                  })
                  .toList(),
              onChanged: (u) async {
                setState(() {
                  _selectedUser = u;
                  _missionWeek = null;
                  _userPoints = null;
                  if (u == null) _pendingConfirmationsCount = 0;
                });
                if (u != null) {
                  final level = _levelFromGraduation(u.graduation);
                  await Future.wait([
                    _loadMissionWeekWith(u.id, u.academyId, level),
                    _loadUserPointsWith(u.id),
                    _loadCollectiveGoalWith(u.academyId),
                    _loadPendingConfirmationsWith(u.id),
                  ]);
                  if (mounted) setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectiveGoalCard() {
    final g = _collectiveGoal!;
    final goal = g['goal'] as Map<String, dynamic>?;
    final current = g['current_count'] as int? ?? 0;
    final target = g['target_count'] as int? ?? 0;
    final techniqueName = goal?['technique_name'] as String? ?? 'técnica';
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Meta da semana',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '$current / $target execuções de $techniqueName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.borderOf(context),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionWeekSection() {
    final entries = _missionWeek!.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(Icons.flag, color: AppTheme.primary, size: 28),
            title: Text(
              'Missões da semana',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildMissionCard(entries[i].periodLabel, entries[i].mission),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard(String periodLabel, MissionToday? m) {
    if (m == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: Colors.grey.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nenhuma missão neste período',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final data = LessonViewData(
      lessonId: m.lessonId,
      missionId: m.missionId,
      title: m.lessonTitle.isNotEmpty ? m.lessonTitle : m.techniqueName,
      description: m.description,
      videoUrl: m.videoUrl,
      userId: _selectedUser!.id,
      academyId: _selectedUser!.academyId,
      techniqueName: m.techniqueName,
      positionName: m.positionName,
      multiplier: m.multiplier,
      estimatedDurationSeconds: m.estimatedDurationSeconds,
      alreadyCompleted: m.alreadyCompleted,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: AppTheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.techniqueName.isNotEmpty ? m.techniqueName : periodLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (m.alreadyCompleted)
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.missionTitle.isNotEmpty ? m.missionTitle : m.lessonTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (m.techniqueName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              m.positionName.isNotEmpty
                  ? '${m.techniqueName} ${m.positionName}'
                  : m.techniqueName,
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 14),
            ),
          ],
          if (m.estimatedDurationSeconds != null && m.estimatedDurationSeconds! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '~${m.estimatedDurationSeconds! ~/ 60} min',
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openLesson(data),
            icon: Icon(m.alreadyCompleted ? Icons.visibility_rounded : Icons.play_arrow_rounded, size: 20),
            label: Text(m.alreadyCompleted ? 'Ver novamente' : 'Começar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts() {
    if (_selectedUser == null) return const SizedBox.shrink();
    final userId = _selectedUser!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShortcutTile(
          icon: Icons.list_alt,
          title: 'Log de pontuação',
          subtitle: 'Histórico de pontos ganhos',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PointsLogScreen(
                userId: userId,
                userName: _selectedUser?.name ?? _selectedUser?.email,
              ),
            ),
          ),
        ),
        _ShortcutTile(
          icon: Icons.how_to_reg,
          title: 'Confirmações pendentes',
          subtitle: 'Confirmar execuções em você',
          showAlertBadge: _pendingConfirmationsCount > 0,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PendingConfirmationsScreen(
                userId: userId,
                userName: _selectedUser?.name ?? _selectedUser?.email,
              ),
            ),
          ).then((_) => _loadPendingConfirmationsWith(userId)),
        ),
        _ShortcutTile(
          icon: Icons.send_outlined,
          title: 'Minhas solicitações',
          subtitle: 'Status das confirmações que você pediu',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyExecutionsScreen(userId: userId),
            ),
          ),
        ),
        _ShortcutTile(
          icon: Icons.warning_amber_rounded,
          title: 'Reportar dificuldade',
          subtitle: 'Marcar posição difícil no treino',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDifficultyScreen(
                userId: userId,
                academyId: _selectedUser?.academyId,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showAlertBadge;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showAlertBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
        child: Material(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                            ),
                          ),
                          if (showAlertBadge) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
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
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMutedOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
