import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/app_theme.dart';
import 'dart:math';

import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/screens/student/my_executions_screen.dart';
import 'package:viewer/screens/student/pending_confirmations_screen.dart';
import 'package:viewer/screens/student/points_log_screen.dart';
import 'package:viewer/screens/student/classmates_gallery_screen.dart';
import 'package:viewer/screens/student/report_difficulty_screen.dart';
import 'package:viewer/screens/student/partners_screen.dart';
import 'package:viewer/screens/student/trophy_gallery_screen.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

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
  Map<String, dynamic>? _collectiveGoal;
  int _pendingConfirmationsCount = 0;
  bool _loading = true;
  String? _error;
  String? _academyLogoUrl;
  bool _academyLogoLoaded = false;
  String? _academyScheduleImageUrl;
  String? _academyScheduleDisplayUrl;
  String? _academyScheduleOriginalUrl;
  bool _academyScheduleLoaded = false;

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
      // Agrupar carregamentos para evitar múltiplos setState
      Future.wait([
        _loadMissionWeekWith(currentUser.academyId, level),
        _loadUserPointsWith(currentUser.id),
        _loadCollectiveGoalWith(currentUser.academyId),
        _loadPendingConfirmationsWith(),
      ]);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missionWeek = null;
      _academyLogoUrl = null;
      _academyLogoLoaded = false;
      _academyScheduleImageUrl = null;
      _academyScheduleDisplayUrl = null;
      _academyScheduleOriginalUrl = null;
      _academyScheduleLoaded = false;
    });
    try {
      await AuthService().refreshMe();
    } catch (_) {
      // Mantém dados em cache se a API falhar (ex.: offline).
    }
    final currentUser = AuthService().currentUser;
    setState(() => _selectedUser = currentUser);
    if (currentUser == null) {
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
        _academyLogoUrl = academy.logoUrl;
        _academyLogoLoaded = true;
        _academyScheduleImageUrl = academy.scheduleImageUrl;
        _academyScheduleLoaded = true;
        _academyScheduleDisplayUrl = null;
        _academyScheduleOriginalUrl = null;
      });
      if (academy.scheduleImageUrl != null && academy.scheduleImageUrl!.isNotEmpty) {
        try {
          final res = await _api.getScheduleDisplayUrl(academy.scheduleImageUrl!);
          if (mounted) {
            setState(() {
              _academyScheduleDisplayUrl = res['display_url'] as String?;
              _academyScheduleOriginalUrl = res['original_url'] as String?;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _academyScheduleDisplayUrl = null;
              _academyScheduleOriginalUrl = academy.scheduleImageUrl;
            });
          }
        }
      }
    } catch (_) {
      // Falha de rede ou permissão: mostra placeholder em vez de ficar em "Carregando...".
      if (mounted) {
        setState(() {
          _academyLogoUrl = null;
          _academyLogoLoaded = true;
          _academyScheduleImageUrl = null;
          _academyScheduleDisplayUrl = null;
          _academyScheduleOriginalUrl = null;
          _academyScheduleLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMissionWeekWith(String? academyId, String level) async {
    try {
      final week = await _api.getMissionWeek(academyId: academyId, level: level);
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
    if (_loading && _selectedUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _selectedUser == null) {
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
            if (_selectedUser?.academyId != null && _selectedUser!.academyId!.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding(context),
                  vertical: 20,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderOf(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _academyLogoUrl != null && _academyLogoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _academyLogoUrl!.startsWith('/')
                                ? '${_api.baseUrl}$_academyLogoUrl'
                                : _academyLogoUrl!,
                            height: 92,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Não foi possível carregar o brasão',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 48,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _academyLogoLoaded
                                  ? 'Brasão não definido para esta academia'
                                  : 'Carregando...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
            ],
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
            _buildUserCard(),
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
            if (_selectedUser != null) ...[
              const SizedBox(height: 16),
              _buildMainAccordion(),
              if (_selectedUser!.academyId != null && _selectedUser!.academyId!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPartnersSection(),
              ],
            ],
            if (_academyScheduleImageUrl != null &&
                _academyScheduleImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildScheduleCard(),
            ],
          ],
        ),
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
    final displayUrl = _academyScheduleDisplayUrl;
    final openUrl = _academyScheduleOriginalUrl ?? _academyScheduleImageUrl;
    final hasImage = displayUrl != null && displayUrl.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openUrl != null && openUrl.isNotEmpty ? () => _openScheduleUrl(openUrl) : null,
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
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    displayUrl!.startsWith('/') ? '${_api.baseUrl}$displayUrl' : displayUrl,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _schedulePlaceholder(context, openUrl),
                  ),
                )
              else
                _schedulePlaceholder(context, openUrl),
              if (openUrl != null && openUrl.isNotEmpty)
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
          Icon(Icons.schedule, size: 32, color: AppTheme.textSecondaryOf(context)),
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

  Widget _buildUserCard() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final displayName = u.name ?? u.email;
    final faixa = _faixaLabel(u.graduation);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            faixa.isNotEmpty ? '$displayName – $faixa' : displayName,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryOf(context)),
          ),
          Text(
            'Pontos: ${_userPoints ?? '—'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
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
                  _selectedUser!.academyId == null || _selectedUser!.academyId!.isEmpty
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(Icons.home_rounded, color: AppTheme.primary, size: 26),
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
              _buildTrophiesSection(),
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        const SizedBox(height: 8),
        _ShortcutTile(
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
      ],
    );
  }

  Widget _buildTrophiesSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final hasAcademy = u.academyId != null && u.academyId!.isNotEmpty;

    final children = <Widget>[
      _ShortcutTile(
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
        _ShortcutTile(
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
    if (u == null || u.academyId == null || u.academyId!.isEmpty) return const SizedBox.shrink();
    return _buildHomeAccordion(
      icon: Icons.handshake_outlined,
      title: 'Parceiros',
      children: [
        _ShortcutTile(
          icon: Icons.business_center_outlined,
          title: 'Nossos parceiros',
          subtitle: 'Empresas e academias parceiras',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartnersScreen(academyId: u.academyId!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcuts() => const SizedBox.shrink();
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
                icon: Icon(Icons.close, size: 20, color: AppTheme.textSecondaryOf(context)),
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
                  partner.logoUrl!.startsWith('/') ? '${api.baseUrl}${partner.logoUrl}' : partner.logoUrl!,
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
          if (partner.description != null && partner.description!.isNotEmpty) ...[
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
