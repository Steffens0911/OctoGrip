import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/student/featured_partners_banner.dart';

import 'package:viewer/screens/student/attendance_my_stats_screen.dart';
import 'package:viewer/screens/student/attendance_scan_screen.dart';
import 'package:viewer/screens/student/marketplace_screen.dart';
import 'package:viewer/screens/student/partners_screen.dart';

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

  Widget _entry({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final academyId = user?.academyId;
    final hasAcademy = academyId != null && academyId.isNotEmpty;

    final showPartners = _flagFromHeaderStats('show_partners', fallback: true);
    final showSchedule = _flagFromHeaderStats('show_schedule', fallback: true);
    final scheduleUrl = _scheduleUrlFromHeaderStats();

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
          padding: const EdgeInsets.all(16),
          children: [
            if (_featuredFuture != null)
              Padding(
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

            if (showPartners)
              _entry(
                icon: Icons.handshake_outlined,
                title: 'Parceiros',
                subtitle: 'Conheça os parceiros da academia',
                enabled: hasAcademy,
                onTap: () => _requireAcademy(
                  onOk: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => PartnersScreen(academyId: academyId!),
                    ),
                  ),
                ),
              ),

            if (showSchedule)
              _entry(
                icon: Icons.schedule_rounded,
                title: 'Horário da academia',
                subtitle: 'Abra o quadro de horários',
                enabled: hasAcademy && scheduleUrl != null && scheduleUrl.isNotEmpty,
                onTap: () => _requireAcademy(onOk: () => _openScheduleUrl(scheduleUrl)),
              ),

            _entry(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Chamada por QR',
              subtitle: 'Escanear QR para registrar presença no treino',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (context) => const AttendanceScanScreen()),
              ),
            ),

            _entry(
              icon: Icons.insights_rounded,
              title: 'Minha frequência',
              subtitle: 'Veja seu histórico e gráficos de presença',
              enabled: hasAcademy,
              onTap: () => _requireAcademy(
                onOk: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (context) => const AttendanceMyStatsScreen()),
                ),
              ),
            ),

            _entry(
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

