import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/constants/reward_points.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/models/weekly_kit.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';
import 'package:viewer/screens/admin/training_video_list_screen.dart';
import 'package:viewer/screens/admin/trophy_list_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/academy/training_field_sections.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Detalhe da academia: missão do dia (técnica), ranking, dificuldades, relatório semanal.
class AcademyDetailScreen extends StatefulWidget {
  final Academy academy;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;
  final bool trainingFieldOnly;

  const AcademyDetailScreen({
    super.key,
    required this.academy,
    required this.onUpdated,
    required this.onDeleted,
    this.trainingFieldOnly = false,
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
  bool _resettingTurmasWeek = false;
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
  /// Intervalo (datas locais) para ranking, conclusões e relatório de logins.
  late DateTime _reportPeriodStart;
  late DateTime _reportPeriodEnd;
  List<WeeklyKitRead> _weeklyKits = [];
  bool _loadingWeeklyKits = false;
  bool _showGlobalSupporters = true;
  bool _faceRecognitionEnabled = false;
  bool _qrAttendanceEnabled = true;
  bool _octophotosEnabled = false;
  int _userPhotosQuota = 30;
  bool _preCheckinEnabled = false;
  bool _preCheckinStrict = false;
  bool _faceCheckinEnabled = false;
  int _punctualityXp = 15;
  late TextEditingController _quotaController;
  late TextEditingController _punctualityXpController;
  bool _savingAdminPersonalization = false;

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
    _showGlobalSupporters = _academy.showGlobalSupporters;
    _faceRecognitionEnabled = _academy.faceRecognitionEnabled;
    _qrAttendanceEnabled = _academy.qrAttendanceEnabled;
    _octophotosEnabled = _academy.octophotosEnabled;
    _userPhotosQuota = _academy.userPhotosQuota;
    _preCheckinEnabled = _academy.preCheckinEnabled;
    _preCheckinStrict = _academy.preCheckinStrict;
    _faceCheckinEnabled = _academy.faceCheckinEnabled;
    _punctualityXp = _academy.punctualityXp;
    _quotaController = TextEditingController(text: _userPhotosQuota.toString());
    _punctualityXpController = TextEditingController(text: _punctualityXp.toString());
    _mult1Controller = TextEditingController(text: _weeklyMultiplier1.toString());
    _mult2Controller = TextEditingController(text: _weeklyMultiplier2.toString());
    _mult3Controller = TextEditingController(text: _weeklyMultiplier3.toString());
    final now = DateTime.now();
    _reportPeriodStart = _mondayOfIsoWeek(now);
    _reportPeriodEnd = _reportPeriodStart.add(const Duration(days: 6));
    _loadTechniques();
    _loadWeeklyKits(silentErrors: true);
    if (!widget.trainingFieldOnly) {
      _loadRankingAndReport();
      _loadUsageMetrics();
      _loadWeeklyPanelLogins();
      if (AuthService().isAdmin()) {
        _loadAdminPersonalizationFresh();
      }
    }
  }

  Future<void> _loadAdminPersonalizationFresh() async {
    try {
      final fresh = await _api.getAcademyFresh(_academy.id);
      if (!mounted) return;
      setState(() {
        _academy = fresh;
        _showGlobalSupporters = fresh.showGlobalSupporters;
        _faceRecognitionEnabled = fresh.faceRecognitionEnabled;
        _qrAttendanceEnabled = fresh.qrAttendanceEnabled;
        _octophotosEnabled = fresh.octophotosEnabled;
        _userPhotosQuota = fresh.userPhotosQuota;
        _preCheckinEnabled = fresh.preCheckinEnabled;
        _preCheckinStrict = fresh.preCheckinStrict;
        _faceCheckinEnabled = fresh.faceCheckinEnabled;
        _punctualityXp = fresh.punctualityXp;
        _quotaController.text = fresh.userPhotosQuota.toString();
        _punctualityXpController.text = fresh.punctualityXp.toString();
      });
    } catch (_) {
      // Mantém os dados já carregados no detalhe caso o refresh falhe.
    }
  }

  /// Igual a [academy_has_active_weekly_kits] no backend: pelo menos uma turma com 1–5 técnicas.
  bool _hasActiveTurmas() {
    for (final k in _weeklyKits) {
      final n = k.items.length;
      if (n >= 1 && n <= 5) return true;
    }
    return false;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOfIsoWeek(DateTime d) {
    final day = _dateOnly(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<void> _pickReportPeriodStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportPeriodStart,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    var start = _dateOnly(picked);
    var end = _reportPeriodEnd;
    if (start.isAfter(end)) end = start;
    setState(() {
      _reportPeriodStart = start;
      _reportPeriodEnd = end;
    });
    await _reloadPeriodReports();
  }

  Future<void> _pickReportPeriodEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportPeriodEnd,
      firstDate: _reportPeriodStart,
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    var end = _dateOnly(picked);
    var start = _reportPeriodStart;
    if (end.isBefore(start)) start = end;
    setState(() {
      _reportPeriodStart = start;
      _reportPeriodEnd = end;
    });
    await _reloadPeriodReports();
  }

  Future<void> _reloadPeriodReports() async {
    await _loadRankingAndReport();
    if (!mounted) return;
    await _loadWeeklyPanelLogins();
  }

  @override
  void dispose() {
    _mult1Controller.dispose();
    _mult2Controller.dispose();
    _mult3Controller.dispose();
    _quotaController.dispose();
    _punctualityXpController.dispose();
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
      final ranking = await _api.getAcademyRanking(
        _academy.id,
        periodStart: _reportPeriodStart,
        periodEnd: _reportPeriodEnd,
      );
      await _api.getAcademyDifficulties(_academy.id);
      final report = await _api.getAcademyWeeklyReport(
        _academy.id,
        startDate: _reportPeriodStart,
        endDate: _reportPeriodEnd,
      );
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
        startDate: _reportPeriodStart,
        endDate: _reportPeriodEnd,
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

  Future<void> _updateAdminPersonalization({
    bool? showGlobalSupporters,
    bool? faceRecognitionEnabled,
    bool? qrAttendanceEnabled,
    bool? octophotosEnabled,
    int? userPhotosQuota,
    bool? preCheckinEnabled,
    bool? preCheckinStrict,
    bool? faceCheckinEnabled,
    int? punctualityXp,
  }) async {
    if (_savingAdminPersonalization) return;
    final previousShowGlobalSupporters = _showGlobalSupporters;
    final previousFaceRecognitionEnabled = _faceRecognitionEnabled;
    final previousQrAttendanceEnabled = _qrAttendanceEnabled;
    final previousOctophotosEnabled = _octophotosEnabled;
    final previousUserPhotosQuota = _userPhotosQuota;
    final previousPreCheckinEnabled = _preCheckinEnabled;
    final previousPreCheckinStrict = _preCheckinStrict;
    final previousFaceCheckinEnabled = _faceCheckinEnabled;
    final previousPunctualityXp = _punctualityXp;
    setState(() {
      _savingAdminPersonalization = true;
      if (showGlobalSupporters != null) _showGlobalSupporters = showGlobalSupporters;
      if (faceRecognitionEnabled != null) _faceRecognitionEnabled = faceRecognitionEnabled;
      if (qrAttendanceEnabled != null) _qrAttendanceEnabled = qrAttendanceEnabled;
      if (octophotosEnabled != null) _octophotosEnabled = octophotosEnabled;
      if (userPhotosQuota != null) _userPhotosQuota = userPhotosQuota;
      if (preCheckinEnabled != null) _preCheckinEnabled = preCheckinEnabled;
      if (preCheckinStrict != null) _preCheckinStrict = preCheckinStrict;
      if (faceCheckinEnabled != null) _faceCheckinEnabled = faceCheckinEnabled;
      if (punctualityXp != null) _punctualityXp = punctualityXp;
    });
    try {
      final updated = await _api.updateAcademy(
        _academy.id,
        showGlobalSupporters: showGlobalSupporters,
        faceRecognitionEnabled: faceRecognitionEnabled,
        qrAttendanceEnabled: qrAttendanceEnabled,
        octophotosEnabled: octophotosEnabled,
        userPhotosQuota: userPhotosQuota,
        preCheckinEnabled: preCheckinEnabled,
        preCheckinStrict: preCheckinStrict,
        faceCheckinEnabled: faceCheckinEnabled,
        punctualityXp: punctualityXp,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _showGlobalSupporters = updated.showGlobalSupporters;
        _faceRecognitionEnabled = updated.faceRecognitionEnabled;
        _qrAttendanceEnabled = updated.qrAttendanceEnabled;
        _octophotosEnabled = updated.octophotosEnabled;
        _userPhotosQuota = updated.userPhotosQuota;
        _preCheckinEnabled = updated.preCheckinEnabled;
        _preCheckinStrict = updated.preCheckinStrict;
        _faceCheckinEnabled = updated.faceCheckinEnabled;
        _punctualityXp = updated.punctualityXp;
        _quotaController.text = updated.userPhotosQuota.toString();
        _punctualityXpController.text = updated.punctualityXp.toString();
        _savingAdminPersonalization = false;
      });
      widget.onUpdated();
      AppFeedback.show(
        context,
        message: 'Personalização da academia atualizada.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showGlobalSupporters = previousShowGlobalSupporters;
        _faceRecognitionEnabled = previousFaceRecognitionEnabled;
        _qrAttendanceEnabled = previousQrAttendanceEnabled;
        _octophotosEnabled = previousOctophotosEnabled;
        _userPhotosQuota = previousUserPhotosQuota;
        _preCheckinEnabled = previousPreCheckinEnabled;
        _preCheckinStrict = previousPreCheckinStrict;
        _faceCheckinEnabled = previousFaceCheckinEnabled;
        _punctualityXp = previousPunctualityXp;
        _quotaController.text = previousUserPhotosQuota.toString();
        _punctualityXpController.text = previousPunctualityXp.toString();
        _savingAdminPersonalization = false;
      });
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
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
    if (widget.trainingFieldOnly) {
      return Scaffold(
        appBar: AppStandardAppBar(
          title: 'Campo de treinamento',
          subtitle: _academy.name,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadTechniques();
            await _loadWeeklyKits();
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
                      child: const Icon(Icons.ondemand_video_rounded, color: AppTheme.primary),
                    ),
                    title: const Text(
                      'Vídeo da tarefa diária',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Cadastrar vídeos da tarefa diária da sua academia'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrainingVideoListScreen(localOnly: true),
                      ),
                    ),
                  ),
                ),
                AppSpacing.verticalM,
                _buildTrainingFieldSections(),
              ],
            ),
          ),
        ),
      );
    }

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
              const SizedBox(height: 24),
              _buildReportPeriodCard(),
              if (AuthService().isAdmin()) ...[
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Personalização da academia'),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'Controle por academia o bloco de parceiros globais da Central, a chamada por foto e a chamada por QR.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryOf(context),
                              ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Mostrar apoiadores do app'),
                        subtitle: const Text(
                          'Exibe parceiros globais na home dos alunos desta academia.',
                        ),
                        value: _showGlobalSupporters,
                        onChanged: _savingAdminPersonalization
                            ? null
                            : (value) {
                                _updateAdminPersonalization(
                                  showGlobalSupporters: value,
                                );
                              },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Ativar chamada por QR Code'),
                        subtitle: const Text(
                          'Quando desativado, a presença é registrada somente de forma manual.',
                        ),
                        value: _qrAttendanceEnabled,
                        onChanged: _savingAdminPersonalization
                            ? null
                            : (value) {
                                _updateAdminPersonalization(
                                  qrAttendanceEnabled: value,
                                );
                              },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Ativar chamada por reconhecimento facial'),
                        subtitle: const Text(
                          'Habilita o botão "Chamada por foto" nas sessões de chamada.',
                        ),
                        value: _faceRecognitionEnabled,
                        onChanged: _savingAdminPersonalization
                            ? null
                            : (value) {
                                _updateAdminPersonalization(
                                  faceRecognitionEnabled: value,
                                );
                              },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Ativar OctoPhotos (feed de fotos)'),
                        subtitle: const Text(
                          'Habilita a aba de fotos da academia para todos os alunos.',
                        ),
                        value: _octophotosEnabled,
                        onChanged: _savingAdminPersonalization
                            ? null
                            : (value) {
                                _updateAdminPersonalization(
                                  octophotosEnabled: value,
                                );
                              },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Ativar pré-checkin de treinos'),
                        subtitle: const Text(
                          'Habilita o lançamento de treinos e a confirmação antecipada de presença.',
                        ),
                        value: _preCheckinEnabled,
                        onChanged: _savingAdminPersonalization
                            ? null
                            : (value) {
                                _updateAdminPersonalization(
                                  preCheckinEnabled: value,
                                );
                              },
                      ),
                      if (_preCheckinEnabled)
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          title: const Text('Modo estrito de pré-checkin'),
                          subtitle: const Text(
                            'Sem confirmação antecipada = sem presença automática. Professor pode dar presença manual.',
                          ),
                          value: _preCheckinStrict,
                          onChanged: _savingAdminPersonalization
                              ? null
                              : (value) {
                                  _updateAdminPersonalization(
                                    preCheckinStrict: value,
                                  );
                                },
                        ),
                      if (_faceRecognitionEnabled)
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          title: const Text('Ativar quiosque facial de chegada'),
                          subtitle: const Text(
                            'Tablet na recepção identifica o aluno pela câmera e registra presença em tempo real.',
                          ),
                          value: _faceCheckinEnabled,
                          onChanged: _savingAdminPersonalization
                              ? null
                              : (value) {
                                  _updateAdminPersonalization(
                                    faceCheckinEnabled: value,
                                  );
                                },
                        ),
                      if (_faceCheckinEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'XP por pontualidade',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Concedido quando o aluno chega antes do início do treino.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: _punctualityXpController,
                                  enabled: !_savingAdminPersonalization,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n >= 0 && n <= 100) {
                                      _updateAdminPersonalization(punctualityXp: n);
                                    } else {
                                      _punctualityXpController.text = _punctualityXp.toString();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_octophotosEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Limite de fotos por aluno',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Moderadores são isentos do limite.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: _quotaController,
                                  enabled: !_savingAdminPersonalization,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n >= 1) {
                                      _updateAdminPersonalization(userPhotosQuota: n);
                                    } else {
                                      _quotaController.text = _userPhotosQuota.toString();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
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

  Future<void> _loadWeeklyKits({bool silentErrors = false}) async {
    setState(() => _loadingWeeklyKits = true);
    try {
      final list = await _api.getWeeklyKits(_academy.id);
      if (mounted) {
        setState(() {
          _weeklyKits = list;
          _loadingWeeklyKits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingWeeklyKits = false);
        if (!silentErrors) {
          AppFeedback.show(
            context,
            message: userFacingMessage(e),
            type: AppFeedbackType.error,
          );
        }
      }
    }
  }

  List<Widget> _buildWeeklyKitsPanelChildren() {
    return [
      Text(
        'Com pelo menos uma turma válida (1–5 técnicas), a semana no app é só por turmas; '
        'as três missões fixas ficam ocultas até não haver turmas ativas.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
      ),
      const SizedBox(height: 12),
      if (_loadingWeeklyKits)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_weeklyKits.isEmpty)
        Text(
          'Nenhuma turma ainda. Crie pelo menos uma turma com 1 a 5 técnicas para os alunos '
          'terem missões da semana.',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        )
      else
        Column(
          children: _weeklyKits
              .map(
                (k) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(k.label),
                  subtitle: Text('${k.items.length} técnica(s)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar turma',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editWeeklyKit(k),
                      ),
                      IconButton(
                        tooltip: 'Remover turma',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDeleteWeeklyKit(k),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _loadingWeeklyKits ? null : () => _editWeeklyKit(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova turma'),
          ),
          if (_hasActiveTurmas())
            OutlinedButton.icon(
              onPressed: (_loadingWeeklyKits || _resettingTurmasWeek)
                  ? null
                  : _confirmResetTurmasWeek,
              icon: _resettingTurmasWeek
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt_outlined),
              label: Text(
                  _resettingTurmasWeek ? 'A reiniciar…' : 'Reiniciar semana (turmas)'),
            ),
        ],
      ),
      if (_hasActiveTurmas()) ...[
        const SizedBox(height: 8),
        Text(
          '«Reiniciar semana (turmas)» remove a escolha de turma e as conclusões desta semana ISO '
          '(calendário horário de Brasília) '
          'para missões de turma; os pontos já ganhos mantêm-se (ajuste no perfil).',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    ];
  }

  Future<void> _confirmResetTurmasWeek() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar semana das turmas?'),
        content: const Text(
          'Isto aplica-se à semana ISO atual no horário de Brasília: todos os alunos perdem a escolha de turma '
          'e podem voltar a escolher; as conclusões dessa semana nas missões de turma são '
          'anuladas para refazer os focos. A pontuação já conquistada é preservada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _resettingTurmasWeek = true);
    try {
      final result = await _api.resetAcademyWeeklyTurmasWeek(_academy.id);
      if (mounted) {
        setState(() => _resettingTurmasWeek = false);
        final msg = result['message'] as String? ?? 'Semana das turmas reiniciada.';
        AppFeedback.show(context, message: msg, type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resettingTurmasWeek = false);
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  Future<void> _confirmDeleteWeeklyKit(WeeklyKitRead kit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover turma?'),
        content: Text(
          'A turma «${kit.label}» será removida. As missões geradas por ela deixam de estar ativas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteWeeklyKit(_academy.id, kit.id);
      await _loadWeeklyKits();
      if (mounted) {
        AppFeedback.show(context, message: 'Turma removida.', type: AppFeedbackType.success);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _editWeeklyKit(WeeklyKitRead? existing) async {
    if (_techniques.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Crie ou carregue técnicas nesta academia primeiro.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final techIds = <String>[];
    final multCtrls = <TextEditingController>[];
    if (existing != null && existing.items.isNotEmpty) {
      for (final it in existing.items) {
        techIds.add(it.techniqueId);
        multCtrls.add(TextEditingController(text: '${it.multiplier}'));
      }
    } else {
      techIds.add(_techniques.first.id);
      multCtrls.add(TextEditingController(text: '$minRewardPoints'));
    }
    void disposeRowCtrls() {
      for (final c in multCtrls) {
        c.dispose();
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Nova turma' : 'Editar turma'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome (turma)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < techIds.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: techIds[i],
                              decoration: const InputDecoration(
                                labelText: 'Técnica',
                                border: OutlineInputBorder(),
                              ),
                              items: _techniques
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t.id,
                                      child: Text(
                                        t.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setLocal(() => techIds[i] = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: multCtrls[i],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Pontos',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      children: [
                        if (techIds.length < 5)
                          TextButton.icon(
                            onPressed: () {
                              setLocal(() {
                                techIds.add(_techniques.first.id);
                                multCtrls.add(TextEditingController(text: '$minRewardPoints'));
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Técnica'),
                          ),
                        if (techIds.length > 1)
                          TextButton.icon(
                            onPressed: () {
                              setLocal(() {
                                final last = multCtrls.removeLast();
                                last.dispose();
                                techIds.removeLast();
                              });
                            },
                            icon: const Icon(Icons.remove, size: 18),
                            label: const Text('Última'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (labelCtrl.text.trim().isEmpty) return;
                    if (techIds.isEmpty || techIds.length > 5) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) {
      labelCtrl.dispose();
      disposeRowCtrls();
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < techIds.length; i++) {
      final mult = int.tryParse(multCtrls[i].text.trim()) ?? minRewardPoints;
      items.add({
        'technique_id': techIds[i],
        'multiplier': clampRewardPoints(mult),
      });
    }
    final labelTrim = labelCtrl.text.trim();
    labelCtrl.dispose();
    disposeRowCtrls();
    if (items.isEmpty || items.length > 5) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Indique entre 1 e 5 técnicas.',
          type: AppFeedbackType.warning,
        );
      }
      return;
    }
    if (!mounted) return;
    try {
      if (existing == null) {
        await _api.createWeeklyKit(
          academyId: _academy.id,
          label: labelTrim,
          items: items,
        );
      } else {
        await _api.patchWeeklyKit(
          academyId: _academy.id,
          kitId: existing.id,
          label: labelTrim,
          items: items,
        );
      }
      await _loadWeeklyKits();
      if (mounted) {
        AppFeedback.show(context, message: 'Turma guardada.', type: AppFeedbackType.success);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Widget _buildReportPeriodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período dos relatórios',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ranking, conclusões e logins usam o mesmo intervalo (máx. 366 dias na API).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '${toBrDate(_reportPeriodStart)} — ${toBrDate(_reportPeriodEnd)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickReportPeriodStart,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: const Text('Data inicial'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickReportPeriodEnd,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Data final'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingFieldSections() {
    return AcademyTrainingFieldSections(
      onOpenTechniques: () async {
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
      onOpenTrophies: () {
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
      hasActiveTurmas: _hasActiveTurmas(),
      onWeeklyKitsExpansionChanged: (open) {
        if (open) _loadWeeklyKits();
      },
      weeklyKitsChildren: _buildWeeklyKitsPanelChildren(),
      weeklyMissionsChildren: _buildWeeklyMissionsFormChildren(),
    );
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
      const _SectionTitle(title: 'Ranking (conclusões no período)'),
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
      const _SectionTitle(title: 'Conclusões no período'),
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
                    'Sem dados no período.',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
              ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Logins no período'),
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
          '${report.eligibleUsersCount} usuários (staff e alunos) · '
          '${report.totalLoginDays} logins no total',
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
            'Ninguém da academia registou login neste período.',
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

