import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/core/leveling.dart';
import 'dart:math';

import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/screens/student/my_executions_screen.dart';
import 'package:viewer/screens/student/pending_confirmations_screen.dart';
import 'package:viewer/screens/student/points_log_screen.dart';
import 'package:viewer/screens/student/classmates_gallery_screen.dart';
import 'package:viewer/screens/student/partners_screen.dart';
import 'package:viewer/screens/student/trophy_gallery_screen.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/screens/student/global_supporters_section.dart';
import 'package:viewer/theme/fantasy_theme.dart';
import 'package:viewer/widgets/header_widget.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/partners_card.dart';

/// Tela inicial da área do aluno: missões da semana e atalhos. Usuário logado via AuthService.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, this.refreshTrigger = 0});

  /// Incrementado ao tocar na aba Início; em didUpdateWidget dispara _load() para atualizar missões.
  final int refreshTrigger;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  final _api = ApiService();
  UserModel? _selectedUser;
  MissionWeek? _missionWeek;
  int? _userPoints;
  int? _userLevel;
  int? _nextLevelThreshold;
  Map<String, dynamic>? _collectiveGoal;
  int _pendingConfirmationsCount = 0;
  TrainingVideo? _dailyVideo;
  int _dailyVideoPoints = 0;
  bool _dailyVideoCompleted = false;
  bool _loading = true;
  String? _error;
  int _scheduleLocalVersion = DateTime.now().millisecondsSinceEpoch;
  String? _academyLogoUrl;
  String? _academyScheduleImageUrl;
  bool _showTrophies = true;
  bool _showPartners = true;
  bool _showSchedule = true;
  bool _showGlobalSupporters = true;

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
      case 'white':
        return 'Branca';
      case 'blue':
        return 'Azul';
      case 'purple':
        return 'Roxa';
      case 'brown':
        return 'Marrom';
      case 'black':
        return 'Preta';
      default:
        return g;
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
  void didUpdateWidget(covariant StudentHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedUser != null) {
      final currentUser = _selectedUser!;
      final level = _levelFromGraduation(currentUser.graduation);
      // Agrupar carregamentos para evitar múltiplos setState (inclui quadro de horários)
      Future.wait([
        _loadMissionWeekWith(currentUser.academyId, level),
        _loadUserPointsWith(currentUser.id),
        _loadCollectiveGoalWith(currentUser.academyId),
        _loadPendingConfirmationsWith(),
        _loadAcademyLogoWith(currentUser.academyId),
      ]);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _missionWeek = null;
      _academyLogoUrl = null;
      _academyScheduleImageUrl = null;
      _showTrophies = true;
      _showPartners = true;
      _showSchedule = true;
      _showGlobalSupporters = true;
      _dailyVideo = null;
      _dailyVideoPoints = 0;
      _dailyVideoCompleted = false;
    });
    try {
      await AuthService().refreshMe();
    } catch (_) {
      // Mantém dados em cache se a API falhar (ex.: offline).
    }
    final currentUser = AuthService().currentUser;
    if (!mounted) return;
    setState(() => _selectedUser = currentUser);
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pendingConfirmationsCount = 0;
      });
      return;
    }
    try {
      final level = _levelFromGraduation(currentUser.graduation);
      await Future.wait([
        _loadMissionWeekWith(currentUser.academyId, level),
        _loadUserPointsWith(currentUser.id),
        _loadCollectiveGoalWith(currentUser.academyId),
        _loadPendingConfirmationsWith(),
        _loadAcademyLogoWith(currentUser.academyId),
        _loadDailyVideo(),
      ]);
      if (mounted) {
        setState(() => _loading = false);
        _maybeShowRandomPartnerHighlight();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  Future<void> _maybeShowRandomPartnerHighlight() async {
    if (!mounted) return;
    final auth = AuthService();
    final user = _selectedUser;
    if (user == null) return;
    if (!auth.isStudent()) return;
    if (auth.randomPartnerShown) return;
    final academyId = user.academyId;
    if (academyId == null || academyId.isEmpty) return;

    try {
      final partners = await _api.getPartners(academyId);
      if (!mounted || partners.isEmpty) return;
      final eligible = partners.where((p) => p.highlightOnLogin).toList();
      if (eligible.isEmpty) return;
      final randomPartner = eligible[Random().nextInt(eligible.length)];
      auth.markRandomPartnerShown();
      await showDialog(
        context: context,
        builder: (context) => _RandomPartnerDialog(
          partner: randomPartner,
          api: _api,
        ),
      );
    } catch (_) {
      // Silencia erros de rede para não quebrar a experiência de login.
    }
  }

  Future<void> _loadAcademyLogoWith(String? academyId) async {
    if (academyId == null || academyId.isEmpty) return;
    try {
      final academy = await _api.getAcademyFresh(academyId);
      if (!mounted) return;
      setState(() {
        _scheduleLocalVersion = DateTime.now().millisecondsSinceEpoch;
        _academyLogoUrl = academy.logoUrl;
        _academyScheduleImageUrl = academy.scheduleImageUrl;
        _showTrophies = academy.showTrophies;
        _showPartners = academy.showPartners;
        _showSchedule = academy.showSchedule;
        _showGlobalSupporters = academy.showGlobalSupporters;
      });
    } catch (_) {
      // Falha de rede ou permissão: mostra placeholder em vez de ficar em "Carregando...".
      if (mounted) {
        setState(() {
          _academyLogoUrl = null;
          _academyScheduleImageUrl = null;
          _showTrophies = true;
          _showPartners = true;
          _showSchedule = true;
          _showGlobalSupporters = true;
        });
      }
    }
  }

  Future<void> _loadMissionWeekWith(String? academyId, String level) async {
    try {
      final week =
          await _api.getMissionWeek(academyId: academyId, level: level);
      if (mounted) {
        setState(() {
          _missionWeek = week;
          if (_error != null && _error!.contains('missão')) {
            _error = null; // Limpar erro de missão se carregou com sucesso
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _missionWeek = null;
          if (!e.toString().contains('404')) {
            _error = userFacingMessage(e);
          }
        });
      }
    }
  }

  Future<void> _loadUserPointsWith(String userId) async {
    try {
      final res = await _api.getUserPoints(userId);
      final p = levelProgressFromUserPointsMap(res);
      if (mounted) {
        setState(() {
          _userLevel = p.level;
          _userPoints = p.levelPoints;
          _nextLevelThreshold = p.nextThreshold;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userPoints = null;
          _userLevel = null;
          _nextLevelThreshold = null;
        });
      }
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

  Future<void> _loadPendingConfirmationsWith() async {
    try {
      final count = await _api.getPendingConfirmationsCount();
      if (mounted) setState(() => _pendingConfirmationsCount = count);
    } catch (_) {
      if (mounted) setState(() => _pendingConfirmationsCount = 0);
    }
  }

  Future<void> _loadMissionWeek() async {
    if (_selectedUser == null) return;
    final currentUser = _selectedUser!;
    final level = _levelFromGraduation(currentUser.graduation);
    // Otimização: agrupar múltiplos setState em um único
    try {
      final week = await _api.getMissionWeek(
        academyId: currentUser.academyId,
        level: level,
      );
      if (mounted) {
        setState(() {
          _missionWeek = week;
          _error = null; // Limpar erro ao carregar com sucesso
        });
      }
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
      final p = levelProgressFromUserPointsMap(res);
      if (mounted) {
        setState(() {
          _userLevel = p.level;
          _userPoints = p.levelPoints;
          _nextLevelThreshold = p.nextThreshold;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userPoints = null;
          _userLevel = null;
          _nextLevelThreshold = null;
        });
      }
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

  /// Vídeo do dia que pontua: primeiro da lista getTrainingVideosToday da academia do usuário.
  Future<void> _loadDailyVideo() async {
    final academyId = _selectedUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      if (mounted) {
        setState(() {
          _dailyVideo = null;
          _dailyVideoPoints = 0;
          _dailyVideoCompleted = false;
        });
      }
      return;
    }
    try {
      final list = await _api.getTrainingVideosToday();
      if (!mounted) return;
      final forAcademy = list
          .where((v) => v.academyId == academyId && v.pointsPerDay > 0)
          .toList();
      final video = forAcademy.isNotEmpty ? forAcademy.first : null;
      setState(() {
        _dailyVideo = video;
        _dailyVideoPoints = video?.pointsPerDay ?? 0;
        _dailyVideoCompleted = video?.hasCompletedToday ?? false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dailyVideo = null;
          _dailyVideoPoints = 0;
          _dailyVideoCompleted = false;
        });
      }
    }
  }

  void _onDailyVideoTap() {
    if (_dailyVideo == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => TrainingVideoViewScreen(video: _dailyVideo!),
      ),
    ).then((_) {
      _loadDailyVideo();
      _loadUserPoints();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _selectedUser == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error != null && _selectedUser == null) {
      return Center(
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
              FilledButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final u = _selectedUser;
    final screenPadding = AppTheme.screenPadding(context);

    return Scaffold(
      body: Stack(
        children: [
          const _FantasyBackground(),
          RefreshIndicator(
            onRefresh: _load,
            color: FantasyTheme.gold,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(screenPadding, 0, screenPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeaderWidget(
                    userName: u?.name ?? u?.email ?? 'Perin',
                    userBelt: _faixaLabel(u?.graduation),
                    userLevel: _userLevel ?? 1,
                    currentXp: _userPoints ?? 0,
                    maxXp: _nextLevelThreshold ?? kBaseLevelThreshold,
                    academyLogoUrl: _academyLogoUrl != null &&
                            _academyLogoUrl!.isNotEmpty
                        ? (_academyLogoUrl!.startsWith('/')
                            ? '${_api.baseUrl}$_academyLogoUrl'
                            : _academyLogoUrl!)
                        : null,
                    dailyVideoPoints: _dailyVideoPoints,
                    dailyVideoCompleted: _dailyVideoCompleted,
                    onDailyVideoTap: _onDailyVideoTap,
                  ),
                  const SizedBox(height: 10),
                  if (_collectiveGoal != null) ...[
                    _buildCollectiveGoalCard(),
                    const SizedBox(height: 14),
                  ] else if (_missionWeek != null) ...[
                    _buildWeeklyMilestoneCard(),
                    const SizedBox(height: 14),
                  ],
                  if (u != null &&
                      (u.academyId == null || u.academyId!.isEmpty))
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vincule este usuário a uma academia em Administração → Usuários para ver as missões semanais.',
                              style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (u != null &&
                      (u.academyId == null || u.academyId!.isEmpty))
                    const SizedBox(height: 16),
                  if (u != null) ...[
                    _buildMainAccordion(),
                    if (u.academyId != null && u.academyId!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (_showPartners) _buildPartnersSection(),
                    ],
                  ],
                  if (_academyScheduleImageUrl != null &&
                      _academyScheduleImageUrl!.isNotEmpty &&
                      _showSchedule) ...[
                    const SizedBox(height: 16),
                    _buildScheduleCard(),
                  ],
                  if (_showGlobalSupporters) const GlobalSupportersSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScheduleUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildScheduleCard() {
    final rawUrl = _academyScheduleImageUrl;
    if (rawUrl == null || rawUrl.isEmpty) return const SizedBox.shrink();
    final baseUrl = rawUrl.startsWith('/') ? '${_api.baseUrl}$rawUrl' : rawUrl;
    // Cache-buster local: sempre que recarregamos a academia (_loadAcademyLogoWith),
    // _scheduleLocalVersion é atualizado, garantindo que a URL mude após um novo upload.
    final v = _scheduleLocalVersion.toString();
    final sep = baseUrl.contains('?') ? '&' : '?';
    final openUrl = '$baseUrl${sep}v=$v';
    final maxH = MediaQuery.of(context).size.height * 0.35;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openScheduleUrl(openUrl),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Horários da academia',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: maxH.clamp(200.0, 320.0)),
                  child: Image.network(
                    openUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _schedulePlaceholder(context, openUrl),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Toque para abrir',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _schedulePlaceholder(BuildContext context, String? openUrl) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.borderOf(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule,
              size: 32, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 12),
          Text(
            openUrl != null && openUrl.isNotEmpty
                ? 'Toque para ver horários'
                : 'Não foi possível carregar a imagem',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
            textAlign: TextAlign.center,
          ),
        ],
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
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyMilestoneCard() {
    final entries = _missionWeek?.entries ?? const <MissionWeekSlot>[];
    final total = entries.length;
    final completed =
        entries.where((e) => e.mission?.alreadyCompleted ?? false).length;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final remaining = total > 0 ? (total - completed) : 0;

    final headline = total == 0
        ? 'Milestone semanal'
        : completed >= total
            ? 'Ciclo semanal concluído'
            : 'Você já concluiu $completed de $total missões';
    final message = total == 0
        ? 'Quando as missões da semana estiverem disponíveis, acompanhe sua evolução aqui.'
        : completed >= total
            ? 'Excelente consistência! Seu progresso da semana está completo.'
            : 'Faltam $remaining missão(ões) para concluir seu ciclo desta semana.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
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
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.flag, color: AppTheme.primary, size: 28),
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
              const Icon(Icons.flag, color: AppTheme.primary, size: 28),
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
                Icon(Icons.check_circle,
                    color: Colors.green.shade700, size: 22),
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
              style: TextStyle(
                  color: AppTheme.textSecondaryOf(context), fontSize: 14),
            ),
          ],
          if (m.estimatedDurationSeconds != null &&
              m.estimatedDurationSeconds! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '~${m.estimatedDurationSeconds! ~/ 60} min',
              style: TextStyle(
                  color: AppTheme.textSecondaryOf(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openLesson(data),
            icon: Icon(
                m.alreadyCompleted
                    ? Icons.visibility_rounded
                    : Icons.play_arrow_rounded,
                size: 20),
            label: Text(m.alreadyCompleted ? 'Ver novamente' : 'Começar'),
          ),
        ],
      ),
    );
  }

  /// Acordeom pai que agrupa Missões da semana, Troféus e Confirmações e solicitações.
  Widget _buildMainAccordion() {
    final missionWidget = _missionWeek != null
        ? _buildMissionWeekSection()
        : (_missionWeek == null && !_loading && _selectedUser != null
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Text(
                  _selectedUser!.academyId == null ||
                          _selectedUser!.academyId!.isEmpty
                      ? 'Configure a academia do usuário para ver as missões.'
                      : 'Nenhuma missão da semana no momento.',
                  style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                ),
              )
            : const SizedBox.shrink());
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
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.home_rounded,
                color: AppTheme.primary, size: 26),
            title: Text(
              'Centro de treinamento',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              missionWidget,
              const SizedBox(height: 16),
              if (_showTrophies) _buildTrophiesSection(),
              const SizedBox(height: 16),
              _buildConfirmationsAndRequestsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAccordion({
    required IconData icon,
    required String title,
    bool showAlert = false,
    required List<Widget> children,
  }) {
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
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(icon, color: AppTheme.primary, size: 26),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (showAlert) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ],
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationsAndRequestsSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final hasConfirmationsAlert = _pendingConfirmationsCount > 0;
    return _buildHomeAccordion(
      icon: Icons.notifications_active_outlined,
      title: 'Confirmações e solicitações',
      showAlert: hasConfirmationsAlert,
      children: [
        AppNavigationTile(
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
        const SizedBox(height: 8),
        AppNavigationTile(
          icon: Icons.how_to_reg,
          title: 'Confirmações pendentes',
          subtitle: 'Confirmar execuções em você',
          showAlertBadge: hasConfirmationsAlert,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PendingConfirmationsScreen(
                userId: userId,
                userName: _selectedUser?.name ?? _selectedUser?.email,
              ),
            ),
          ).then((_) => _loadPendingConfirmationsWith()),
        ),
        const SizedBox(height: 8),
        AppNavigationTile(
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
      ],
    );
  }

  Widget _buildTrophiesSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final hasAcademy = u.academyId != null && u.academyId!.isNotEmpty;

    final children = <Widget>[
      AppNavigationTile(
        icon: Icons.emoji_events_outlined,
        title: 'Galeria de troféus',
        subtitle: 'Troféus conquistados (ouro, prata, bronze)',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrophyGalleryScreen(
              userId: userId,
              userName: _selectedUser?.name ?? _selectedUser?.email,
            ),
          ),
        ),
      ),
    ];

    if (hasAcademy) {
      children.addAll([
        const SizedBox(height: 8),
        AppNavigationTile(
          icon: Icons.people_outline,
          title: 'Galeria dos colegas',
          subtitle: 'Troféus e medalhas dos colegas da academia',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassmatesGalleryScreen(
                academyId: u.academyId!,
                currentUserId: userId,
              ),
            ),
          ),
        ),
      ]);
    }

    return _buildHomeAccordion(
      icon: Icons.emoji_events,
      title: 'Troféus',
      children: children,
    );
  }

  Widget _buildPartnersSection() {
    final u = _selectedUser;
    if (u == null || u.academyId == null || u.academyId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return PartnersCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartnersScreen(academyId: u.academyId!),
        ),
      ),
    );
  }

}

/// Fundo espacial/gradiente usado também na home fantasia.
class _FantasyBackground extends StatelessWidget {
  const _FantasyBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: FantasyTheme.backgroundGradient,
      ),
    );
  }
}

class _RandomPartnerDialog extends StatelessWidget {
  final Partner partner;
  final ApiService api;

  const _RandomPartnerDialog({
    required this.partner,
    required this.api,
  });

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parceiro em destaque',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    size: 20, color: AppTheme.textSecondaryOf(context)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (partner.logoUrl != null && partner.logoUrl!.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  partner.logoUrl!.startsWith('/')
                      ? '${api.baseUrl}${partner.logoUrl}'
                      : partner.logoUrl!,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (partner.logoUrl != null && partner.logoUrl!.isNotEmpty)
            const SizedBox(height: 12),
          Text(
            partner.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (partner.description != null &&
              partner.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              partner.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Agora não'),
              ),
              if (partner.url != null && partner.url!.isNotEmpty) ...[
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _openUrl(partner.url),
                  child: const Text('Conhecer'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

