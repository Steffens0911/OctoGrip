import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance_ranking.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

enum _RankingPeriodKind { month, quarter, year, custom }

class _RankingQuery {
  final String periodKind;
  final String? month;
  final int? year;
  final int? quarter;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _RankingQuery({
    required this.periodKind,
    this.month,
    this.year,
    this.quarter,
    this.dateFrom,
    this.dateTo,
  });
}

class AttendanceRankingScreen extends StatefulWidget {
  final String academyId;

  const AttendanceRankingScreen({super.key, required this.academyId});

  @override
  State<AttendanceRankingScreen> createState() =>
      _AttendanceRankingScreenState();
}

class _AttendanceRankingScreenState extends State<AttendanceRankingScreen> {
  static const String _title = 'Ranking de frequência';
  static const String _emptyMessage = 'Nenhuma presença registrada neste mês';
  static const Color _firstColor = Color(0xFFD4AF37);
  static const Color _secondColor = Color(0xFF9CA3AF);
  static const Color _thirdColor = Color(0xFFCD7F32);
  static const Color _highlightRowBackground = Color(0xFF1E2A1E);
  static const Color _highlightText = Color(0xFF4ECF8A);
  static const Color _avatarFallback = Color(0xFF2A3A4A);

  final _api = ApiService();

  _RankingPeriodKind _periodKind = _RankingPeriodKind.month;
  late DateTime _selectedMonth;
  late int _selectedYear;
  late int _selectedQuarter;
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loading = true;
  String? _error;
  AttendanceRankingModel? _ranking;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedYear = now.year;
    _selectedQuarter = _quarterForMonth(now.month);
    _loadRanking();
  }

  int get _currentYear => DateTime.now().year;

  int get _currentQuarter => _quarterForMonth(DateTime.now().month);

  bool get _canGoNextMonth {
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return _selectedMonth.isBefore(nowMonth);
  }

  _RankingQuery _buildQuery() {
    switch (_periodKind) {
      case _RankingPeriodKind.month:
        return _RankingQuery(
          periodKind: 'month',
          month: DateFormat('yyyy-MM').format(_selectedMonth),
        );
      case _RankingPeriodKind.quarter:
        return _RankingQuery(
          periodKind: 'quarter',
          year: _selectedYear,
          quarter: _selectedQuarter,
        );
      case _RankingPeriodKind.year:
        return _RankingQuery(
          periodKind: 'year',
          year: _selectedYear,
        );
      case _RankingPeriodKind.custom:
        return _RankingQuery(
          periodKind: 'custom',
          dateFrom: _customFrom,
          dateTo: _customTo,
        );
    }
  }

  void _invalidateQueryCache(_RankingQuery query) {
    _api.invalidateAttendanceRankingCache(
      academyId: widget.academyId,
      periodKind: query.periodKind,
      month: query.month,
      year: query.year,
      quarter: query.quarter,
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
    );
  }

  Future<void> _loadRanking({_RankingQuery? invalidateQuery}) async {
    if (invalidateQuery != null) {
      _invalidateQueryCache(invalidateQuery);
    }
    final query = _buildQuery();
    if (query.periodKind == 'custom' &&
        (query.dateFrom == null || query.dateTo == null)) {
      setState(() {
        _loading = false;
        _error = null;
        _ranking = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchAttendanceRanking(
        academyId: widget.academyId,
        periodKind: query.periodKind,
        month: query.month,
        year: query.year,
        quarter: query.quarter,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      );
      if (!mounted) return;
      setState(() {
        _ranking = data;
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
    final oldQuery = _buildQuery();
    setState(() {
      _periodKind = _RankingPeriodKind.custom;
      _customFrom =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _customTo = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    await _loadRanking(invalidateQuery: oldQuery);
  }

  Future<void> _onPeriodChange(_RankingPeriodKind kind) async {
    if (_periodKind == kind && kind != _RankingPeriodKind.custom) return;
    final oldQuery = _buildQuery();
    if (kind == _RankingPeriodKind.custom) {
      await _pickCustomRange();
      return;
    }
    setState(() => _periodKind = kind);
    await _loadRanking(invalidateQuery: oldQuery);
  }

  Future<void> _goMonth(int delta) async {
    final oldQuery = _buildQuery();
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    await _loadRanking(invalidateQuery: oldQuery);
  }

  Future<void> _changeYear(int year) async {
    if (_selectedYear == year) return;
    final oldQuery = _buildQuery();
    setState(() {
      _selectedYear = year;
      if (_periodKind == _RankingPeriodKind.quarter &&
          _selectedYear == _currentYear &&
          _selectedQuarter > _currentQuarter) {
        _selectedQuarter = _currentQuarter;
      }
    });
    await _loadRanking(invalidateQuery: oldQuery);
  }

  Future<void> _changeQuarter(int quarter) async {
    if (_selectedQuarter == quarter) return;
    final oldQuery = _buildQuery();
    setState(() => _selectedQuarter = quarter);
    await _loadRanking(invalidateQuery: oldQuery);
  }

  static int _quarterForMonth(int month) => ((month - 1) ~/ 3) + 1;

  List<int> _availableYears() {
    final now = DateTime.now().year;
    return List<int>.generate(7, (i) => now - i);
  }

  List<int> _availableQuarters() {
    if (_selectedYear < _currentYear) {
      return const [1, 2, 3, 4];
    }
    return List<int>.generate(_currentQuarter, (i) => i + 1);
  }

  String _monthLabel(DateTime month) =>
      DateFormat('MMMM yyyy', 'pt_BR').format(month);

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first;
    return '${parts.first}${parts.last}';
  }

  Widget _buildAvatar({
    required String name,
    required String? avatarUrl,
    required double radius,
    Color? borderColor,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: _avatarFallback,
        foregroundImage: hasAvatar ? NetworkImage(avatarUrl.trim()) : null,
        child: hasAvatar
            ? null
            : Text(
                _initials(name),
                style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildPositionChange(int? change) {
    if (change == null || change == 0) return const SizedBox.shrink();
    final up = change > 0;
    final absValue = change.abs();
    return Text(
      up ? '▲ $absValue' : '▼ $absValue',
      style: TextStyle(
        color: up ? Colors.greenAccent.shade400 : Colors.redAccent.shade200,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPodium(
      List<AttendanceRankingEntryModel> ranking, String? myUserId) {
    final top1 = ranking
        .where((e) => e.position == 1)
        .cast<AttendanceRankingEntryModel?>()
        .firstOrNull;
    final top2 = ranking
        .where((e) => e.position == 2)
        .cast<AttendanceRankingEntryModel?>()
        .firstOrNull;
    final top3 = ranking
        .where((e) => e.position == 3)
        .cast<AttendanceRankingEntryModel?>()
        .firstOrNull;

    if (top1 == null && top2 == null && top3 == null) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
            child: _buildPodiumColumn(top2,
                medalColor: _secondColor,
                avatarRadius: 26,
                barHeight: 60,
                myUserId: myUserId)),
        Expanded(
            child: _buildPodiumColumn(top1,
                medalColor: _firstColor,
                avatarRadius: 32,
                barHeight: 80,
                myUserId: myUserId)),
        Expanded(
            child: _buildPodiumColumn(top3,
                medalColor: _thirdColor,
                avatarRadius: 24,
                barHeight: 44,
                myUserId: myUserId)),
      ],
    );
  }

  Widget _buildPodiumColumn(
    AttendanceRankingEntryModel? entry, {
    required Color medalColor,
    required double avatarRadius,
    required double barHeight,
    required String? myUserId,
  }) {
    if (entry == null) {
      return const SizedBox(height: 180);
    }
    final isMe = myUserId != null && entry.studentId == myUserId;
    final secondary = AppTheme.textSecondaryOf(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? _highlightRowBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: medalColor,
            child: Text(
              '${entry.position}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAvatar(
            name: entry.name,
            avatarUrl: entry.avatarUrl,
            radius: avatarRadius,
            borderColor: medalColor,
          ),
          const SizedBox(height: 6),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? _highlightText : AppTheme.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${entry.totalCheckins} aulas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _highlightText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: barHeight,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.22),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.position}º',
              style: TextStyle(
                color: secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingItem({
    required AttendanceRankingEntryModel entry,
    required bool isCurrentUser,
  }) {
    final secondary = AppTheme.textSecondaryOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? _highlightRowBackground
            : AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.position}',
              style: TextStyle(
                color: secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildAvatar(
              name: entry.name, avatarUrl: entry.avatarUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrentUser
                              ? _highlightText
                              : AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildPositionChange(entry.positionChange),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.attendancePercentage}%',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.totalCheckins}',
            style: const TextStyle(
              color: _highlightText,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPositionCard(AttendanceMyPositionModel myPosition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _highlightRowBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sua posição',
            style: TextStyle(
              color: _highlightText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${myPosition.position}',
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${myPosition.totalCheckins} check-ins',
                  style: const TextStyle(
                    color: _highlightText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildPositionChange(myPosition.positionChange),
              const SizedBox(width: 10),
              Text(
                '${myPosition.attendancePercentage}%',
                style: TextStyle(
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodControls() {
    final monthLabel = _monthLabel(_selectedMonth);
    final quarters = _availableQuarters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Mês'),
              selected: _periodKind == _RankingPeriodKind.month,
              onSelected: (_) => _onPeriodChange(_RankingPeriodKind.month),
            ),
            ChoiceChip(
              label: const Text('Trimestre'),
              selected: _periodKind == _RankingPeriodKind.quarter,
              onSelected: (_) => _onPeriodChange(_RankingPeriodKind.quarter),
            ),
            ChoiceChip(
              label: const Text('Ano'),
              selected: _periodKind == _RankingPeriodKind.year,
              onSelected: (_) => _onPeriodChange(_RankingPeriodKind.year),
            ),
            ChoiceChip(
              label: const Text('Personalizado'),
              selected: _periodKind == _RankingPeriodKind.custom,
              onSelected: (_) => _onPeriodChange(_RankingPeriodKind.custom),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_periodKind == _RankingPeriodKind.month)
          Row(
            children: [
              IconButton(
                onPressed: () => _goMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: _canGoNextMonth ? () => _goMonth(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (_periodKind == _RankingPeriodKind.quarter)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedQuarter,
                  decoration: const InputDecoration(labelText: 'Trimestre'),
                  items: quarters
                      .map(
                        (q) => DropdownMenuItem<int>(
                          value: q,
                          child: Text('Q$q'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _changeQuarter(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: _availableYears()
                      .map(
                        (y) => DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _changeYear(v);
                    }
                  },
                ),
              ),
            ],
          ),
        if (_periodKind == _RankingPeriodKind.year)
          DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(labelText: 'Ano'),
            items: _availableYears()
                .map(
                  (y) => DropdownMenuItem<int>(
                    value: y,
                    child: Text('$y'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _changeYear(v);
              }
            },
          ),
        if (_periodKind == _RankingPeriodKind.custom)
          OutlinedButton.icon(
            onPressed: _pickCustomRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              (_customFrom != null && _customTo != null)
                  ? '${DateFormat('dd/MM/yyyy').format(_customFrom!)} - ${DateFormat('dd/MM/yyyy').format(_customTo!)}'
                  : 'Selecionar período personalizado',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ranking = _ranking;
    final userId = AuthService().currentUser?.id;

    return Scaffold(
      appBar: const AppStandardAppBar(title: _title),
      body: RefreshIndicator(
        onRefresh: _loadRanking,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodControls(),
              const SizedBox(height: 12),
              if (_loading)
                const SizedBox(height: 240, child: AppScreenState.loading())
              else if (_error != null)
                SizedBox(
                  height: 220,
                  child: AppScreenState.error(
                    message: _error!,
                    onRetry: () => _loadRanking(),
                  ),
                )
              else if (ranking == null || ranking.ranking.isEmpty)
                const SizedBox(
                  height: 220,
                  child: AppScreenState.empty(
                    message: _emptyMessage,
                  ),
                )
              else ...[
                _buildPodium(ranking.ranking, userId),
                const SizedBox(height: 12),
                ...ranking.ranking
                    .where((e) => e.position >= 4 && e.position <= 10)
                    .map(
                      (entry) => _buildRankingItem(
                        entry: entry,
                        isCurrentUser:
                            userId != null && entry.studentId == userId,
                      ),
                    ),
                if (ranking.myPosition != null &&
                    ranking.myPosition!.position > 10) ...[
                  const SizedBox(height: 6),
                  Divider(color: AppTheme.borderOf(context)),
                  const SizedBox(height: 6),
                  _buildMyPositionCard(ranking.myPosition!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
