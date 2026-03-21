import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/role_guard.dart';

class ExecutionReportsScreen extends StatefulWidget {
  const ExecutionReportsScreen({super.key});

  @override
  State<ExecutionReportsScreen> createState() => _ExecutionReportsScreenState();
}

class _ExecutionReportsScreenState extends State<ExecutionReportsScreen> {
  final ApiService _api = ApiService();

  UsageMetrics? _globalMetrics;
  UsageMetrics? _academyMetrics;
  List<Academy> _academies = [];
  String? _selectedAcademyId;

  bool _loadingGlobal = true;
  bool _loadingAcademies = true;
  bool _loadingAcademyMetrics = false;
  String? _errorGlobal;
  String? _errorAcademyMetrics;

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
      _errorAcademyMetrics = null;
    });
    try {
      final metrics = await _api.getMetricsUsage();
      final academies = await _api.getAcademies();
      if (!mounted) return;
      setState(() {
        _globalMetrics = metrics;
        _academies = academies;
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

  Future<void> _loadAcademyMetrics(String academyId) async {
    setState(() {
      _selectedAcademyId = academyId;
      _loadingAcademyMetrics = true;
      _errorAcademyMetrics = null;
    });
    try {
      final metrics = await _api.getMetricsUsageForAcademy(academyId);
      if (!mounted) return;
      setState(() {
        _academyMetrics = metrics;
        _loadingAcademyMetrics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAcademyMetrics = false;
        _errorAcademyMetrics = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatórios de execuções'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadInitial,
          child: ListView(
            padding: EdgeInsets.all(AppTheme.screenPadding(context)),
            children: [
              Text(
                'Execuções premeditadas vs naturais',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Acompanhe quantas execuções foram marcadas como premeditadas '
                'focando em troféu/medalha/posição do dia e quantas aconteceram naturalmente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
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
    if (_globalMetrics == null) {
      return const SizedBox.shrink();
    }
    return _UsageMetricsCard(
      title: 'Visão global (todas as academias)',
      metrics: _globalMetrics!,
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
          child: Text('Sem filtro (apenas visão global)'),
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
            _academyMetrics = null;
          });
        } else {
          _loadAcademyMetrics(value);
        }
      },
    );
  }

  Widget _buildAcademySection(BuildContext context) {
    if (_selectedAcademyId == null) {
      return const Text(
        'Selecione uma academia para ver o detalhamento local.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    if (_loadingAcademyMetrics) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_errorAcademyMetrics != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorAcademyMetrics!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final id = _selectedAcademyId;
                  if (id != null) _loadAcademyMetrics(id);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_academyMetrics == null) {
      return const Text(
        'Ainda não há respostas suficientes para este relatório na academia selecionada.',
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
    return _UsageMetricsCard(
      title: 'Visão da academia $academyName',
      metrics: _academyMetrics!,
    );
  }
}

class _UsageMetricsCard extends StatelessWidget {
  final String title;
  final UsageMetrics metrics;

  const _UsageMetricsCard({
    required this.title,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final totalExecutions =
        metrics.beforeTrainingCount + metrics.afterTrainingCount;
    final plannedCount = metrics.afterTrainingCount;
    final naturalCount = metrics.beforeTrainingCount;
    final plannedPercent =
        totalExecutions > 0 ? (plannedCount / totalExecutions * 100) : 0.0;
    final naturalPercent =
        totalExecutions > 0 ? (naturalCount / totalExecutions * 100) : 0.0;

    final plannedFlex = plannedCount > 0 ? plannedCount : 0;
    final naturalFlex = naturalCount > 0 ? naturalCount : 0;

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
            Text(
              totalExecutions > 0
                  ? '$totalExecutions respostas registradas'
                  : 'Nenhuma resposta registrada ainda',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 12),
            if (totalExecutions > 0) ...[
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (plannedFlex > 0)
                        Expanded(
                          flex: plannedFlex,
                          child: Container(color: AppTheme.primary),
                        ),
                      if (naturalFlex > 0)
                        Expanded(
                          flex: naturalFlex,
                          child: Container(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
