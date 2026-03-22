import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/student/partners_screen.dart';
import 'package:viewer/screens/student/student_home_screen.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/theme/fantasy_theme.dart';
import 'package:viewer/widgets/header_widget.dart';
import 'package:viewer/widgets/mission_card.dart';
import 'package:viewer/widgets/partners_card.dart';
import 'package:viewer/widgets/schedule_card.dart';
import 'package:viewer/widgets/today_academy_card.dart';
import 'package:viewer/core/leveling.dart';

/// Página inicial no estilo fantasia / academia medieval.
/// Dados reais: usuário, pontos, brasão da academia, vídeo diário que pontua.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _api = ApiService();

  UserModel? _user;
  int? _userPoints;
  int? _userLevel;
  int? _nextLevelThreshold;
  String? _academyLogoUrl;
  TrainingVideo? _dailyVideo;
  int _dailyVideoPoints = 0;
  bool _dailyVideoCompleted = false;
  bool _loading = true;
  String? _lastUserId;

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
    if (state == AppLifecycleState.resumed && _user != null) {
      _loadUserPoints();
      _loadDailyVideo();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _user = null;
      _userPoints = null;
      _userLevel = null;
      _nextLevelThreshold = null;
      _academyLogoUrl = null;
      _dailyVideo = null;
      _dailyVideoPoints = 0;
      _dailyVideoCompleted = false;
    });
    try {
      await AuthService().refreshMe();
    } catch (_) {}
    final currentUser = AuthService().currentUser;
    setState(() => _user = currentUser);
    if (currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      await Future.wait([
        _loadUserPointsWith(currentUser.id),
        _loadAcademyLogoWith(currentUser.academyId),
        _loadDailyVideo(),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

  Future<void> _loadUserPoints() async {
    if (_user == null) return;
    await _loadUserPointsWith(_user!.id);
  }

  Future<void> _loadAcademyLogoWith(String? academyId) async {
    if (academyId == null || academyId.isEmpty) {
      if (mounted) setState(() => _academyLogoUrl = null);
      return;
    }
    try {
      final academy = await _api.getAcademyFresh(academyId);
      if (!mounted) return;
      final url = academy.logoUrl;
      setState(() => _academyLogoUrl = url != null && url.isNotEmpty
          ? (url.startsWith('/') ? '${_api.baseUrl}$url' : url)
          : null);
    } catch (_) {
      if (mounted) setState(() => _academyLogoUrl = null);
    }
  }

  /// Vídeo do dia que pontua: primeiro da lista getTrainingVideosToday da academia do usuário.
  Future<void> _loadDailyVideo() async {
    final academyId = _user?.academyId;
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

  static String? _faixaLabel(String? g) {
    if (g == null || g.isEmpty) return null;
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
    final auth = context.watch<AuthService>();
    final effectiveUser = auth.currentUser;
    final user = _user ?? effectiveUser;

    // Se o usuário efetivo mudou (login ou "Atuar como"),
    // recarregamos os dados da home para refletir o novo perfil.
    if (effectiveUser?.id != _lastUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastUserId = effectiveUser?.id;
        _load();
      });
    }
    final academyId = user?.academyId;
    final screenPadding = AppTheme.screenPadding(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppTheme.breakpointTablet;

    if (_loading && user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: FantasyTheme.gold),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _FantasyBackground()),
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
                    userName: user?.name ?? 'Perin',
                    userBelt: _faixaLabel(user?.graduation) ?? 'Preta',
                    userLevel: _userLevel ?? 1,
                    currentXp: _userPoints ?? 0,
                    maxXp: _nextLevelThreshold ?? kBaseLevelThreshold,
                    academyLogoUrl: _academyLogoUrl,
                    dailyVideoPoints: _dailyVideoPoints,
                    dailyVideoCompleted: _dailyVideoCompleted,
                    onDailyVideoTap: _onDailyVideoTap,
                  ),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              MissionCard(onTap: () => _openMissions(context)),
                              const SizedBox(height: 16),
                              PartnersCard(
                                onTap: academyId != null && academyId.isNotEmpty
                                    ? () => _openPartners(context, academyId)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              ScheduleCard(onTap: () => _openSchedule(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 320,
                          child: TodayAcademyCard(
                              onTap: () => _openTodayAcademy(context)),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        MissionCard(onTap: () => _openMissions(context)),
                        const SizedBox(height: 16),
                        PartnersCard(
                          onTap: academyId != null && academyId.isNotEmpty
                              ? () => _openPartners(context, academyId)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        ScheduleCard(onTap: () => _openSchedule(context)),
                        const SizedBox(height: 16),
                        TodayAcademyCard(
                            onTap: () => _openTodayAcademy(context)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Centro de treinamento: abre a tela com Missões da semana, Troféus e Confirmações e solicitações.
  void _openMissions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const StudentHomeScreen(refreshTrigger: 0),
      ),
    ).then((_) {
      _loadUserPoints();
      _loadDailyVideo();
    });
  }

  void _openPartners(BuildContext context, String academyId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PartnersScreen(academyId: academyId),
      ),
    );
  }

  Future<void> _openSchedule(BuildContext context) async {
    final user = AuthService().currentUser;
    final academyId = user?.academyId;
    if (academyId == null || academyId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Vincule-se a uma academia para ver horários.')),
        );
      }
      return;
    }
    try {
      final academy = await _api.getAcademyFresh(academyId);
      final url = academy.scheduleImageUrl;
      if (url != null && url.isNotEmpty && context.mounted) {
        final fullUrl = url.startsWith('/') ? '${_api.baseUrl}$url' : url;
        final uri = Uri.tryParse(
            fullUrl.startsWith('http') ? fullUrl : 'https://$fullUrl');
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Horários não disponíveis no momento.')),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horários não disponíveis no momento.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir os horários.')),
        );
      }
    }
  }

  void _openTodayAcademy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FantasyTheme.cardSurfaceTop,
        shape: RoundedRectangleBorder(
          borderRadius: FantasyTheme.cardBorderRadius,
        ),
        title: const Text(
          'Thomas Hobbes — Leviatã',
          style: TextStyle(color: FantasyTheme.textPrimary),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'No estado de natureza, a vida seria "solitária, pobre, sórdida, '
            'odiosa e curta... Para escapar dessa situação e garantir a '
            'segurança pessoal, o indivíduo concordaria em formar um Estado, '
            'transferindo todos os seus direitos ao soberano (ou Leviatã), '
            'exceto o direito à vida.',
            style: TextStyle(
              color: FantasyTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(color: FantasyTheme.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fundo: imagem espacial ou gradiente escuro como fallback.
class _FantasyBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/background_stars.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: FantasyTheme.backgroundGradient,
        ),
      ),
    );
  }
}
