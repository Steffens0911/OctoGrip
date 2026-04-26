import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/screens/academy/attendance_session_detail_screen.dart';
import 'package:viewer/screens/academy/attendance_student_detail_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

enum _PeriodPreset { week, month, custom }

enum _StudentSort { nameAsc, freqDesc, freqAsc }

/// Frequência: minhas sessões (stats) e alunos da academia no período.
class AttendanceFrequencyScreen extends StatefulWidget {
  const AttendanceFrequencyScreen({super.key});

  @override
  State<AttendanceFrequencyScreen> createState() => _AttendanceFrequencyScreenState();
}

class _AttendanceFrequencyScreenState extends State<AttendanceFrequencyScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  _PeriodPreset _preset = _PeriodPreset.month;
  late DateTimeRange _range;

  List<AttendanceSessionStatModel> _sessions = [];
  List<AttendanceStudentStatModel> _students = [];
  bool _loadingSessions = true;
  bool _loadingStudents = true;
  String? _errorSessions;
  String? _errorStudents;
  _StudentSort _studentSort = _StudentSort.freqDesc;

  static DateTimeRange _weekRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDay = now.subtract(const Duration(days: 6));
    final start = DateTime(startDay.year, startDay.month, startDay.day);
    return DateTimeRange(start: start, end: end);
  }

  static DateTimeRange _monthRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDay = now.subtract(const Duration(days: 29));
    final start = DateTime(startDay.year, startDay.month, startDay.day);
    return DateTimeRange(start: start, end: end);
  }

  @override
  void initState() {
    super.initState();
    _range = _monthRange();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyPreset(_PeriodPreset p) {
    setState(() {
      _preset = p;
      if (p == _PeriodPreset.week) {
        _range = _weekRange();
      } else if (p == _PeriodPreset.month) {
        _range = _monthRange();
      }
    });
    _loadAll();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = _PeriodPreset.custom;
      _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
      );
    });
    _loadAll();
  }

  void _loadAll() {
    unawaited(_loadSessions());
    unawaited(_loadStudents());
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loadingSessions = true;
      _errorSessions = null;
    });
    try {
      final list = await _api.getAttendanceStatsSessions(
        from: _range.start,
        to: _range.end,
      );
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loadingSessions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSessions = userFacingMessage(e);
        _loadingSessions = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
      _errorStudents = null;
    });
    try {
      final academyId = AuthService().currentUser?.academyId;
      if (AuthService().isAdmin() && (academyId == null || academyId.isEmpty)) {
        if (!mounted) return;
        setState(() {
          _students = [];
          _loadingStudents = false;
          _errorStudents =
              'Administrador sem academia vinculada: vincule uma academia ao seu perfil para ver a lista de alunos.';
        });
        return;
      }
      final list = await _api.getAttendanceStatsStudents(
        academyId: academyId,
        from: _range.start,
        to: _range.end,
      );
      if (!mounted) return;
      setState(() {
        _students = list;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorStudents = userFacingMessage(e);
        _loadingStudents = false;
      });
    }
  }

  String _formatSessionDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatLastSeen(DateTime? dt) {
    if (dt == null) return '—';
    return _formatSessionDate(dt);
  }

  List<AttendanceStudentStatModel> _sortedStudents() {
    final copy = List<AttendanceStudentStatModel>.from(_students);
    switch (_studentSort) {
      case _StudentSort.nameAsc:
        copy.sort((a, b) {
          final an = (a.name?.trim().isNotEmpty == true ? a.name! : a.email).toLowerCase();
          final bn = (b.name?.trim().isNotEmpty == true ? b.name! : b.email).toLowerCase();
          return an.compareTo(bn);
        });
        break;
      case _StudentSort.freqDesc:
        copy.sort((a, b) {
          final c = b.attendanceRate.compareTo(a.attendanceRate);
          if (c != 0) return c;
          return a.email.compareTo(b.email);
        });
        break;
      case _StudentSort.freqAsc:
        copy.sort((a, b) {
          final c = a.attendanceRate.compareTo(b.attendanceRate);
          if (c != 0) return c;
          return a.email.compareTo(b.email);
        });
        break;
    }
    return copy;
  }

  String _sortLabel() {
    switch (_studentSort) {
      case _StudentSort.nameAsc:
        return 'Nome A–Z';
      case _StudentSort.freqDesc:
        return 'Frequência (maior)';
      case _StudentSort.freqAsc:
        return 'Frequência (menor)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Frequência'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.screenPadding(context),
              8,
              AppTheme.screenPadding(context),
              0,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semana'),
                  selected: _preset == _PeriodPreset.week,
                  onSelected: (_) => _applyPreset(_PeriodPreset.week),
                ),
                ChoiceChip(
                  label: const Text('Mês'),
                  selected: _preset == _PeriodPreset.month,
                  onSelected: (_) => _applyPreset(_PeriodPreset.month),
                ),
                ChoiceChip(
                  label: const Text('Personalizado'),
                  selected: _preset == _PeriodPreset.custom,
                  onSelected: (_) => unawaited(_pickCustomRange()),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Minhas sessões'),
              Tab(text: 'Alunos da academia'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsTab(context),
                _buildStudentsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context) {
    if (_loadingSessions) {
      return const AppScreenState.loading();
    }
    if (_errorSessions != null) {
      return AppScreenState.error(message: _errorSessions!, onRetry: _loadSessions);
    }
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: _sessions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              children: [
                Text(
                  'Nenhuma sessão sua neste período.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                final s = _sessions[i];
                final title = s.title?.trim().isNotEmpty == true ? s.title!.trim() : 'Chamada';
                final closed = s.status.toLowerCase() == 'closed';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      closed ? Icons.event_busy_rounded : Icons.event_available_rounded,
                      color: closed ? AppTheme.textSecondaryOf(context) : AppTheme.primary,
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${_formatSessionDate(s.startsAt)} · ${s.presentCount} presente(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                    trailing: Chip(
                      label: Text(closed ? 'Encerrada' : 'Ativa'),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (ctx) => AttendanceSessionDetailScreen(sessionId: s.id),
                        ),
                      );
                      if (mounted) _loadSessions();
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStudentsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding(context),
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ordenação: $_sortLabel()',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ),
              PopupMenuButton<_StudentSort>(
                icon: const Icon(Icons.sort_rounded),
                onSelected: (v) => setState(() => _studentSort = v),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: _StudentSort.nameAsc, child: Text('Nome A–Z')),
                  const PopupMenuItem(value: _StudentSort.freqDesc, child: Text('Frequência (maior)')),
                  const PopupMenuItem(value: _StudentSort.freqAsc, child: Text('Frequência (menor)')),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildStudentsListBody(context)),
      ],
    );
  }

  Widget _buildStudentsListBody(BuildContext context) {
    if (_loadingStudents) {
      return const AppScreenState.loading();
    }
    if (_errorStudents != null) {
      return AppScreenState.error(message: _errorStudents!, onRetry: _loadStudents);
    }
    final rows = _sortedStudents();
    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              children: [
                Text(
                  'Nenhum aluno encontrado para esta academia.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppTheme.screenPadding(context),
                0,
                AppTheme.screenPadding(context),
                16,
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final s = rows[i];
                final pct = (s.attendanceRate * 100).toStringAsFixed(1);
                final label = s.name?.trim().isNotEmpty == true ? s.name!.trim() : s.email;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        label.isNotEmpty ? label[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${s.presentCount} presença(s) · $pct% · última: ${_formatLastSeen(s.lastSeenAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final academyId = AuthService().currentUser?.academyId;
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (ctx) => AttendanceStudentDetailScreen(
                            studentId: s.userId,
                            period: _range,
                            academyId: academyId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
