import 'dart:async' show unawaited;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Frequência do aluno: visão geral (desde o início + período), gráfico por semana/mês e histórico paginado.
///
/// Dados: [ApiService.getAttendanceMyStats] → `GET /attendance/stats/me`.
class AttendanceMyStatsScreen extends StatefulWidget {
  const AttendanceMyStatsScreen({super.key});

  @override
  State<AttendanceMyStatsScreen> createState() => _AttendanceMyStatsScreenState();
}

enum _PeriodPreset { week, month, threeMonths, year, custom }

class _AttendanceMyStatsScreenState extends State<AttendanceMyStatsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  _PeriodPreset _preset = _PeriodPreset.month;
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loading = true;
  String? _error;
  AttendanceMyStatsModel? _stats;

  final List<AttendanceRecordWithSessionModel> _historyRecords = [];
  bool _loadingMoreHistory = false;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload(resetHistory: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _dateRangeForPreset() {
    final now = DateTime.now();
    final today = _startOfDay(now);

    switch (_preset) {
      case _PeriodPreset.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (monday, _endOfDay(now));
      case _PeriodPreset.month:
        final first = DateTime(now.year, now.month, 1);
        return (first, _endOfDay(now));
      case _PeriodPreset.threeMonths:
        final from = today.subtract(const Duration(days: 90));
        return (_startOfDay(from), _endOfDay(now));
      case _PeriodPreset.year:
        final first = DateTime(now.year, 1, 1);
        return (first, _endOfDay(now));
      case _PeriodPreset.custom:
        final from = _customFrom ?? DateTime(now.year, now.month, 1);
        final to = _customTo ?? now;
        if (from.isAfter(to)) {
          return (to, from);
        }
        return (_startOfDay(from), _endOfDay(to));
    }
  }

  Future<void> _reload({required bool resetHistory}) async {
    _api.invalidateCache('GET:${_api.baseUrl}/attendance/stats/me');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _dateRangeForPreset();
      final data = await _api.getAttendanceMyStats(
        from: range.$1,
        to: range.$2,
        limit: 30,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _stats = data;
        _loading = false;
        if (resetHistory) {
          _historyRecords
            ..clear()
            ..addAll(data.history);
        }
      });
    } catch (e, st) {
      debugPrint('AttendanceMyStatsScreen: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    final s = _stats;
    if (s == null || _loadingMoreHistory) return;
    if (_historyRecords.length >= s.historyTotal) return;

    setState(() => _loadingMoreHistory = true);
    try {
      final range = _dateRangeForPreset();
      final data = await _api.getAttendanceMyStats(
        from: range.$1,
        to: range.$2,
        limit: 30,
        offset: _historyRecords.length,
      );
      if (!mounted) return;
      setState(() {
        _historyRecords.addAll(data.history);
        _loadingMoreHistory = false;
      });
    } catch (e, st) {
      debugPrint('loadMoreHistory: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingMoreHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingMessage(e))),
      );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: _customFrom ?? DateTime(now.year, now.month, 1),
      end: _customTo ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      locale: const Locale('pt', 'BR'),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _preset = _PeriodPreset.custom;
      _customFrom = picked.start;
      _customTo = picked.end;
    });
    await _reload(resetHistory: true);
  }

  void _onPreset(_PeriodPreset p) {
    if (p == _PeriodPreset.custom) {
      unawaited(_pickCustomRange());
      return;
    }
    setState(() => _preset = p);
    unawaited(_reload(resetHistory: true));
  }

  void _onChipSelected(_PeriodPreset p, bool selected) {
    if (!selected) return;
    _onPreset(p);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd('pt_BR');
    final tf = DateFormat.Hm('pt_BR');

    return Scaffold(
        appBar: AppBar(
          title: const Text('Minha frequência'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Geral'),
              Tab(text: 'Por período'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semana'),
                      selected: _preset == _PeriodPreset.week,
                      onSelected: (s) => _onChipSelected(_PeriodPreset.week, s),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Mês'),
                      selected: _preset == _PeriodPreset.month,
                      onSelected: (s) => _onChipSelected(_PeriodPreset.month, s),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('3 meses'),
                      selected: _preset == _PeriodPreset.threeMonths,
                      onSelected: (s) => _onChipSelected(_PeriodPreset.threeMonths, s),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Ano'),
                      selected: _preset == _PeriodPreset.year,
                      onSelected: (s) => _onChipSelected(_PeriodPreset.year, s),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Personalizado'),
                      selected: _preset == _PeriodPreset.custom,
                      onSelected: (s) => _onChipSelected(_PeriodPreset.custom, s),
                    ),
                  ],
                ),
              ),
            ),
            if (_stats != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '${df.format(_stats!.fromDate.toLocal())} — ${df.format(_stats!.toDate.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _reload(resetHistory: true),
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildGeneralTab(df),
                            _buildChartTab(),
                            _buildHistoryTab(df, tf),
                          ],
                        ),
            ),
          ],
        ),
    );
  }

  Widget _buildGeneralTab(DateFormat df) {
    final s = _stats!;

    return RefreshIndicator(
      onRefresh: () => _reload(resetHistory: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Desde o início', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${s.lifetimeTotalCheckins}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'presenças',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No período selecionado', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${s.totalCheckins}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'presenças',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (s.lastSeenAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Última presença: ${df.format(s.lastSeenAt!.toLocal())} às '
                      '${DateFormat.Hm('pt_BR').format(s.lastSeenAt!.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    final s = _stats!;
    final buckets = s.checkinsByPeriod;
    if (buckets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _reload(resetHistory: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Sem dados para o período.')),
          ],
        ),
      );
    }

    final maxY = buckets.map((b) => b.presentCount).reduce((a, b) => a > b ? a : b);
    final capY = maxY < 1 ? 1.0 : (maxY * 1.15).toDouble();

    return RefreshIndicator(
      onRefresh: () => _reload(resetHistory: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.bucket == 'week' ? 'Presenças por semana' : 'Presenças por mês',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                maxY: capY,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                        final label = buckets[i].label;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: capY > 5 ? (capY / 5).ceilToDouble() : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].presentCount.toDouble(),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          color: AppTheme.primary,
                        ),
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

  Widget _buildHistoryTab(DateFormat df, DateFormat tf) {
    if (_historyRecords.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _reload(resetHistory: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Nenhuma presença no período.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _reload(resetHistory: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            unawaited(_loadMoreHistory());
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _historyRecords.length + (_loadingMoreHistory ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _historyRecords.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final r = _historyRecords[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(r.sessionTitle?.trim().isNotEmpty == true ? r.sessionTitle! : 'Treino'),
                subtitle: Text(
                  '${df.format(r.checkedInAt.toLocal())} · ${tf.format(r.checkedInAt.toLocal())} · ${r.method}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
