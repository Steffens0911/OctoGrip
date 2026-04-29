import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/student/featured_partners_banner.dart';

import 'package:viewer/screens/student/attendance_my_stats_screen.dart';
import 'package:viewer/screens/student/attendance_ranking_screen.dart';
import 'package:viewer/screens/student/attendance_scan_screen.dart';
import 'package:viewer/screens/student/marketplace_screen.dart';
import 'package:viewer/screens/student/partners_screen.dart';
import 'package:viewer/screens/student/user_avatar_screen.dart';

class StudentAcademyHubScreen extends StatefulWidget {
  const StudentAcademyHubScreen({super.key});

  @override
  State<StudentAcademyHubScreen> createState() => _StudentAcademyHubScreenState();
}

class _StudentAcademyHubScreenState extends State<StudentAcademyHubScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _headerStats;
  Future<List<GlobalPartner>>? _featuredFuture;

  @override
  void initState() {
    super.initState();
    _load();
    _setupFeaturedFuture();
  }

  void _setupFeaturedFuture() {
    _featuredFuture = _api.getFeaturedPartners();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getMeHeaderStats();
      if (!mounted) return;
      setState(() {
        _headerStats = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String? _scheduleUrlFromHeaderStats() {
    final hs = _headerStats;
    if (hs == null) return null;
    final academy = hs['academy'];
    if (academy is! Map<String, dynamic>) return null;
    final v = academy['schedule_image_url'];
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  bool _flagFromHeaderStats(String key, {required bool fallback}) {
    final hs = _headerStats;
    if (hs == null) return fallback;
    final academy = hs['academy'];
    if (academy is! Map<String, dynamic>) return fallback;
    final v = academy[key];
    return v is bool ? v : fallback;
  }

  Future<void> _openScheduleUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final baseUrl = url.startsWith('/') ? '${_api.baseUrl}$url' : url;
    final uri = Uri.tryParse(baseUrl.startsWith('http') ? baseUrl : 'https://$baseUrl');
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Horários não disponíveis no momento.',
        type: AppFeedbackType.warning,
      );
    }
  }

  void _requireAcademy({required VoidCallback onOk}) {
    final academyId = AuthService().currentUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Vincule-se a uma academia para acessar esta área.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    onOk();
  }

  void _pushAttendanceQr() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const AttendanceScanScreen()),
    );
  }

  void _pushAttendanceFrequency() {
    _requireAcademy(
      onOk: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (context) => const AttendanceMyStatsScreen()),
      ),
    );
  }

  void _pushAttendanceRanking(String? academyId) {
    _requireAcademy(
      onOk: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => AttendanceRankingScreen(academyId: academyId!),
        ),
      ),
    );
  }

  void _pushUserAvatarScreen() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => const UserAvatarScreen(),
      ),
    ).then((updated) {
      if (updated == true && mounted) _load();
    });
  }

  Widget _academyNavigationTile({
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTapWhenEnabled,
  }) {
    final tile = AppNavigationTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: enabled ? onTapWhenEnabled : () {},
    );
    if (!enabled) {
      return Opacity(
        opacity: 0.45,
        child: IgnorePointer(child: tile),
      );
    }
    return tile;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final academyId = user?.academyId;
    final hasAcademy = academyId != null && academyId.isNotEmpty;

    final showPartners = _flagFromHeaderStats('show_partners', fallback: true);
    final showSchedule = _flagFromHeaderStats('show_schedule', fallback: true);
    final scheduleUrl = _scheduleUrlFromHeaderStats();

    final scheduleEnabled =
        hasAcademy && scheduleUrl != null && scheduleUrl.isNotEmpty;

    // AppBar fica no [MainScaffold] (aba "Central"); evita barra extra com seta e título duplicado.
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _api.invalidateCache('GET:${_api.baseUrl}/partners/featured');
          setState(() => _setupFeaturedFuture());
          await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            if (_featuredFuture != null)
              Padding(
                // Mesmo recorte horizontal do banner de antes do redesenho (parceiros em destaque no topo).
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                child: FutureBuilder<List<GlobalPartner>>(
                  future: _featuredFuture,
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? const <GlobalPartner>[];
                    if (snapshot.connectionState == ConnectionState.waiting && list.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.hasError) return const SizedBox.shrink();
                    if (list.isEmpty) return const SizedBox.shrink();
                    return FeaturedPartnersBanner(partners: list);
                  },
                ),
              ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Não foi possível carregar dados da academia.\n\n$_error',
                  style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                ),
              ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s),
                const _HubSectionLabel('PRESENÇA'),
                const SizedBox(height: AppSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HubPresenceCard(
                        featured: true,
                        enabled: true,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Chamada por QR',
                        subtitle: 'Escanear QR para registrar presença no treino',
                        onTap: _pushAttendanceQr,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _HubPresenceCard(
                        featured: false,
                        enabled: true,
                        icon: Icons.face_retouching_natural_outlined,
                        title: 'Foto de perfil',
                        subtitle: 'Usada na chamada por reconhecimento facial',
                        onTap: _pushUserAvatarScreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HubPresenceCard(
                        featured: false,
                        enabled: hasAcademy,
                        icon: Icons.insights_rounded,
                        title: 'Minha frequência',
                        subtitle: 'Histórico e gráficos de presença',
                        onTap: hasAcademy ? _pushAttendanceFrequency : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _HubPresenceCard(
                        featured: false,
                        enabled: hasAcademy,
                        icon: Icons.emoji_events_outlined,
                        title: 'Ranking',
                        subtitle: 'Frequência da academia por período',
                        onTap: hasAcademy ? () => _pushAttendanceRanking(academyId) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                const _HubSectionLabel('ACADEMIA'),
                const SizedBox(height: AppSpacing.s),
              ],
            ),

            if (showPartners)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _academyNavigationTile(
                  enabled: hasAcademy,
                  icon: Icons.handshake_outlined,
                  title: 'Parceiros',
                  subtitle: 'Conheça os parceiros da academia',
                  onTapWhenEnabled: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => PartnersScreen(academyId: academyId!),
                    ),
                  ),
                ),
              ),

            if (showSchedule)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _academyNavigationTile(
                  enabled: scheduleEnabled,
                  icon: Icons.schedule_rounded,
                  title: 'Horário da academia',
                  subtitle: 'Abra o quadro de horários',
                  onTapWhenEnabled: () => _requireAcademy(onOk: () => _openScheduleUrl(scheduleUrl)),
                ),
              ),

            AppNavigationTile(
              icon: Icons.storefront_rounded,
              title: 'Loja da academia',
              subtitle: 'Produtos, preços e contato no WhatsApp',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (context) => const MarketplaceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label uppercase para secções da Central (Presença / Academia).
class _HubSectionLabel extends StatelessWidget {
  const _HubSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.45,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedOf(context),
            ),
      ),
    );
  }
}

/// Cartão compacto para atalhos de presença (destaque QR ou tile normal).
class _HubPresenceCard extends StatelessWidget {
  const _HubPresenceCard({
    required this.featured,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool featured;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final surface = featured
        ? scheme.primary.withValues(alpha: 0.14)
        : AppTheme.surfaceOf(context);

    final borderColor = featured
        ? scheme.primary.withValues(alpha: 0.42)
        : AppTheme.borderOf(context);

    final iconBg = featured
        ? scheme.primary.withValues(alpha: 0.26)
        : scheme.primary.withValues(alpha: 0.1);

    final titleStyleBase =
        Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyleBase = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          height: 1.25,
        );

    final titleColor =
        featured ? scheme.primary : AppTheme.textPrimaryOf(context);
    final subtitleColor = featured
        ? scheme.primary.withValues(alpha: 0.72)
        : AppTheme.textMutedOf(context);

    final inner = Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: borderColor, width: featured ? 1 : 0.5),
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
                  color: iconBg,
                  borderRadius: AppRadius.tileRadius,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              AppSpacing.verticalS,
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyleBase?.copyWith(color: titleColor, fontSize: 13.5),
              ),
              AppSpacing.verticalXs,
              Text(
                subtitle,
                maxLines: featured ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyleBase?.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
      ),
    );

    final decorated = featured ? inner : DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadow.card(context),
      ),
      child: inner,
    );

    final effective = enabled
        ? decorated
        : Opacity(
            opacity: 0.45,
            child: IgnorePointer(child: decorated),
          );

    return effective;
  }
}
