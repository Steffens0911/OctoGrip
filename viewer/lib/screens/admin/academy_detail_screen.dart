import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/constants/reward_points.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';
import 'package:file_picker/file_picker.dart';
import 'package:viewer/screens/admin/academy_active_students_screen.dart';
import 'package:viewer/screens/admin/academy_points_edit_screen.dart';
import 'package:viewer/screens/admin/partner_list_screen.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';
import 'package:viewer/screens/admin/trophy_list_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Detalhe da academia: missão do dia (técnica), ranking, dificuldades, relatório semanal.
class AcademyDetailScreen extends StatefulWidget {
  final Academy academy;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const AcademyDetailScreen({
    super.key,
    required this.academy,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<AcademyDetailScreen> createState() => _AcademyDetailScreenState();
}

class _AcademyDetailScreenState extends State<AcademyDetailScreen> {
  final ApiService _api = ApiService();
  late Academy _academy;
  List<Technique> _techniques = [];
  String? _weeklyTechniqueId;
  String? _weeklyTechnique2Id;
  String? _weeklyTechnique3Id;
  int _weeklyMultiplier1 = minRewardPoints;
  int _weeklyMultiplier2 = minRewardPoints;
  int _weeklyMultiplier3 = minRewardPoints;
  late final TextEditingController _mult1Controller;
  late final TextEditingController _mult2Controller;
  late final TextEditingController _mult3Controller;
  bool _loadingTechniques = true;
  bool _savingTheme = false;
  bool _resetting = false;
  Map<String, dynamic>? _ranking;
  AcademyWeeklyReport? _weeklyReport;
  bool _loadingExtra = true;
  String? _errorExtra;
  UsageMetrics? _usageMetrics;
  bool _loadingUsageMetrics = false;
  String? _errorUsageMetrics;
  WeeklyPanelLoginsReport? _weeklyPanelLogins;
  bool _loadingWeeklyPanelLogins = false;
  String? _errorWeeklyPanelLogins;
  late final TextEditingController _logoUrlController;
  bool _uploadingLogo = false;
  bool _uploadingScheduleImage = false;
  bool _showTrophies = true;
  bool _showPartners = true;
  bool _showSchedule = true;
  bool _savingVisibility = false;
  bool _showGlobalSupporters = true;
  int? _scheduleImageCacheBuster;
  late final TextEditingController _loginNoticeTitleController;
  late final TextEditingController _loginNoticeBodyController;
  late final TextEditingController _loginNoticeUrlController;
  bool _loginNoticeActive = false;
  bool _savingLoginNotice = false;

  @override
  void initState() {
    super.initState();
    _academy = widget.academy;
    _weeklyTechniqueId = _academy.weeklyTechniqueId;
    _weeklyTechnique2Id = _academy.weeklyTechnique2Id;
    _weeklyTechnique3Id = _academy.weeklyTechnique3Id;
    _weeklyMultiplier1 = clampRewardPoints(_academy.weeklyMultiplier1);
    _weeklyMultiplier2 = clampRewardPoints(_academy.weeklyMultiplier2);
    _weeklyMultiplier3 = clampRewardPoints(_academy.weeklyMultiplier3);
    _mult1Controller = TextEditingController(text: _weeklyMultiplier1.toString());
    _mult2Controller = TextEditingController(text: _weeklyMultiplier2.toString());
    _mult3Controller = TextEditingController(text: _weeklyMultiplier3.toString());
    _logoUrlController = TextEditingController(text: _academy.logoUrl ?? '');
    _showTrophies = _academy.showTrophies;
    _showPartners = _academy.showPartners;
    _showSchedule = _academy.showSchedule;
    _showGlobalSupporters = _academy.showGlobalSupporters;
    _loginNoticeTitleController =
        TextEditingController(text: _academy.loginNoticeTitle ?? '');
    _loginNoticeBodyController =
        TextEditingController(text: _academy.loginNoticeBody ?? '');
    _loginNoticeUrlController =
        TextEditingController(text: _academy.loginNoticeUrl ?? '');
    _loginNoticeActive = _academy.loginNoticeActive;
    _loadTechniques();
    _loadRankingAndReport();
    _loadUsageMetrics();
    _loadWeeklyPanelLogins();
  }

  @override
  void dispose() {
    _mult1Controller.dispose();
    _mult2Controller.dispose();
    _mult3Controller.dispose();
    _logoUrlController.dispose();
    _loginNoticeTitleController.dispose();
    _loginNoticeBodyController.dispose();
    _loginNoticeUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadTechniques() async {
    if (mounted) setState(() => _loadingTechniques = true);
    try {
      _api.invalidateCache('GET:${_api.baseUrl}/techniques');
      final list = await _api.getTechniques(
        academyId: _academy.id,
        cacheBust: true,
      );
      if (mounted) {
        setState(() {
          _techniques = list;
          _loadingTechniques = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTechniques = false);
    }
  }

  Future<void> _loadRankingAndReport() async {
    setState(() {
      _loadingExtra = true;
      _errorExtra = null;
    });
    try {
      final ranking = await _api.getAcademyRanking(_academy.id);
      await _api.getAcademyDifficulties(_academy.id);
      final report = await _api.getAcademyWeeklyReport(_academy.id);
      if (mounted) {
        setState(() {
        _ranking = ranking;
        _weeklyReport = report;
        _loadingExtra = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _errorExtra = userFacingMessage(e);
        _loadingExtra = false;
      });
      }
    }
  }

  Future<void> _loadUsageMetrics() async {
    setState(() {
      _loadingUsageMetrics = true;
      _errorUsageMetrics = null;
    });
    try {
      final metrics = await _api.getMetricsUsageForAcademy(_academy.id);
      if (!mounted) return;
      setState(() {
        _usageMetrics = metrics;
        _loadingUsageMetrics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorUsageMetrics = userFacingMessage(e);
        _loadingUsageMetrics = false;
      });
    }
  }

  Future<void> _loadWeeklyPanelLogins() async {
    setState(() {
      _loadingWeeklyPanelLogins = true;
      _errorWeeklyPanelLogins = null;
    });
    try {
      final report = await _api.getWeeklyPanelLoginsReport(
        referenceDate: DateTime.now(),
        academyId: _academy.id,
      );
      if (!mounted) return;
      setState(() {
        _weeklyPanelLogins = report;
        _loadingWeeklyPanelLogins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorWeeklyPanelLogins = userFacingMessage(e);
        _loadingWeeklyPanelLogins = false;
      });
    }
  }

  Future<void> _pickAndUploadLogo() async {
    setState(() {
      _uploadingLogo = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _uploadingLogo = false;
        });
        return;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _uploadingLogo = false;
        });
        return;
      }
      final updated = await _api.uploadAcademyLogo(
        _academy.id,
        file.bytes!,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _logoUrlController.text = updated.logoUrl ?? '';
        _uploadingLogo = false;
      });
      AppFeedback.show(
        context,
        message: 'Brasão da academia atualizado.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingLogo = false;
      });
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }
  Future<void> _pickAndUploadScheduleImage() async {
    setState(() {
      _uploadingScheduleImage = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _uploadingScheduleImage = false;
        });
        return;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _uploadingScheduleImage = false;
        });
        return;
      }
      final updated = await _api.uploadAcademyScheduleImage(
        _academy.id,
        file.bytes!,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _uploadingScheduleImage = false;
        _scheduleImageCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });
      _api.invalidateCache('GET:${_api.baseUrl}/academies');
      AppFeedback.show(
        context,
        message: 'Quadro de horários atualizado.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingScheduleImage = false;
      });
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  String _scheduleImageUrlWithCacheBuster() {
    final raw = _academy.scheduleImageUrl!;
    final base = raw.startsWith('/') ? '${_api.baseUrl}$raw' : raw;
    final v = (_scheduleImageCacheBuster ?? _academy.updatedAt ?? '').toString();
    if (v.isEmpty) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$v';
  }

  /// URL completa do logo (evita 404/HTML quando a API devolve path relativo).
  String _academyLogoFullUrl() {
    final raw = _academy.logoUrl!;
    return raw.startsWith('/') ? '${_api.baseUrl}$raw' : raw;
  }

  Future<void> _updateHomeVisibility({
    bool? showTrophies,
    bool? showPartners,
    bool? showSchedule,
    bool? showGlobalSupporters,
  }) async {
    if (_savingVisibility) return;
    setState(() {
      _savingVisibility = true;
      if (showTrophies != null) _showTrophies = showTrophies;
      if (showPartners != null) _showPartners = showPartners;
      if (showSchedule != null) _showSchedule = showSchedule;
      if (showGlobalSupporters != null) {
        _showGlobalSupporters = showGlobalSupporters;
      }
    });
    try {
      final updated = await _api.updateAcademy(
        _academy.id,
        showTrophies: _showTrophies,
        showPartners: _showPartners,
        showSchedule: _showSchedule,
        showGlobalSupporters: _showGlobalSupporters,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _showTrophies = updated.showTrophies;
        _showPartners = updated.showPartners;
        _showSchedule = updated.showSchedule;
        _showGlobalSupporters = updated.showGlobalSupporters;
        _savingVisibility = false;
      });
      AppFeedback.show(
        context,
        message: 'Visibilidade atualizada na tela do aluno.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingVisibility = false;
      });
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _saveLoginNotice() async {
    if (_savingLoginNotice) return;
    final body = _loginNoticeBodyController.text.trim();
    if (_loginNoticeActive && body.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Para ativar o aviso, preencha o texto do corpo.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    setState(() => _savingLoginNotice = true);
    try {
      final t = _loginNoticeTitleController.text.trim();
      final b = _loginNoticeBodyController.text.trim();
      final u = _loginNoticeUrlController.text.trim();
      final updated = await _api.updateAcademyLoginNotice(
        _academy.id,
        loginNoticeTitle: t.isEmpty ? null : t,
        loginNoticeBody: b.isEmpty ? null : b,
        loginNoticeUrl: u.isEmpty ? null : u,
        loginNoticeActive: _loginNoticeActive,
      );
      if (!context.mounted) return;
      setState(() {
        _academy = updated;
        _savingLoginNotice = false;
        _loginNoticeTitleController.text = updated.loginNoticeTitle ?? '';
        _loginNoticeBodyController.text = updated.loginNoticeBody ?? '';
        _loginNoticeUrlController.text = updated.loginNoticeUrl ?? '';
        _loginNoticeActive = updated.loginNoticeActive;
      });
      widget.onUpdated();
      final navCtx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navCtx.mounted) return;
        AppFeedback.show(
          navCtx,
          message: 'Aviso ao abrir o app atualizado.',
          type: AppFeedbackType.success,
        );
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _savingLoginNotice = false);
      final err = userFacingMessage(e);
      final navCtx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navCtx.mounted) return;
        AppFeedback.show(
          navCtx,
          message: err,
          type: AppFeedbackType.error,
        );
      });
    }
  }

  Future<void> _saveTheme() async {
    final e1 = int.tryParse(_mult1Controller.text.trim());
    final e2 = int.tryParse(_mult2Controller.text.trim());
    final e3 = int.tryParse(_mult3Controller.text.trim());
    if (e1 == null ||
        e2 == null ||
        e3 == null ||
        !isValidRewardPoints(e1) ||
        !isValidRewardPoints(e2) ||
        !isValidRewardPoints(e3)) {
      AppFeedback.show(
        context,
        message:
            'Pontuação de cada missão semanal deve estar entre $minRewardPoints e $maxRewardPoints.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    setState(() {
      _weeklyMultiplier1 = e1;
      _weeklyMultiplier2 = e2;
      _weeklyMultiplier3 = e3;
    });
    setState(() => _savingTheme = true);
    try {
      final updated = await _api.updateAcademyWeeklyMissions(
        _academy.id,
        weeklyTechniqueId: _weeklyTechniqueId,
        weeklyTechnique2Id: _weeklyTechnique2Id,
        weeklyTechnique3Id: _weeklyTechnique3Id,
        weeklyMultiplier1: _weeklyMultiplier1,
        weeklyMultiplier2: _weeklyMultiplier2,
        weeklyMultiplier3: _weeklyMultiplier3,
      );
      if (updated != null && mounted) {
        setState(() {
          _academy = updated;
          _weeklyTechniqueId = updated.weeklyTechniqueId;
          _weeklyTechnique2Id = updated.weeklyTechnique2Id;
          _weeklyTechnique3Id = updated.weeklyTechnique3Id;
          _weeklyMultiplier1 = updated.weeklyMultiplier1;
          _weeklyMultiplier2 = updated.weeklyMultiplier2;
          _weeklyMultiplier3 = updated.weeklyMultiplier3;
          _mult1Controller.text = _weeklyMultiplier1.toString();
          _mult2Controller.text = _weeklyMultiplier2.toString();
          _mult3Controller.text = _weeklyMultiplier3.toString();
          _logoUrlController.text = updated.logoUrl ?? '';
          _savingTheme = false;
        });
        widget.onUpdated();
        AppFeedback.show(
          context,
          message: _weeklyTechniqueId != null || _weeklyTechnique2Id != null || _weeklyTechnique3Id != null
              ? 'Missões semanais atualizadas para todos os alunos.'
              : 'Tema salvo.',
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingTheme = false);
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  Future<void> _resetMissions() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar missões'),
        content: const Text(
          'Reiniciar missões desta academia? Todos poderão fazer as posições novamente. '
          'A pontuação já conquistada será preservada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _resetting = true);
    try {
      final result = await _api.resetAcademyMissions(_academy.id);
      if (mounted) {
        setState(() => _resetting = false);
        final msg = result['message'] as String? ?? 'Missões reiniciadas. Pontuação preservada.';
        AppFeedback.show(
          context,
          message: msg,
          type: AppFeedbackType.success,
        );
        _loadRankingAndReport();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resetting = false);
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir academia?'),
        content: Text(
            'Remover "${_academy.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAcademy(_academy.id);
      if (mounted) widget.onDeleted();
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: _academy.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final nameController = TextEditingController(text: _academy.name);
              String? techniqueId = _academy.weeklyTechniqueId;
              await showDialog<void>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Editar academia'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Nome'),
                          ),
                          AppSpacing.verticalM,
                          DropdownButtonFormField<String>(
                            initialValue: techniqueId,
                            decoration: const InputDecoration(labelText: 'Missão do dia (técnica)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                              ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                            ],
                            onChanged: (v) => setDialogState(() => techniqueId = v),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(ctx);
                          try {
                            final updated = await _api.updateAcademy(
                              _academy.id,
                              name: name,
                              weeklyTechniqueId: techniqueId,
                            );
                            if (mounted) {
                              setState(() {
                                _academy = updated;
                                _weeklyTechniqueId = updated.weeklyTechniqueId;
                              });
                              widget.onUpdated();
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            AppFeedback.show(
                              context,
                              message: userFacingMessage(e),
                              type: AppFeedbackType.error,
                            );
                          }
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDelete();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
                  title: Text('Excluir academia',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRankingAndReport();
          await _loadTechniques();
          await _loadWeeklyPanelLogins();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: const Icon(Icons.edit_note, color: AppTheme.primary),
                  ),
                  title: const Text('Editar pontos dos alunos', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Ajustar pontuação manual dos alunos desta academia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AcademyPointsEditScreen(
                        academyId: _academy.id,
                        academyName: _academy.name,
                      ),
                    ),
                  ),
                ),
              ),
              AppSpacing.verticalM,
              if (AuthService().isAdmin() || AuthService().isManager() || AuthService().isSupervisor())
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: const Icon(Icons.insights_rounded, color: AppTheme.primary),
                    ),
                    title: const Text('Alunos ativos (últimos 7 dias)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Ver quem está usando o app recentemente nesta academia'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AcademyActiveStudentsScreen(
                          academy: _academy,
                        ),
                      ),
                    ),
                  ),
                ),
              AppSpacing.verticalM,
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  child: ExpansionTile(
                    title: Text(
                      'Posições e técnicas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    initiallyExpanded: false,
                    controlAffinity: ListTileControlAffinity.leading,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.alt_route_rounded),
                        title: const Text('Técnicas'),
                        subtitle:
                            const Text('Gerencie as técnicas desta academia'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TechniqueListScreen(
                                academyId: _academy.id,
                              ),
                            ),
                          );
                          if (mounted) {
                            await _loadTechniques();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.verticalM,
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  child: ExpansionTile(
                    title: Text(
                      'Troféus e missões semanais',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    initiallyExpanded: false,
                    controlAffinity: ListTileControlAffinity.leading,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: const Text('Troféus'),
                        subtitle: const Text('Gerencie os troféus desta academia'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => TrophyListScreen(
                                academyId: _academy.id,
                                academyName: _academy.name,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text('Missões semanais'),
                          childrenPadding: const EdgeInsets.all(16),
                          initiallyExpanded: false,
                          controlAffinity: ListTileControlAffinity.leading,
                          children: _buildWeeklyMissionsFormChildren(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.verticalM,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brasão / logo da academia',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_academy.logoUrl != null &&
                          _academy.logoUrl!.isNotEmpty) ...[
                        Center(
                          child: ClipRRect(
                            borderRadius: AppRadius.cardRadius,
                            child: Image.network(
                              _academyLogoFullUrl(),
                              height: 72,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 72,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: AppRadius.cardRadius,
                                ),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.verticalM,
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _uploadingLogo ? null : _pickAndUploadLogo,
                          icon: _uploadingLogo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload),
                          label: Text(_uploadingLogo ? 'Enviando...' : 'Selecionar imagem'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Quadro de horários (imagem opcional)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_academy.scheduleImageUrl != null &&
                          _academy.scheduleImageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: Image.network(
                              _scheduleImageUrlWithCacheBuster(),
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                alignment: Alignment.center,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.verticalM,
                      ],
                      if (AuthService().canEditResources())
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _uploadingScheduleImage ? null : _pickAndUploadScheduleImage,
                            icon: _uploadingScheduleImage
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload),
                            label: Text(_uploadingScheduleImage ? 'Enviando...' : 'Selecionar imagem'),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Apenas visualização. Apenas administradores, gestores e professores podem alterar.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (AuthService().isAdmin() || AuthService().isManager()) ...[
                AppSpacing.verticalM,
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: const Icon(Icons.handshake_outlined, color: AppTheme.primary),
                    ),
                    title: const Text('Parceiros', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Divulgação para os alunos: empresas e academias parceiras'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartnerListScreen(academy: _academy),
                      ),
                    ),
                  ),
                ),
              ],
              AppSpacing.verticalM,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visibilidade na tela do aluno',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Defina quais blocos aparecem na home dos alunos desta academia.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar troféus'),
                        subtitle: const Text('Exibe o acordeon de troféus na tela inicial do aluno.'),
                        value: _showTrophies,
                        onChanged: _savingVisibility
                            ? null
                            : (value) {
                                _updateHomeVisibility(showTrophies: value);
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar parceiros'),
                        subtitle: const Text('Exibe o acordeon de parceiros na tela inicial do aluno.'),
                        value: _showPartners,
                        onChanged: _savingVisibility
                            ? null
                            : (value) {
                                _updateHomeVisibility(showPartners: value);
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar horários da academia'),
                        subtitle: const Text('Exibe o quadro de horários na tela inicial (quando houver imagem configurada).'),
                        value: _showSchedule,
                        onChanged: _savingVisibility
                            ? null
                            : (value) {
                                _updateHomeVisibility(showSchedule: value);
                              },
                      ),
                      if (AuthService().isAdmin())
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar apoiadores do app'),
                          subtitle: const Text(
                            'Exibe o quadro de apoiadores do app (vídeos globais) no final da tela inicial do aluno.',
                          ),
                          value: _showGlobalSupporters,
                          onChanged: _savingVisibility
                              ? null
                              : (value) {
                                  _updateHomeVisibility(showGlobalSupporters: value);
                                },
                        ),
                    ],
                  ),
                ),
              ),
              AppSpacing.verticalM,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aviso ao abrir o app',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modal na tela inicial (Campo de treinamento), uma vez por sessão de login, '
                        'para todos os utilizadores com esta academia — antes do destaque de parceiros.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginNoticeTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Título (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 255,
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) =>
                            null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginNoticeBodyController,
                        decoration: const InputDecoration(
                          labelText: 'Texto do aviso',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 6,
                        maxLength: 8000,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginNoticeUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Link opcional',
                          hintText: 'https://…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar aviso ao abrir o app'),
                        subtitle: const Text(
                          'Só aparece se o texto do aviso estiver preenchido.',
                        ),
                        value: _loginNoticeActive,
                        onChanged: _savingLoginNotice
                            ? null
                            : (v) => setState(() => _loginNoticeActive = v),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _savingLoginNotice ? null : _saveLoginNotice,
                          child: _savingLoginNotice
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Guardar aviso'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ..._buildExtraSections(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWeeklyMissionsFormChildren() {
    return [
      Text(
        'Missões semanais (3 técnicas)',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        'As técnicas selecionadas aparecem como missões no painel do aluno enquanto estiverem configuradas.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
      ),
      AppSpacing.verticalM,
      if (_loadingTechniques)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
      else ...[
        DropdownButtonFormField<String>(
          initialValue: _weeklyTechniqueId,
          decoration: const InputDecoration(
            labelText: 'Missão 1',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
          ],
          onChanged: (v) => setState(() => _weeklyTechniqueId = v),
        ),
        AppSpacing.verticalM,
        DropdownButtonFormField<String>(
          initialValue: _weeklyTechnique2Id,
          decoration: const InputDecoration(
            labelText: 'Missão 2',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
          ],
          onChanged: (v) => setState(() => _weeklyTechnique2Id = v),
        ),
        AppSpacing.verticalM,
        DropdownButtonFormField<String>(
          initialValue: _weeklyTechnique3Id,
          decoration: const InputDecoration(
            labelText: 'Missão 3',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
          ],
          onChanged: (v) => setState(() => _weeklyTechnique3Id = v),
        ),
        AppSpacing.verticalM,
        Text(
          'Pontuação base (por slot)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = AppTheme.isNarrow(context);
            final fields = [
              TextFormField(
                controller: _mult1Controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Missão 1',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1) setState(() => _weeklyMultiplier1 = n);
                },
              ),
              TextFormField(
                controller: _mult2Controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Missão 2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && isValidRewardPoints(n)) {
                    setState(() => _weeklyMultiplier2 = n);
                  }
                },
              ),
              TextFormField(
                controller: _mult3Controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Missão 3',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1) setState(() => _weeklyMultiplier3 = n);
                },
              ),
            ];
            if (narrow) {
              return Column(
                children: fields
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: f,
                        ))
                    .toList(),
              );
            }
            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
                const SizedBox(width: 12),
                Expanded(child: fields[2]),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Valor por slot: $minRewardPoints–$maxRewardPoints pontos. '
          'Concluir missão no app usa esse valor fixo. '
          'Execuções confirmadas: base × faixa do oponente.',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
        AppSpacing.verticalM,
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = AppTheme.isNarrow(context);
            final saveBtn = FilledButton.icon(
              onPressed: _savingTheme ? null : _saveTheme,
              icon: _savingTheme
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_savingTheme ? 'Salvando...' : 'Salvar missões semanais'),
            );
            final resetBtn = OutlinedButton.icon(
              onPressed: _resetting ? null : _resetMissions,
              icon: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_resetting ? 'Reiniciando...' : 'Reiniciar missões'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  saveBtn,
                  const SizedBox(height: 8),
                  resetBtn,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: saveBtn),
                const SizedBox(width: 12),
                Expanded(child: resetBtn),
              ],
            );
          },
        ),
      ],
    ];
  }

  List<Widget> _buildExtraSections() {
    if (_loadingExtra) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_errorExtra != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                _errorExtra!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMutedOf(context)),
              ),
              AppSpacing.verticalM,
              TextButton.icon(
                onPressed: _loadRankingAndReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      const _SectionTitle(title: 'Ranking (últimos 30 dias)'),
      Card(
        child: _ranking != null && (_ranking!['entries'] as List).isNotEmpty
            ? ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_ranking!['entries'] as List).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = (_ranking!['entries'] as List)[i] as AcademyRankingEntry;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        '${e.rank}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(e.name ?? 'Sem nome'),
                    trailing: Text(
                      '${e.completionsCount} conclusões',
                      style: TextStyle(
                        color: AppTheme.textMutedOf(context),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhuma conclusão no período.',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
              ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Execuções focadas em troféu/medalha/posição'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingUsageMetrics
              ? const Center(child: CircularProgressIndicator())
              : _errorUsageMetrics != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorUsageMetrics!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loadUsageMetrics,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    )
                  : _usageMetrics == null
                      ? Text(
                          'Ainda não há respostas suficientes para este relatório.',
                          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                        )
                      : _AcademyUsageMetricsView(metrics: _usageMetrics!),
        ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Relatório semanal'),
      Card(
        child: _weeklyReport != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weeklyReport!.weekStart} a ${_weeklyReport!.weekEnd}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_weeklyReport!.completionsCount} conclusões · '
                      '${_weeklyReport!.activeUsersCount} ativos',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (_weeklyReport!.entries.isNotEmpty) ...[
                      AppSpacing.verticalM,
                      const Divider(),
                      ..._weeklyReport!.entries.map(
                        (e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            '${e.rank}º',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          title: Text(e.name ?? 'Sem nome'),
                          trailing: Text(
                            '${e.completionsCount}',
                            style: TextStyle(
                              color: AppTheme.textMutedOf(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Sem dados da semana.',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
              ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Logins na semana'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingWeeklyPanelLogins
              ? const Center(child: CircularProgressIndicator())
              : _errorWeeklyPanelLogins != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorWeeklyPanelLogins!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loadWeeklyPanelLogins,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    )
                  : _buildWeeklyPanelLoginsContent(),
        ),
      ),
    ];
  }

  Widget _buildWeeklyPanelLoginsContent() {
    final report = _weeklyPanelLogins;
    if (report == null) {
      return Text(
        'Ainda não há dados suficientes para este relatório.',
        style: TextStyle(color: AppTheme.textSecondaryOf(context)),
      );
    }
    final period = '${toBrDate(report.weekStart)} a ${toBrDate(report.weekEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          period,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '${report.usersLoggedAtLeastOnce} logaram ao menos 1 dia · '
          '${report.eligibleUsersCount} utilizadores (staff e alunos)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (report.users.isNotEmpty) ...[
          AppSpacing.verticalM,
          const Divider(),
          ...report.users.map(
            (u) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(u.name ?? u.email),
              subtitle: Text(
                u.distinctLoginDaysInWeek == 1
                    ? '1 dia com login'
                    : '${u.distinctLoginDaysInWeek} dias com login',
              ),
              trailing: Text(
                u.role,
                style: TextStyle(color: AppTheme.textMutedOf(context)),
              ),
            ),
          ),
        ] else ...[
          AppSpacing.verticalM,
          Text(
            'Ninguém da academia registou login nesta semana.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _AcademyUsageMetricsView extends StatelessWidget {
  final UsageMetrics metrics;

  const _AcademyUsageMetricsView({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final totalExecutions =
        metrics.beforeTrainingCount + metrics.afterTrainingCount;
    if (totalExecutions == 0) {
      return Text(
        'Nenhuma resposta registrada ainda para esta academia.',
        style: TextStyle(color: AppTheme.textSecondaryOf(context)),
      );
    }

    final plannedCount = metrics.afterTrainingCount;
    final naturalCount = metrics.beforeTrainingCount;
    final plannedPercent =
        totalExecutions > 0 ? (plannedCount / totalExecutions * 100) : 0.0;
    final naturalPercent =
        totalExecutions > 0 ? (naturalCount / totalExecutions * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalExecutions respostas registradas nesta academia',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Premeditadas (focando em troféu/medalha/posição): '
          '$plannedCount (${plannedPercent.toStringAsFixed(1)}%)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Naturais (aconteceu naturalmente): '
          '$naturalCount (${naturalPercent.toStringAsFixed(1)}%)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

