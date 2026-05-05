import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:viewer/screens/student/trophy_gallery_screen.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/student_home_snapshot_store.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/theme/fantasy_theme.dart';
import 'package:viewer/widgets/gamification/points_rules_sheet.dart';
import 'package:viewer/widgets/gamification/streak_widget.dart';
import 'package:viewer/widgets/gamification/weekly_mission_path.dart';
import 'package:viewer/widgets/header_widget.dart';
import 'package:viewer/widgets/academy_login_notice_dialog.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/widgets/layout/memo_section_label.dart';
import 'package:viewer/widgets/student/home_loading_skeleton.dart';
import 'package:viewer/widgets/account_frozen_banner.dart';
import 'package:viewer/widgets/student/student_rules_sheet.dart';
import 'package:viewer/widgets/student/academy_partners_training_banner.dart';

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
  /// Pré-seleção na UI antes de confirmar escolha de turma (`PUT /users/me/weekly-kit-choice`).
  String? _weeklyKitChoiceLocal;
  /// Durante PUT escolha + recarregar semana (missões da turma).
  bool _savingWeeklyTurmaChoice = false;
  int? _userPoints;
  int? _userLevel;
  int? _nextLevelThreshold;
  Map<String, dynamic>? _collectiveGoal;
  int _pendingConfirmationsCount = 0;
  /// Solicitações enviadas por mim com `pending_confirmation` ([ApiService.getMyExecutions]).
  int _myOutgoingPendingCount = 0;
  /// Esconde o banner até o contador mudar de valor (nova carga da API).
  bool _pendingBannerDismissed = false;
  /// Bottom sheet de lembrete só uma vez por vida do State (sessão na aba Campo de treinamento).
  bool _pendingBottomSheetShownThisSession = false;
  TrainingVideo? _dailyVideo;
  int _dailyVideoPoints = 0;
  bool _dailyVideoCompleted = false;
  bool _loading = true;
  String? _error;
  String? _academyLogoUrl;
  bool _showTrophies = true;
  bool _showPartners = true;
  /// Aviso ao logar (dados da academia; modal uma vez por sessão).
  String? _loginNoticeTitle;
  String? _loginNoticeBody;
  String? _loginNoticeUrl;
  bool _loginNoticeActive = false;
  /// Missão recém-concluída (pulso no [WeeklyMissionPath]); limpo após animar.
  String? _celebrateMissionId;
  /// Rede a sincronizar (header + missões, etc.): barra no topo e skeletons opcionais.
  bool _syncingHomeData = false;
  Future<List<Partner>>? _trainingPartnersFuture;
  Future<TrophyHomeSummary>? _trophySummaryFuture;

  void _setupTrainingPartnersFuture(String? academyId) {
    if (academyId == null || academyId.isEmpty) {
      _trainingPartnersFuture = null;
      return;
    }
    _trainingPartnersFuture = _api.getPartners(academyId);
  }

  void _setupTrophySummaryFuture(String? academyId) {
    if (academyId == null || academyId.isEmpty) {
      _trophySummaryFuture = null;
      return;
    }
    _trophySummaryFuture = _api.getTrophyHomeSummary();
  }

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

  void _notifyAccountFrozen() {
    if (!mounted) return;
    final r = AuthService().currentUser?.accountFreezeReason?.trim();
    AppFeedback.show(
      context,
      message: r != null && r.isNotEmpty
          ? r
          : 'Conta congelada. Regularize com a academia para treinar e pontuar.',
      type: AppFeedbackType.warning,
    );
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
      _setupTrainingPartnersFuture(currentUser?.academyId);
      _setupTrophySummaryFuture(currentUser?.academyId);
      if (currentUser != null) {
        _syncingHomeData = true;
      }
    });
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncingHomeData = false;
        _trainingPartnersFuture = null;
        _pendingConfirmationsCount = 0;
        _myOutgoingPendingCount = 0;
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
        unawaited(_runPostLoadNudges());
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

  /// Usuários com [UserModel.academyId] na home (aluno, gestor ou admin com academia).
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
        _academyLogoUrl = academy.logoUrl;
        _showTrophies = academy.showTrophies;
        _showPartners = academy.showPartners;
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
          _showTrophies = true;
          _showPartners = true;
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
      _showTrophies = academy?['show_trophies'] as bool? ?? true;
      _showPartners = academy?['show_partners'] as bool? ?? true;
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
      final results = await Future.wait([
        _api.getPendingConfirmationsCount(),
        _api.getMyExecutions(),
      ]);
      final pendingIn = results[0] as int;
      final myExec = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      final outgoing =
          myExec.where((e) => e['status'] == 'pending_confirmation').length;
      final prev = _pendingConfirmationsCount;
      setState(() {
        if (pendingIn != prev) _pendingBannerDismissed = false;
        _pendingConfirmationsCount = pendingIn;
        _myOutgoingPendingCount = outgoing;
      });
      widget.onPendingConfirmationsCountChanged?.call(pendingIn);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingConfirmationsCount = 0;
        _myOutgoingPendingCount = 0;
      });
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
    if (AuthService().isEffectiveStudentFrozen) {
      _notifyAccountFrozen();
      return;
    }
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
    if (AuthService().isEffectiveStudentFrozen) {
      _notifyAccountFrozen();
      return;
    }
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
    final frozenStudent =
        u != null && u.role == 'aluno' && u.accountFrozen;

    return Scaffold(
      body: Stack(
        children: [
          const _FantasyBackground(),
          RefreshIndicator(
            onRefresh: () => _load(silent: true),
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                screenPadding,
                0,
                screenPadding,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
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
                      onDailyVideoTap:
                          frozenStudent ? _notifyAccountFrozen : _onDailyVideoTap,
                      onOpenRules: () => showStudentRulesSheet(context),
                    ),
                  if (frozenStudent) ...[
                    const SizedBox(height: 10),
                    AccountFrozenBanner(reason: u.accountFreezeReason),
                  ],
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
                  if (_showPartners && _trainingPartnersFuture != null) ...[
                    const SizedBox(height: 10),
                    FutureBuilder<List<Partner>>(
                      future: _trainingPartnersFuture,
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? const <Partner>[];
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            list.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        if (snapshot.hasError || list.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return AcademyPartnersTrainingBanner(partners: list);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_collectiveGoal != null) ...[
                    _buildCollectiveGoalCard(),
                    const SizedBox(height: 14),
                  ],
                  if (showMissionSkeleton) ...[
                    const HomeMissionSectionSkeleton(),
                    const SizedBox(height: 14),
                  ] else if (_missionWeek?.needsKitChoice == true &&
                      _missionWeek!.availableKits.isNotEmpty) ...[
                    _buildWeeklyKitChoiceSection(),
                    const SizedBox(height: 14),
                  ] else if (_missionWeek != null &&
                      _missionWeek!.entries.any((e) => e.mission != null)) ...[
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
                      const SizedBox(height: AppSpacing.l),
                    ],
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

  void _openPendingConfirmationsScreen() {
    final u = _selectedUser;
    if (u == null) return;
    if (AuthService().isEffectiveStudentFrozen) {
      _notifyAccountFrozen();
      return;
    }
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
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.secondary,
                          backgroundColor:
                              scheme.secondaryContainer.withValues(alpha: 0.65),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
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

  /// Escolha da turma da semana quando a academia usa turmas (1–5 técnicas).
  Widget _buildWeeklyKitChoiceSection() {
    final week = _missionWeek;
    final u = _selectedUser;
    if (week == null || u == null) return const SizedBox.shrink();
    final options = week.availableKits;
    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Text(
          'A academia ainda não configurou turmas válidas (1–5 técnicas) para esta semana.',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }
    final groupValue = _weeklyKitChoiceLocal ?? week.selectedKitId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Turma da semana',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Escolha a turma que vai treinar mais vezes essa semana.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
        if (_savingWeeklyTurmaChoice) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: AppTheme.borderOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A preparar as missões da turma…',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Column(
            children: [
              for (final k in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: groupValue == k.kitId
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _savingWeeklyTurmaChoice ||
                              AuthService().isEffectiveStudentFrozen
                          ? null
                          : () => setState(() => _weeklyKitChoiceLocal = k.kitId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              groupValue == k.kitId
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 22,
                              color: groupValue == k.kitId
                                  ? Theme.of(context).colorScheme.primary
                                  : AppTheme.textSecondaryOf(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    k.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${k.itemCount} técnica(s)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: switch (groupValue) {
                  null => null,
                  final g => _savingWeeklyTurmaChoice ||
                          AuthService().isEffectiveStudentFrozen
                      ? null
                      : () async {
                          if (AuthService().isEffectiveStudentFrozen) {
                            _notifyAccountFrozen();
                            return;
                          }
                          setState(() => _savingWeeklyTurmaChoice = true);
                          try {
                            await _api.putWeeklyKitChoice(kitId: g);
                            if (!mounted) return;
                            setState(() => _weeklyKitChoiceLocal = null);
                            await _loadMissionWeek();
                          } catch (e) {
                            if (!mounted) return;
                            AppFeedback.show(
                              context,
                              message: userFacingMessage(e),
                              type: AppFeedbackType.error,
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _savingWeeklyTurmaChoice = false);
                            }
                          }
                        },
                },
                child: _savingWeeklyTurmaChoice
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar turma'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Título **Missões da semana** + caminho ●──●──● (técnicas + toque → lição).
  Widget _buildWeeklyMissionPathSection() {
    final week = _missionWeek;
    final u = _selectedUser;
    if (week == null || u == null) return const SizedBox.shrink();
    final entries = week.entries.where((e) => e.mission != null).toList();
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
  /// Com `missionWeek` carregado não há filhos aqui; troféus em grelha tipo Central / Presença.
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

  Widget _buildConfirmationsAndRequestsSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final pending = _pendingConfirmationsCount;
    final outgoing = _myOutgoingPendingCount;

    /// Rodapés discretos (surface + borda tema), texto como subtítulo do header ("Construa consistência…").
    Widget neutralFooterChip(String label) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: FantasyTheme.textSecondaryOf(context),
              ),
        ),
      );
    }

    Widget footerPointsLogBadge() => neutralFooterChip('Ver histórico');

    Widget footerPendingBadge() =>
        neutralFooterChip(pending > 0 ? '$pending pendentes' : 'Em dia');

    Widget footerRequestsBadge() => neutralFooterChip(
          outgoing > 0 ? '$outgoing enviadas' : 'Nenhuma pendente',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MemoSectionLabel('CONFIRMAÇÕES E SOLICITAÇÕES'),
        const SizedBox(height: AppSpacing.s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MemoPresenceStyleTrophyCard(
                    enabled: true,
                    icon: Icons.how_to_reg_rounded,
                    title: 'Confirmações pendentes',
                    subtitle: 'Confirmar execuções em você',
                    footer: footerPendingBadge(),
                    onTap: _openPendingConfirmationsScreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: _MemoPresenceStyleTrophyCard(
                    enabled: true,
                    icon: Icons.send_rounded,
                    title: 'Minhas solicitações',
                    subtitle: 'Status das confirmações que você pediu',
                    footer: footerRequestsBadge(),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            MyExecutionsScreen(userId: userId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MemoPresenceStyleTrophyCard(
                    enabled: true,
                    icon: Icons.list_alt_rounded,
                    title: 'Log de pontuação',
                    subtitle: 'Histórico de pontos ganhos',
                    footer: footerPointsLogBadge(),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => PointsLogScreen(
                          userId: userId,
                          userName:
                              _selectedUser?.name ?? _selectedUser?.email,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrophiesHomeSection() {
    final u = _selectedUser;
    if (u == null) return const SizedBox.shrink();
    final userId = u.id;
    final hasAcademy = u.academyId != null && u.academyId!.isNotEmpty;

    void openGallery() {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => TrophyGalleryScreen(
            userId: userId,
            userName: _selectedUser?.name ?? _selectedUser?.email,
          ),
        ),
      );
    }

    void openClassmates() {
      if (!hasAcademy) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ClassmatesGalleryScreen(
            academyId: u.academyId!,
            currentUserId: userId,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MemoSectionLabel('TROFÉUS'),
        const SizedBox(height: AppSpacing.s),
        FutureBuilder<TrophyHomeSummary>(
          future: _trophySummaryFuture,
          builder: (context, snap) {
            final summary = snap.data;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MemoPresenceStyleTrophyCard(
                    enabled: true,
                    icon: Icons.emoji_events_outlined,
                    title: 'Galeria de troféus',
                    subtitle: 'Conquistas ouro, prata e bronze',
                    onTap: openGallery,
                    footer: summary != null && summary.myRecent.isNotEmpty
                        ? _TrophyPillsRow(
                            items: summary.myRecent
                                .map((t) => '${t.emoji} ${t.name}')
                                .toList(),
                            extra: summary.myEarnedCount - summary.myRecent.length,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: _MemoPresenceStyleTrophyCard(
                    enabled: hasAcademy,
                    icon: Icons.groups_outlined,
                    title: 'Galeria dos colegas',
                    subtitle: 'Troféus e medalhas da academia',
                    onTap: openClassmates,
                    footer: summary != null && summary.academyRecent.isNotEmpty
                        ? _AcademyRecentFooter(items: summary.academyRecent)
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

}

/// Cartão compacto com ícone Material em círculo (primary suave), igual ao [MemoCompactTileCard] da Central.
class _MemoPresenceStyleTrophyCard extends StatelessWidget {
  const _MemoPresenceStyleTrophyCard({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.footer,
    required this.onTap,
  });

  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconBg = scheme.primary.withValues(alpha: 0.1);

    // Cor e hierarquia alinhadas ao cumprimento «Olá, …!» no [HeaderWidget].
    final titleStyleBase = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: FantasyTheme.textPrimaryOf(context),
        );
    final subtitleStyleBase = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          height: 1.25,
        );

    final inner = Material(
      color: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: AppTheme.borderOf(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              AppSpacing.verticalS,
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyleBase?.copyWith(fontSize: 13.5),
              ),
              AppSpacing.verticalXs,
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyleBase?.copyWith(
                  color: AppTheme.textMutedOf(context),
                ),
              ),
              if (footer != null) ...[
                AppSpacing.verticalS,
                footer!,
              ],
            ],
          ),
        ),
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadow.card(context),
      ),
      child: inner,
    );

    if (enabled) return decorated;
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(child: decorated),
    );
  }
}

/// Linha de pills "🥇 Nome do troféu" com indicador +N para conquistas extras.
class _TrophyPillsRow extends StatelessWidget {
  const _TrophyPillsRow({required this.items, required this.extra});
  final List<String> items;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.textMutedOf(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final label in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (extra > 0)
          Text('+$extra', style: style?.copyWith(color: muted)),
      ],
    );
  }
}

/// Footer do card "Galeria dos colegas": avatares de iniciais + pills com nome e tier.
class _AcademyRecentFooter extends StatelessWidget {
  const _AcademyRecentFooter({required this.items});
  final List<AcademyRecentItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = AppTheme.textMutedOf(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5);

    // Avatares únicos por userId (máx 4 + indicador)
    final seen = <String>{};
    final unique = items.where((i) => seen.add(i.userId)).toList();
    final avatarCount = unique.length.clamp(0, 4);
    final avatarExtra = unique.length - avatarCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < avatarCount; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: scheme.primary.withValues(alpha: 0.18),
                  child: Text(
                    unique[i].initials,
                    style: TextStyle(fontSize: 9, color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (avatarExtra > 0)
              Text('+$avatarExtra', style: labelStyle?.copyWith(color: muted)),
            const SizedBox(width: 4),
            Text('conquistas recentes', style: labelStyle?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final item in items.take(3))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${item.tierEmoji} ${item.firstName}',
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (items.length > 3)
              Text('+${items.length - 3}', style: labelStyle?.copyWith(color: muted)),
          ],
        ),
      ],
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
                child: CachedNetworkImage(
                  imageUrl: partner.logoUrl!.startsWith('/')
                      ? '${api.baseUrl}${partner.logoUrl}'
                      : partner.logoUrl!,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    height: 72,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
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

