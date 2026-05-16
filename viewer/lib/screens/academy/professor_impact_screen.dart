import 'package:flutter/material.dart';

import 'package:viewer/models/professor_impact.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class ProfessorImpactScreen extends StatefulWidget {
  const ProfessorImpactScreen({super.key});

  @override
  State<ProfessorImpactScreen> createState() => _ProfessorImpactScreenState();
}

class _ProfessorImpactScreenState extends State<ProfessorImpactScreen> {
  final _api = ApiService();

  ProfessorImpact? _data;
  bool _loading = true;
  String? _error;
  DateTime _referenceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getProfessorImpact(referenceDate: _referenceDate);
      if (mounted) setState(() { _data = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  void _previousWeek() {
    setState(() => _referenceDate = _referenceDate.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    final next = _referenceDate.add(const Duration(days: 7));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _referenceDate = next);
    _load();
  }

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final diff = now.difference(_referenceDate).inDays;
    return diff < 7;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Meu Impacto'),
      body: Column(
        children: [
          _WeekSelector(
            label: _data?.weekLabel ?? '...',
            onPrevious: _previousWeek,
            onNext: _isCurrentWeek ? null : _nextWeek,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _data == null
                        ? const SizedBox()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _ImpactBody(data: _data!),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WeekSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const _WeekSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            color: onNext == null
                ? Theme.of(context).disabledColor
                : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImpactBody extends StatelessWidget {
  final ProfessorImpact data;

  const _ImpactBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const SizedBox(height: 12),
        _HeroCard(data: data),
        const SizedBox(height: 20),
        if (data.techniques.isNotEmpty) ...[
          _SectionLabel('CONCLUSÃO POR TÉCNICA'),
          const SizedBox(height: 8),
          ...data.techniques.map((t) => _TechniqueCard(technique: t, key: ValueKey(t.techniqueName))),
        ],
        if (data.atRiskStudents.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel('ALUNOS PARA DAR ATENÇÃO'),
          const SizedBox(height: 8),
          ...data.atRiskStudents.map((s) => _AtRiskCard(student: s, key: ValueKey(s.id))),
        ],
        const SizedBox(height: 8),
        _SectionLabel('SUA TRAJETÓRIA'),
        const SizedBox(height: 8),
        _MilestoneCard(data: data),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ProfessorImpact data;

  const _HeroCard({required this.data});

  String _narrativeText() {
    final reached = data.studentsReached;
    final total = data.totalStudents;
    final rate = data.completionRate.round();
    final delta = data.completionRateDelta;

    final buf = StringBuffer();
    buf.write('Essa semana você alcançou $reached');
    buf.write(total > 0 ? ' de $total alunos' : ' alunos');
    buf.write('.');

    if (data.techniques.isNotEmpty) {
      final best = data.techniques.first;
      buf.write(' ${best.studentsCompleted} deles completaram a missão de ${best.techniqueName}.');
    }

    if (delta != null && delta != 0) {
      final sign = delta > 0 ? '+' : '';
      buf.write(' Taxa de conclusão: $rate% ($sign${delta.toStringAsFixed(1)}% vs semana anterior).');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final delta = data.completionRateDelta;
    final deltaStr = delta == null
        ? null
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%';
    final deltaColor = delta == null
        ? null
        : delta >= 0
            ? Colors.green.shade400
            : Colors.red.shade400;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Resumo da semana',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _narrativeText(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                children: [
                  _StatChip(value: '${data.studentsReached}', label: 'alcançados'),
                  _Divider(),
                  _StatChip(value: '${data.completionRate.round()}%', label: 'conclusão'),
                  if (deltaStr != null) ...[
                    _Divider(),
                    _StatChip(
                      value: deltaStr,
                      label: 'vs semana ant.',
                      valueColor: deltaColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatChip({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        color: Theme.of(context).dividerColor,
        margin: const EdgeInsets.symmetric(vertical: 4),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _TechniqueCard extends StatelessWidget {
  final TechniqueImpact technique;

  const _TechniqueCard({required this.technique, super.key});

  Color _barColor(double pct) {
    if (pct >= 70) return Colors.green.shade400;
    if (pct >= 40) return Colors.amber.shade500;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final pct = technique.completionPct;
    final barColor = _barColor(pct);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    technique.techniqueName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${pct.round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${technique.studentsCompleted} de ${technique.totalStudents} alunos'
              ' · ${technique.missionsCount} execução(ões)',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AtRiskCard extends StatelessWidget {
  final AtRiskStudent student;

  const _AtRiskCard({required this.student, super.key});

  @override
  Widget build(BuildContext context) {
    final isAlert = student.riskLevel == 'alert';
    final color = isAlert ? Colors.red.shade400 : Colors.orange.shade400;
    final bgColor = color.withValues(alpha: 0.12);
    final label = '${student.daysInactive >= 999 ? '30+' : student.daysInactive} dias';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(Icons.person_outline, color: color, size: 20),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Sem chamada há $label',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MilestoneCard extends StatelessWidget {
  final ProfessorImpact data;

  const _MilestoneCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  size: 28, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.totalCompletionsAllTime} missões',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    'completadas pelos seus alunos no total',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '↑ ${data.totalMissionsInAcademy} missões ativas na academia',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.08,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}
