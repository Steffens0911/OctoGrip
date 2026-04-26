import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/screens/academy/attendance_session_detail_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Histórico de chamadas (sessões) da academia com filtros e paginação.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _api = ApiService();

  final List<AttendanceSessionModel> _items = [];
  int _offset = 0;
  static const int _pageSize = 40;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  /// null = todas; 'active' | 'closed'
  String? _statusFilter;
  bool _mineOnly = false;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
        _items.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final list = await _api.listAttendanceSessions(
        status: _statusFilter,
        mine: _mineOnly,
        dateFrom: _dateRange?.start,
        dateTo: _dateRange?.end,
        limit: _pageSize,
        offset: reset ? 0 : _offset,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _offset = _items.length;
        _hasMore = list.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
      );
    });
    await _load(reset: true);
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    unawaited(_load(reset: true));
  }

  String _sessionTitle(AttendanceSessionModel s) {
    if (s.title != null && s.title!.trim().isNotEmpty) return s.title!.trim();
    return 'Chamada';
  }

  String _formatStarts(AttendanceSessionModel s) {
    final local = s.startsAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Histórico de chamadas'),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: () => _load(reset: true))
              : Column(
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
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Todas'),
                            selected: _statusFilter == null,
                            onSelected: (_) {
                              setState(() => _statusFilter = null);
                              unawaited(_load(reset: true));
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Ativas'),
                            selected: _statusFilter == 'active',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'active');
                              unawaited(_load(reset: true));
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Encerradas'),
                            selected: _statusFilter == 'closed',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'closed');
                              unawaited(_load(reset: true));
                            },
                          ),
                          FilterChip(
                            label: const Text('Só minhas'),
                            selected: _mineOnly,
                            onSelected: (v) {
                              setState(() => _mineOnly = v);
                              unawaited(_load(reset: true));
                            },
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: const Icon(Icons.date_range_rounded, size: 18),
                            label: Text(
                              _dateRange == null
                                  ? 'Período'
                                  : '${_dateRange!.start.day}/${_dateRange!.start.month} — ${_dateRange!.end.day}/${_dateRange!.end.month}',
                            ),
                          ),
                          if (_dateRange != null)
                            TextButton(
                              onPressed: _clearDateRange,
                              child: const Text('Limpar período'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView.builder(
                          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : TextButton(
                                          onPressed: () => _load(reset: false),
                                          child: const Text('Carregar mais'),
                                        ),
                                ),
                              );
                            }
                            final s = _items[index];
                            final closed = s.status.toLowerCase() == 'closed';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: Icon(
                                  closed ? Icons.event_busy_rounded : Icons.event_available_rounded,
                                  color: closed ? AppTheme.textSecondaryOf(context) : AppTheme.primary,
                                ),
                                title: Text(
                                  _sessionTitle(s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${_formatStarts(s)} · ${s.presentCount} presente(s)',
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
                                  if (mounted) await _load(reset: true);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
