import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/engagement_report.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/role_guard.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class EngagementReportsScreen extends StatefulWidget {
  const EngagementReportsScreen({super.key});

  @override
  State<EngagementReportsScreen> createState() =>
      _EngagementReportsScreenState();
}

class _EngagementReportsScreenState extends State<EngagementReportsScreen> {
  final ApiService _api = ApiService();

  DateTime _referenceDate = DateTime.now();
  EngagementReport? _globalReport;
  EngagementReport? _academyReport;
  WeeklyPanelLoginsReport? _globalLoginsReport;
  WeeklyPanelLoginsReport? _academyLoginsReport;
  List<Academy> _academies = [];
  String? _selectedAcademyId;

  bool _loadingGlobal = true;
  bool _loadingAcademies = true;
  bool _loadingAcademy = false;
  String? _errorGlobal;
  String? _errorAcademy;
  String? _errorGlobalLogins;
  String? _errorAcademyLogins;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingGlobal = true;
      _loadingAcademies = true;
      _errorGlobal = null;
      _errorAcademy = null;
      _errorGlobalLogins = null;
      _errorAcademyLogins = null;
    });
    try {
      final metricsFuture =
          _api.getEngagementReport(referenceDate: _referenceDate);
      final globalLoginsFuture =
          _api.getWeeklyPanelLoginsReport(referenceDate: _referenceDate);
      final academiesFuture = _api.getAcademies();
      final results =
          await Future.wait([metricsFuture, globalLoginsFuture, academiesFuture]);
      if (!mounted) return;
      setState(() {
        _globalReport = results[0] as EngagementReport;
        _globalLoginsReport = results[1] as WeeklyPanelLoginsReport;
        _academies = results[2] as List<Academy>;
        _loadingGlobal = false;
        _loadingAcademies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGlobal = false;
        _loadingAcademies = false;
        _errorGlobal = userFacingMessage(e);
      });
    }
  }

  Future<void> _loadAcademyReport(String academyId) async {
    setState(() {
      _selectedAcademyId = academyId;
      _loadingAcademy = true;
      _errorAcademy = null;
      _errorAcademyLogins = null;
    });
    try {
      final reports = await Future.wait([
        _api.getEngagementReport(
          referenceDate: _referenceDate,
          academyId: academyId,
        ),
        _api.getWeeklyPanelLoginsReport(
          referenceDate: _referenceDate,
          academyId: academyId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _academyReport = reports[0] as EngagementReport;
        _academyLoginsReport = reports[1] as WeeklyPanelLoginsReport;
        _loadingAcademy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAcademy = false;
        _errorAcademy = userFacingMessage(e);
        _errorAcademyLogins = userFacingMessage(e);
      });
    }
  }

  Future<void> _pickReferenceDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Selecione a data de referência',
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _referenceDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _loadInitial();
    final academyId = _selectedAcademyId;
    if (academyId != null) {
      await _loadAcademyReport(academyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: const AppStandardAppBar(
          title: 'Relatórios de engajamento',
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadInitial();
            final academyId = _selectedAcademyId;
            if (academyId != null) {
              await _loadAcademyReport(academyId);
            }
          },
          child: ListView(
            padding: EdgeInsets.all(AppTheme.screenPadding(context)),
            children: [
              Text(
                'Engajamento geral por período',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Veja a porcentagem de alunos ativos (pelo menos 1 acesso) '
                'na semana e no mês, para todas as academias ou filtrando por uma unidade.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data de referência: ${toBrDate(_referenceDate)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pickReferenceDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Alterar data'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildGlobalSection(context),
              const SizedBox(height: 24),
              _buildAcademyFilter(context),
              const SizedBox(height: 16),
              _buildAcademySection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSection(BuildContext context) {
    if (_loadingGlobal) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_errorGlobal != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorGlobal!,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_globalReport == null) {
      return const SizedBox.shrink();
    }
    return _EngagementCard(
      title: 'Visão global (todas as academias) — engajamento',
      report: _globalReport!,
      loginReport: _globalLoginsReport,
      loginError: _errorGlobalLogins,
    );
  }

  Widget _buildAcademyFilter(BuildContext context) {
    if (_loadingAcademies) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_academies.isEmpty) {
      return const Text(
        'Nenhuma academia cadastrada para filtrar.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedAcademyId,
      decoration: const InputDecoration(
        labelText: 'Filtrar por academia',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Todas (visão geral)'),
        ),
        ..._academies.map(
          (a) => DropdownMenuItem(
            value: a.id,
            child: Text(a.name),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          setState(() {
            _selectedAcademyId = null;
            _academyReport = null;
            _academyLoginsReport = null;
            _errorAcademyLogins = null;
          });
        } else {
          _loadAcademyReport(value);
        }
      },
    );
  }

  Widget _buildAcademySection(BuildContext context) {
    if (_selectedAcademyId == null) {
      return const Text(
        'Selecione uma academia para ver o engajamento local.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    if (_loadingAcademy) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_errorAcademy != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorAcademy!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final id = _selectedAcademyId;
                  if (id != null) _loadAcademyReport(id);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_academyReport == null) {
      return const Text(
        'Ainda não há dados suficientes para este relatório na academia selecionada.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    final academyName = _academies
        .firstWhere(
          (a) => a.id == _selectedAcademyId,
          orElse: () => Academy(
            id: _selectedAcademyId ?? '',
            name: 'Academia selecionada',
          ),
        )
        .name;
    return _EngagementCard(
      title: 'Visão da academia $academyName — engajamento',
      report: _academyReport!,
      loginReport: _academyLoginsReport,
      loginError: _errorAcademyLogins,
    );
  }
}

class _EngagementCard extends StatelessWidget {
  final String title;
  final EngagementReport report;
  final WeeklyPanelLoginsReport? loginReport;
  final String? loginError;

  const _EngagementCard({
    required this.title,
    required this.report,
    this.loginReport,
    this.loginError,
  });

  @override
  Widget build(BuildContext context) {
    final weekly = report.weekly;
    final monthly = report.monthly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                  ),
            ),
            const SizedBox(height: 8),
            if (weekly.totalStudents == 0 && monthly.totalStudents == 0)
              Text(
                'Nenhum aluno cadastrado para este escopo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              )
            else ...[
              _buildRow(
                context,
                label:
                    'Semana (${toBrDate(weekly.startDate)} a ${toBrDate(weekly.endDate)})',
                period: weekly,
              ),
              const SizedBox(height: 12),
              _buildRow(
                context,
                label:
                    'Mês (${toBrDate(monthly.startDate)} a ${toBrDate(monthly.endDate)})',
                period: monthly,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Logins na semana (staff e alunos)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              if (loginError != null)
                Text(
                  loginError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                )
              else if (loginReport == null)
                Text(
                  'Sem dados de login para este período.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                )
              else ...[
                Text(
                  '${loginReport!.usersLoggedAtLeastOnce} logaram ao menos 1 dia · '
                  '${loginReport!.eligibleUsersCount} utilizadores (staff e alunos)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                if (loginReport!.users.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...loginReport!.users.take(6).map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${u.name ?? u.email} — ${u.distinctLoginDaysInWeek} dia(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    ),
                  ),
                  if (loginReport!.users.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '... e mais ${loginReport!.users.length - 6} usuários',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required EngagementPeriodMetrics period,
  }) {
    final rateText = '${period.activeRate.toStringAsFixed(1)}%';
    final subtitle =
        '${period.activeStudents} de ${period.totalStudents} alunos ativos';
    final percent = (period.totalStudents > 0)
        ? (period.activeRate / 100.0).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 10,
                  backgroundColor: AppTheme.surfaceOf(context),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              rateText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
