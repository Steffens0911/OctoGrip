import 'dart:async' show unawaited;

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
import 'package:viewer/services/student_home_snapshot_store.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/screens/student/global_supporters_section.dart';
import 'package:viewer/theme/fantasy_theme.dart';
import 'package:viewer/widgets/gamification/points_rules_sheet.dart';
import 'package:viewer/widgets/gamification/streak_widget.dart';
import 'package:viewer/widgets/gamification/weekly_mission_path.dart';
import 'package:viewer/widgets/header_widget.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/academy_login_notice_dialog.dart';
import 'package:viewer/widgets/partners_card.dart';
import 'package:viewer/widgets/trophies_home_section.dart';
import 'package:viewer/widgets/student/home_loading_skeleton.dart';

/// Tela inicial da área do aluno: missões da semana e atalhos. Usuário logado via AuthService.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    this.refreshTrigger = 0,
    this.onPendingConfirmationsCountChanged,
  });

  /// Incrementado ao tocar na aba Início; em didUpdateWidget dispara _load() para atualizar missões.
  final int refreshTrigger;

  /// Notifica o shell (ex.: badge na aba Campo de treinamento) quando o contador de confirmações pendentes muda.
  final ValueChanged<int>? onPendingConfirmationsCountChanged;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  final _api = ApiService();
  final _snapshotStore = StudentHomeSnapshotStore();
  UserModel? _selectedUser;
  MissionWeek? _missionWeek;
  int? _userPoints;
  int? _userLevel;
  int? _nextLevelThreshold;
  Map<String, dynamic>? _collectiveGoal;
  int _pendingConfirmationsCount = 0;
  /// Esconde o banner até o contador mudar de valor (nova carga da API).
  bool _pendingBannerDismissed = false;
  /// Bottom sheet de lembrete só uma vez por vida do State (sessão na aba Campo de treinamento).
  bool _pendingBottomSheetShownThisSession = false;
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
  /// Aviso ao logar (dados da academia; modal uma vez por sessão).
  String? _loginNoticeTitle;
  String? _loginNoticeBody;
  String? _loginNoticeUrl;
  bool _loginNoticeActive = false;
  /// Missão recém-concluída (pulso no [WeeklyMissionPath]); limpo após animar.
  String? _celebrateMissionId;
  /// Rede a sincronizar (header + missões, etc.): barra no topo e skeletons opcionais.
  bool _syncingHomeData = false;

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
      _load(silent: true);
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
        _loadHeaderStatsWith(),
        _loadCollectiveGoalWith(currentUser.academyId),
        _loadPendingConfirmationsWith(),
      ]).then((_) {
        if (mounted) {
          setState(() => _selectedUser = AuthService().currentUser);
        }
      });
    }
  }

  /// [silent]: não mostra estado de “carregamento inicial” nem limpa celebração
  /// (ex.: voltar à aba Início, pull-to-refresh). Mantém TTL/cache do [ApiService].
  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _celebrateMissionId = null;
      });
    }
    try {
      await AuthService().refreshMe();
    } catch (_) {
      // Mantém dados em cache se a API falhar (ex.: offline).
    }
    final currentUser = AuthService().currentUser;
    if (!mounted) return;
    setState(() {
      _selectedUser = currentUser;
      if (currentUser != null) {
        _syncingHomeData = true;
      }
    });
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncingHomeData = false;
        _pendingConfirmationsCount = 0;
      });
      widget.onPendingConfirmationsCountChanged?.call(0);
      return;
    }

    final level = _levelFromGraduation(currentUser.graduation);
    final shouldHydrateDisk = _missionWeek == null ||
        _userLevel == null ||
        (_academyLogoUrl == null || _academyLogoUrl!.isEmpty);

    if (shouldHydrateDisk) {
      final snap = await _snapshotStore.read(
        userId: currentUser.id,
        academyId: currentUser.academyId,
        levelKey: level,
      );
      if (snap != null && mounted) {
        _applyHeaderStatsMap(snap.header);
        setState(() {
          _missionWeek = snap.week;
          if (!silent) _loading = false;
        });
        final logoUrl =
            (snap.header['academy'] as Map<String, dynamic>?)?['logo_url']
                as String?;
        unawaited(_precacheAcademyLogo(logoUrl));
      }
    }

    try {
      Map<String, dynamic>? headerMap;
      MissionWeek? weekForSnapshot;

      await Future.wait([
        _loadHeaderStatsWith().then((m) {
          headerMap = m;
        }),
        _loadMissionWeekWith(currentUser.academyId, level).then((w) {
          weekForSnapshot = w;
        }),
        _loadCollectiveGoalWith(currentUser.academyId),
        _loadPendingConfirmationsWith(),
      ]);

      if (headerMap == null) {
        await Future.wait([
          _loadUserPointsWith(currentUser.id),
          _loadAcademyLogoWith(currentUser.academyId),
        ]);
      }

      if (mounted) {
        setState(() {
          _selectedUser = AuthService().currentUser;
          _loading = false;
          _syncingHomeData = false;
        });
        if (headerMap != null && weekForSnapshot != null) {
          await _snapshotStore.write(
            userId: currentUser.id,
            academyId: currentUser.academyId,
            levelKey: level,
            header: headerMap!,
            week: weekForSnapshot!,
          );
        }
        unawaited(_loadDailyVideo());
        await _runPostLoadNudges();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _syncingHomeData = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  /// Aviso da academia (se ativo), parceiro em destaque e lembrete de confirmações pendentes.
  Future<void> _runPostLoadNudges() async {
    await _maybeShowAcademyLoginNotice();
    await _maybeShowRandomPartnerHighlight();
    await _maybeShowPendingConfirmationsBottomSheet();
  }

  /// Utilizadores com [UserModel.academyId] na home (aluno, gestor ou admin com academia).
  Future<void> _maybeShowAcademyLoginNotice() async {
    if (!mounted) return;
    final auth = AuthService();
    if (auth.loginNoticeShown) return;
    final user = _selectedUser;
    final academyId = user?.academyId;
    if (academyId == null || academyId.isEmpty) return;
    if (!_loginNoticeActive) return;
    final body = _loginNoticeBody?.trim() ?? '';
    if (body.isEmpty) return;
    auth.markLoginNoticeShown();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AcademyLoginNoticeDialog(
        titleText: _loginNoticeTitle,
        bodyText: body,
        linkUrl: _loginNoticeUrl,
      ),
    );
  }

  Future<void> _maybeShowPendingConfirmationsBottomSheet() async {
    if (!mounted) return;
    if (_pendingBottomSheetShownThisSession) return;
    if (_pendingConfirmationsCount <= 0) return;
    _pendingBottomSheetShownThisSession = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _pendingConfirmationsCount <= 0) return;
    final n = _pendingConfirmationsCount;
    final u = _selectedUser;
    if (u == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmações pendentes',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                n == 1
                    ? 'Há 1 execução aguardando sua confirmação. Confirme para o colega ganhar os pontos.'
                    : 'Há $n execuções aguardando sua confirmação. Confirme para os colegas ganharem os pontos.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(ctx),
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPendingConfirmationsScreen();
                },
                icon: const Icon(Icons.how_to_reg_rounded),
                label: const Text('Ir confirmar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Depois'),
              ),
            ],
          ),
        );
      },
    );
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
      // Fallback do fluxo otimizado: preferir cache para reduzir latência percebida.
      final academy = await _api.getAcademy(academyId);
      if (!mounted) return;
      setState(() {
        _scheduleLocalVersion = DateTime.now().millisecondsSinceEpoch;
        _academyLogoUrl = academy.logoUrl;
        _academyScheduleImageUrl = academy.scheduleImageUrl;
        _showTrophies = academy.showTrophies;
        _showPartners = academy.showPartners;
        _showSchedule = academy.showSchedule;
        _showGlobalSupporters = academy.showGlobalSupporters;
        _loginNoticeTitle = academy.loginNoticeTitle;
        _loginNoticeBody = academy.loginNoticeBody;
        _loginNoticeUrl = academy.loginNoticeUrl;
        _loginNoticeActive = academy.loginNoticeActive;
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
          _loginNoticeTitle = null;
          _loginNoticeBody = null;
          _loginNoticeUrl = null;
          _loginNoticeActive = false;
        });
      }
    }
  }

  String? _absoluteMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    return rawUrl.startsWith('/') ? '${_api.baseUrl}$rawUrl' : rawUrl;
  }

  Future<void> _precacheAcademyLogo(String? rawUrl) async {
    final url = _absoluteMediaUrl(rawUrl);
    if (url == null) return;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (_) {
      // Falha de pre-cache não deve bloquear a renderização.
    }
  }

  void _applyHeaderStatsMap(Map<String, dynamic> data) {
    if (!mounted) return;
    final academy = data['academy'] as Map<String, dynamic>?;
    final logoUrl = academy?['logo_url'] as String?;
    setState(() {
      _userLevel = (data['reward_level'] as num?)?.toInt() ?? _userLevel ?? 1;
      _userPoints =
          (data['reward_level_points'] as num?)?.toInt() ?? _userPoints ?? 0;
      _nextLevelThreshold =
          (data['next_level_threshold'] as num?)?.toInt() ??
              _nextLevelThreshold ??
              kBaseLevelThreshold;
      _academyLogoUrl = logoUrl;
      _academyScheduleImageUrl = academy?['schedule_image_url'] as String?;
      _showTrophies = academy?['show_trophies'] as bool? ?? true;
      _showPartners = academy?['show_partners'] as bool? ?? true;
      _showSchedule = academy?['show_schedule'] as bool? ?? true;
      _showGlobalSupporters =
          academy?['show_global_supporters'] as bool? ?? true;
      _loginNoticeTitle = academy?['login_notice_title'] as String?;
      _loginNoticeBody = academy?['login_notice_body'] as String?;
      _loginNoticeUrl = academy?['login_notice_url'] as String?;
      _loginNoticeActive = academy?['login_notice_active'] as bool? ?? false;
    });
  }

  /// Retorna o mapa bruto em sucesso (para persistir snapshot); `null` se falhar.
  Future<Map<String, dynamic>?> _loadHeaderStatsWith() async {
    try {
      final data = await _api.getMeHeaderStats();
      if (!mounted) return null;
      final academy = data['academy'] as Map<String, dynamic>?;
      final logoUrl = academy?['logo_url'] as String?;
      _applyHeaderStatsMap(data);
      unawaited(_precacheAcademyLogo(logoUrl));
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<MissionWeek?> _loadMissionWeekWith(String? academyId, String level) async {
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
      return week;
    } catch (e) {
      if (mounted) {
        setState(() {
          _missionWeek = null;
          if (!e.toString().contains('404')) {
            _error = userFacingMessage(e);
          }
        });
      }
      return null;
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
      if (!mounted) return;
      final prev = _pendingConfirmationsCount;
      setState(() {
        if (count != prev) _pendingBannerDismissed = false;
        _pendingConfirmationsCount = count;
      });
      widget.onPendingConfirmationsCountChanged?.call(count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingConfirmationsCount = 0);
      widget.onPendingConfirmationsCountChanged?.call(0);
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
    final byHeader = await _loadHeaderStatsWith();
    if (byHeader != null) return;
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
    final openedMissionId = data.missionId;
    final trackCelebrate =
        openedMissionId != null && openedMissionId.isNotEmpty && !data.alreadyCompleted;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewScreen(data: data),
      ),
    );
    await _loadMissionWeek();
    await _loadUserPoints();
    await _loadCollectiveGoal();
    if (!mounted) return;
    if (trackCelebrate) {
      MissionToday? hit;
      for (final e in _missionWeek?.entries ?? const <MissionWeekSlot>[]) {
        if (e.mission?.missionId == openedMissionId) {
          hit = e.mission;
          break;
        }
      }
      if (hit != null && hit.alreadyCompleted) {
        setState(() => _celebrateMissionId = openedMissionId);
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() {
            if (_celebrateMissionId == openedMissionId) {
              _celebrateMissionId = null;
            }
          });
        });
      }
    }
  }

  void _openMissionFromPath(MissionToday m, String _) {
    final u = _selectedUser;
    if (u == null) return;
    _openLesson(
      LessonViewData(
        lessonId: m.lessonId,
        missionId: m.missionId,
        title: m.lessonTitle.isNotEmpty ? m.lessonTitle : m.techniqueName,
        description: m.description,
        videoUrl: m.videoUrl,
        userId: u.id,
        academyId: u.academyId,
        techniqueName: m.techniqueName,
        positionName: m.positionName,
        multiplier: m.multiplier,
        estimatedDurationSeconds: m.estimatedDurationSeconds,
        alreadyCompleted: m.alreadyCompleted,
      ),
    );
  }

  /// Vídeo do dia que pontua: primeiro da lista getTrainingVideosToday da academia do usuário.
  Future<void> _loadDailyVideo() async {
    try {
      final list = await _api.getTrainingVideosToday();
      if (!mounted) return;
      final academyId = AuthService().currentUser?.academyId?.trim();
      if (academyId == null || academyId.isEmpty) {
        setState(() {
          _dailyVideo = null;
          _dailyVideoPoints = 0;
          _dailyVideoCompleted = false;
        });
        return;
      }
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
    final showHeaderSkeleton =
        _syncingHomeData && _userLevel == null && u != null;
    final showMissionSkeleton = _syncingHomeData &&
        _missionWeek == null &&
        u != null &&
        (u.academyId != null && u.academyId!.isNotEmpty);

    return Scaffold(
      body: Stack(
        children: [
          const _FantasyBackground(),
          RefreshIndicator(
            onRefresh: () => _load(silent: true),
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(screenPadding, 0, screenPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeaderSkeleton)
                    const HomeHeaderLoadingSkeleton()
                  else
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
                  if (_pendingConfirmationsCount > 0 &&
                      !_pendingBannerDismissed &&
                      u != null) ...[
                    const SizedBox(height: 10),
                    _buildPendingConfirmationsBanner(),
                  ],
                  const SizedBox(height: 10),
                  if (u != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StreakWidget(
                        streakDays: u.loginStreakDays,
                        onOpenPointsRules: () => showPointsRulesSheet(context),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_collectiveGoal != null) ...[
                    _buildCollectiveGoalCard(),
                    const SizedBox(height: 14),
                  ],
                  if (showMissionSkeleton) ...[
                    const HomeMissionSectionSkeleton(),
                    const SizedBox(height: 14),
                  ] else if (_missionWeek != null &&
                      _missionWeek!.entries.isNotEmpty) ...[
                    _buildWeeklyMissionPathSection(),
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
                    if (_showTrophies) ...[
                      const SizedBox(height: 16),
                      _buildTrophiesHomeSection(),
                    ],
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
                  if (u != null) ...[
                    const SizedBox(height: 16),
                    _buildConfirmationsAndRequestsSection(),
                  ],
                ],
              ),
            ),
          ),
          if (u != null && _syncingHomeData)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  label: 'A sincronizar dados',
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    color: Theme.of(context).colorScheme.primary,
                  ),
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

  void _openPendingConfirmationsScreen() {
    final u = _selectedUser;
    if (u == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PendingConfirmationsScreen(
          userId: u.id,
          userName: _selectedUser?.name ?? _selectedUser?.email,
        ),
      ),
    ).then((_) => _loadPendingConfirmationsWith());
  }

  /// Banner sob o header: confirmações pendentes (fechar só oculta até o contador mudar).
  Widget _buildPendingConfirmationsBanner() {
    final n = _pendingConfirmationsCount;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.tertiary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: scheme.onTertiaryContainer,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n == 1
                        ? '1 confirmação pendente'
                        : '$n confirmações pendentes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confirme execuções em que você foi indicado como parceiro.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer.withValues(alpha: 0.9),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _openPendingConfirmationsScreen,
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Ocultar',
              onPressed: () =>
                  setState(() => _pendingBannerDismissed = true),
              icon: Icon(
                Icons.close_rounded,
                color: scheme.onTertiaryContainer,
              ),
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

  /// Título **Missões da semana** + caminho ●──●──● (técnicas + toque → lição).
  Widget _buildWeeklyMissionPathSection() {
    final week = _missionWeek;
    final u = _selectedUser;
    if (week == null || u == null) return const SizedBox.shrink();
    final entries = week.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Missões da semana',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: WeeklyMissionPath(
            slots: entries,
            onMissionTap: _openMissionFromPath,
            celebrateMissionId: _celebrateMissionId,
            onCelebrateComplete: () {
              if (mounted) {
                setState(() => _celebrateMissionId = null);
              }
            },
          ),
        ),
      ],
    );
  }

  /// Acordeom **Centro de treinamento** só quando há mensagem de missões ausentes.
  /// Com `missionWeek` carregado não há filhos aqui; troféus em [TrophiesHomeSection].
  Widget _buildMainAccordion() {
    final missionHint = _missionWeek == null &&
            !_loading &&
            !_syncingHomeData &&
            _selectedUser != null
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
        : null;
    if (missionHint == null) return const SizedBox.shrink();
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
            children: [missionHint],
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
          onTap: _openPendingConfirmationsScreen,
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

  Widget _buildTrophiesHomeSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final hasAcademy = u.academyId != null && u.academyId!.isNotEmpty;
    return TrophiesHomeSection(
      onOpenGallery: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => TrophyGalleryScreen(
            userId: userId,
            userName: _selectedUser?.name ?? _selectedUser?.email,
          ),
        ),
      ),
      onOpenClassmates: hasAcademy
          ? () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ClassmatesGalleryScreen(
                    academyId: u.academyId!,
                    currentUserId: userId,
                  ),
                ),
              )
          : null,
      showClassmatesRow: hasAcademy,
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

/// Fundo da home Campo de treinamento: gradiente espacial no escuro; claro alinhado ao scaffold.
class _FantasyBackground extends StatelessWidget {
  const _FantasyBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: FantasyTheme.missionHomeBackgroundDecoration(context),
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

