import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/engagement_report.dart';
import 'package:viewer/models/mission_completion_report.dart';
import 'package:viewer/models/punctuality_report.dart';
import 'package:viewer/models/students_attention_report.dart';
import 'package:viewer/models/technique_execution_summary.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';
import 'package:viewer/screens/admin/engagement_reports_screen.dart';
import 'package:viewer/screens/admin/execution_reports_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/role_guard.dart';

class RelatoriosHubScreen extends StatefulWidget {
  const RelatoriosHubScreen({super.key});

  @override
  State<RelatoriosHubScreen> createState() => _RelatoriosHubScreenState();
}

class _RelatoriosHubScreenState extends State<RelatoriosHubScreen> {
  final ApiService _api = ApiService();

  late DateTime _fromDate;
  late DateTime _toDate;
  String? _selectedAcademyId;

  List<Academy> _academies = [];
  EngagementReport? _engagement;
  WeeklyPanelLoginsReport? _logins;
  MissionCompletionReport? _missions;
  TechniqueExecutionSummary? _executions;
  StudentsAttentionReport? _attention;
  PunctualityReport? _punctuality;
  int _punctualityDays = 30;
  bool _loadingPunctuality = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate.subtract(const Duration(days: 6));
    _loadAll();
    _loadPunctuality();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getAcademies(),
        _api.getEngagementReport(
          referenceDate: _toDate,
          academyId: _selectedAcademyId,
        ),
        _api.getWeeklyPanelLoginsReport(
          startDate: _fromDate,
          endDate: _toDate,
          academyId: _selectedAcademyId,
        ),
        _api.getMissionCompletionReport(
          fromDate: _fromDate,
          toDate: _toDate,
          academyId: _selectedAcademyId,
        ),
        _api.getTechniqueExecutionSummary(academyId: _selectedAcademyId),
        _api.getStudentsAttentionReport(academyId: _selectedAcademyId),
      ]);
      if (!mounted) return;
      setState(() {
        _academies = results[0] as List<Academy>;
        _engagement = results[1] as EngagementReport;
        _logins = results[2] as WeeklyPanelLoginsReport;
        _missions = results[3] as MissionCompletionReport;
        _executions = results[4] as TechniqueExecutionSummary;
        _attention = results[5] as StudentsAttentionReport;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _loadPunctuality() async {
    if (_selectedAcademyId == null || _selectedAcademyId!.isEmpty) {
      setState(() {
        _punctuality = null;
        _loadingPunctuality = false;
      });
      return;
    }
    setState(() => _loadingPunctuality = true);
    try {
      final r = await _api.getPunctualityReport(
        academyId: _selectedAcademyId,
        days: _punctualityDays,
      );
      if (!mounted) return;
      setState(() {
        _punctuality = r;
        _loadingPunctuality = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPunctuality = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: isFrom ? 'Data inicial' : 'Data final',
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
        if (_fromDate.isAfter(_toDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = DateTime(picked.year, picked.month, picked.day);
        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      }
    });
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: const AppStandardAppBar(title: 'Relatórios'),
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: EdgeInsets.all(AppTheme.screenPadding(context)),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                _buildError(context)
              else ...[
                _buildSummaryRow(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Engajamento'),
                const SizedBox(height: 12),
                _buildEngagementCards(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Execuções de Técnicas'),
                const SizedBox(height: 12),
                _buildExecutionsCard(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Missões'),
                const SizedBox(height: 12),
                _buildMissionsCard(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Alunos para dar atenção'),
                const SizedBox(height: 12),
                _buildAttentionCard(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Pontualidade'),
                const SizedBox(height: 12),
                _buildPunctualitySection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: 'De',
                date: _fromDate,
                onTap: () => _pickDate(isFrom: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateButton(
                label: 'Até',
                date: _toDate,
                onTap: () => _pickDate(isFrom: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedAcademyId,
          decoration: const InputDecoration(
            labelText: 'Academia',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todas as academias'),
            ),
            ..._academies.map(
              (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
            ),
          ],
          onChanged: (value) {
            setState(() => _selectedAcademyId = value);
            _loadAll();
            _loadPunctuality();
          },
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final engagement = _engagement;
    final logins = _logins;
    final missions = _missions;
    final executions = _executions;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          label: 'Ativos 7 dias',
          value: engagement != null
              ? '${engagement.weekly.activeRate.toStringAsFixed(1)}%'
              : '—',
          sub: engagement != null
              ? '${engagement.weekly.activeStudents} de ${engagement.weekly.totalStudents} alunos'
              : '',
          color: Colors.green,
          tooltip: 'Alunos que fizeram ao menos 1 login nos últimos 7 dias antes da data final do filtro.\nCálculo: alunos ativos ÷ total de alunos.',
        ),
        _SummaryCard(
          label: 'Ativos 30 dias',
          value: engagement != null
              ? '${engagement.monthly.activeRate.toStringAsFixed(1)}%'
              : '—',
          sub: engagement != null
              ? '${engagement.monthly.activeStudents} de ${engagement.monthly.totalStudents} alunos'
              : '',
          color: AppTheme.primary,
          tooltip: 'Alunos que fizeram ao menos 1 login do 1º dia do mês até a data final do filtro.\nCálculo: alunos ativos ÷ total de alunos.',
        ),
        _SummaryCard(
          label: 'Logins no período',
          value: logins != null ? '${logins.usersLoggedAtLeastOnce}' : '—',
          sub: logins != null ? 'de ${logins.eligibleUsersCount} usuários' : '',
          color: Colors.blue,
          tooltip: 'Quantidade de usuários (staff e alunos) que fizeram ao menos 1 login no intervalo De/Até selecionado.',
        ),
        _SummaryCard(
          label: 'Missões concluídas',
          value: missions != null
              ? '${missions.completionRate.toStringAsFixed(1)}%'
              : '—',
          sub: missions != null
              ? '${missions.usersCompleted} de ${missions.totalStudents} alunos'
              : '',
          color: Colors.amber,
          tooltip: 'Alunos que concluíram ao menos 1 missão no período selecionado.\nCálculo: alunos com ≥1 missão concluída ÷ total de alunos.',
        ),
        _SummaryCard(
          label: 'Execuções (total)',
          value: executions != null ? '${executions.total}' : '—',
          sub: executions != null
              ? '${executions.beforeTrainingPercent.toStringAsFixed(0)}% planejadas'
              : '',
          color: Colors.deepOrange,
          tooltip: 'Total de execuções de técnicas confirmadas (planejadas antes + naturais após o treino).\nNão filtrado pelo período De/Até — reflete o histórico geral da academia.',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondaryOf(context),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
    );
  }

  Widget _buildEngagementCards(BuildContext context) {
    final engagement = _engagement;
    final logins = _logins;
    return Column(
      children: [
        _ReportCard(
          icon: Icons.trending_up_rounded,
          title: 'Taxa de Atividade',
          onDetail: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EngagementReportsScreen(),
            ),
          ),
          child: engagement == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgressRow(
                      label:
                          'Semana (${toBrDate(engagement.weekly.startDate)} – ${toBrDate(engagement.weekly.endDate)})',
                      value: engagement.weekly.activeRate / 100,
                      text: '${engagement.weekly.activeRate.toStringAsFixed(1)}%',
                      sub: '${engagement.weekly.activeStudents} de ${engagement.weekly.totalStudents} alunos',
                    ),
                    const SizedBox(height: 12),
                    _ProgressRow(
                      label:
                          'Mês (${toBrDate(engagement.monthly.startDate)} – ${toBrDate(engagement.monthly.endDate)})',
                      value: engagement.monthly.activeRate / 100,
                      text: '${engagement.monthly.activeRate.toStringAsFixed(1)}%',
                      sub: '${engagement.monthly.activeStudents} de ${engagement.monthly.totalStudents} alunos',
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _ReportCard(
          icon: Icons.lock_open_rounded,
          title: 'Logins no Painel',
          tooltip:
              'Usuários (staff e alunos) que fizeram login ao menos 1 vez no período.\n'
              'Cálculo: usuários com ≥1 login ÷ total de usuários elegíveis.',
          onDetail: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EngagementReportsScreen(),
            ),
          ),
          child: logins == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgressRow(
                      label:
                          '${toBrDate(_fromDate)} – ${toBrDate(_toDate)}',
                      value: logins.eligibleUsersCount > 0
                          ? logins.usersLoggedAtLeastOnce /
                              logins.eligibleUsersCount
                          : 0,
                      text: logins.eligibleUsersCount > 0
                          ? '${(logins.usersLoggedAtLeastOnce / logins.eligibleUsersCount * 100).toStringAsFixed(1)}%'
                          : '—',
                      sub: '${logins.usersLoggedAtLeastOnce} de ${logins.eligibleUsersCount} usuários',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total de dias de login: ${logins.totalLoginDays}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildExecutionsCard(BuildContext context) {
    final executions = _executions;
    return _ReportCard(
      icon: Icons.sports_martial_arts_rounded,
      title: 'Planejadas vs. Naturais',
      onDetail: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExecutionReportsScreen()),
      ),
      child: executions == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressRow(
                  label: 'Planejadas (antes do treino)',
                  value: executions.total > 0
                      ? executions.beforeTrainingCount / executions.total
                      : 0,
                  text: '${executions.beforeTrainingPercent.toStringAsFixed(1)}%',
                  sub: '${executions.beforeTrainingCount} execuções confirmadas',
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),
                _ProgressRow(
                  label: 'Naturais (após o treino)',
                  value: executions.total > 0
                      ? executions.afterTrainingCount / executions.total
                      : 0,
                  text: executions.total > 0
                      ? '${(executions.afterTrainingCount / executions.total * 100).toStringAsFixed(1)}%'
                      : '0%',
                  sub: '${executions.afterTrainingCount} execuções confirmadas',
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total confirmadas: ${executions.total}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ],
            ),
    );
  }

  Widget _buildAttentionCard(BuildContext context) {
    final attention = _attention;
    return _ReportCard(
      icon: Icons.person_off_rounded,
      title: 'Mais tempo sem presença',
      tooltip:
          'Alunos ordenados pela data da última presença em aula (mais antiga primeiro).\n'
          'Alunos que nunca compareceram aparecem no topo.',
      child: attention == null || attention.students.isEmpty
          ? Text(
              'Nenhum aluno encontrado.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            )
          : Column(
              children: [
                ...attention.students.take(10).map(
                  (s) => _AttentionRow(student: s),
                ),
                if (attention.totalStudents > 10) ...[
                  const SizedBox(height: 8),
                  Text(
                    '... e mais ${attention.totalStudents - 10} alunos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildPunctualitySection(BuildContext context) {
    const dayOptions = [7, 30, 60, 90];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de período independentes do filtro de datas principal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: dayOptions.map((d) {
              final selected = d == _punctualityDays;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$d dias'),
                  selected: selected,
                  onSelected: (_) {
                    if (_punctualityDays == d) return;
                    setState(() => _punctualityDays = d);
                    _loadPunctuality();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingPunctuality)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_selectedAcademyId == null || _selectedAcademyId!.isEmpty)
          _ReportCard(
            icon: Icons.timer_outlined,
            title: 'Ranking de pontualidade',
            tooltip: 'Selecione uma academia para ver o relatório de pontualidade.',
            child: Text(
              'Selecione uma academia no filtro acima para ver o ranking de pontualidade.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          )
        else if (_punctuality == null || _punctuality!.students.isEmpty)
          _ReportCard(
            icon: Icons.timer_outlined,
            title: 'Ranking de pontualidade',
            tooltip: 'Alunos ordenados por % de check-ins pontuais (chegada antes do horário da sessão) nos últimos $_punctualityDays dias.',
            child: Text(
              'Nenhum dado de pontualidade para o período.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          )
        else ...[
          // Cards de resumo
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                label: 'Média de pontualidade',
                value: '${_punctuality!.avgPct.toStringAsFixed(1)}%',
                sub: '${_punctuality!.students.length} alunos com check-ins',
                color: _pctColor(_punctuality!.avgPct),
                tooltip: 'Média de pontualidade de todos os alunos com check-ins nos últimos $_punctualityDays dias.',
              ),
              _SummaryCard(
                label: 'Maior streak ativo',
                value: '${_punctuality!.maxActiveStreak}',
                sub: 'treinos pontuais seguidos',
                color: const Color(0xFF1D9E75),
                tooltip: 'Maior streak de pontualidade atual entre os alunos.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.timer_outlined,
            title: 'Ranking de pontualidade',
            tooltip: 'Alunos ordenados por % de check-ins pontuais nos últimos $_punctualityDays dias.\nVerde ≥80% · Azul 60-79% · Âmbar 40-59% · Vermelho <40%.',
            child: Column(
              children: _punctuality!.students
                  .take(15)
                  .map((s) => _PunctualityRow(entry: s))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  static Color _pctColor(double pct) {
    if (pct >= 80) return const Color(0xFF1D9E75);
    if (pct >= 60) return const Color(0xFF378ADD);
    if (pct >= 40) return const Color(0xFFBA7517);
    return const Color(0xFFE24B4A);
  }

  Widget _buildMissionsCard(BuildContext context) {
    final missions = _missions;
    return _ReportCard(
      icon: Icons.flag_rounded,
      title: 'Taxa de Conclusão',
      tooltip:
          'Percentual de alunos que concluíram ao menos 1 missão no período.\n'
          'Cálculo: alunos com ≥1 missão concluída ÷ total de alunos ativos.',
      child: missions == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressRow(
                  label: '${toBrDate(_fromDate)} – ${toBrDate(_toDate)}',
                  value: missions.completionRate / 100,
                  text: '${missions.completionRate.toStringAsFixed(1)}%',
                  sub: '${missions.usersCompleted} de ${missions.totalStudents} alunos',
                  color: Colors.green,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _PunctualityRow extends StatelessWidget {
  final PunctualityStudentEntry entry;
  const _PunctualityRow({required this.entry});

  static Color _pctColor(double pct) {
    if (pct >= 80) return const Color(0xFF1D9E75);
    if (pct >= 60) return const Color(0xFF378ADD);
    if (pct >= 40) return const Color(0xFFBA7517);
    return const Color(0xFFE24B4A);
  }

  @override
  Widget build(BuildContext context) {
    final color = _pctColor(entry.punctualityPct);
    final name = entry.name ?? '—';
    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (entry.punctualityPct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppTheme.surfaceOf(context),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.punctualCount}/${entry.totalCheckins}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.punctualityPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (entry.punctualityStreak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 13, color: const Color(0xFF1D9E75)),
                    Text(
                      '${entry.punctualityStreak}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF1D9E75),
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final StudentAttentionItem student;
  const _AttentionRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = student.name ?? student.email;
    final String absence;
    if (student.lastSeenAt == null) {
      absence = 'Nunca compareceu';
    } else if (student.daysAbsent == 0) {
      absence = 'Hoje';
    } else if (student.daysAbsent == 1) {
      absence = 'Há 1 dia';
    } else {
      absence = 'Há ${student.daysAbsent} dias';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: student.lastSeenAt == null
                ? Colors.grey.shade300
                : (student.daysAbsent != null && student.daysAbsent! > 30
                    ? Colors.red.shade100
                    : Colors.orange.shade100),
            child: Text(
              (student.name?.isNotEmpty == true ? student.name![0] : student.email[0])
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: student.lastSeenAt == null
                    ? Colors.grey.shade600
                    : (student.daysAbsent != null && student.daysAbsent! > 30
                        ? Colors.red.shade700
                        : Colors.orange.shade700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (student.graduation != null)
                  Text(
                    student.graduation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: student.lastSeenAt == null
                  ? Colors.grey.shade200
                  : (student.daysAbsent != null && student.daysAbsent! > 30
                      ? Colors.red.shade50
                      : Colors.orange.shade50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              absence,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: student.lastSeenAt == null
                        ? Colors.grey.shade600
                        : (student.daysAbsent != null && student.daysAbsent! > 30
                            ? Colors.red.shade700
                            : Colors.orange.shade700),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label: ${toBrDate(date)}'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final String? tooltip;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                            letterSpacing: .8,
                          ),
                    ),
                  ),
                  if (tooltip != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: tooltip,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 5),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 13,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? tooltip;
  final VoidCallback? onDetail;
  final Widget child;

  const _ReportCard({
    required this.icon,
    required this.title,
    this.tooltip,
    this.onDetail,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (tooltip != null)
                  Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 5),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                if (onDetail != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onDetail,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Ver completo'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final String text;
  final String sub;
  final Color? color;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.text,
    required this.sub,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
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
                  value: value.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceOf(context),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              text,
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
