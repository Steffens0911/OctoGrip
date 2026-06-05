import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart' show ApiException, ApiService;
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/execution_confirm_sheet.dart';
import 'package:viewer/widgets/opponent_picker_sheet.dart';
// ─────────────────────────────────────────────────────────────
//  OCTO DESIGN TOKENS
// ─────────────────────────────────────────────────────────────

class _C {
  static const bg      = Color(0xFF0D0F1A);
  static const surface = Color(0xFF131627);
  static const card    = Color(0xFF1A1E2E);
  static const locked  = Color(0xFF111320);
  static const green   = Color(0xFF4ECF8A);
  static const blue    = Color(0xFF4A9EFF);
  static const purple  = Color(0xFF9B72CF);
  static const gold    = Color(0xFFFFB830);
  static const textPri = Color(0xFFE8ECF4);
  static const textSec = Color(0xFF7A8299);
  static const textMut = Color(0xFF3D4358);
  static const border  = Color(0xFF252A3D);
  static const borderS = Color(0xFF1E2336);
}

// ─────────────────────────────────────────────────────────────
//  TIER → VISUAL MAPPING
// ─────────────────────────────────────────────────────────────

class _Tier {
  final Color color;
  final Color glow;
  final String label;

  const _Tier({required this.color, required this.glow, required this.label});

  static _Tier of(TrophyWithEarned t) {
    if (t.isManualAward) {
      return const _Tier(
        color: _C.purple,
        glow: Color(0x339B72CF),
        label: 'ESPECIAL',
      );
    }
    return switch (t.earnedTier) {
      'gold'   => _Tier(color: _C.gold,   glow: _C.gold.withValues(alpha: 0.3),   label: 'OURO'),
      'silver' => _Tier(color: _C.blue,   glow: _C.blue.withValues(alpha: 0.3),   label: 'PRATA'),
      'bronze' => _Tier(color: _C.green,  glow: _C.green.withValues(alpha: 0.3),  label: 'BRONZE'),
      _        => _Tier(color: _C.textMut, glow: Colors.transparent,              label: 'BLOQUEADO'),
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  PAGE
// ─────────────────────────────────────────────────────────────

class TrophyShelfPage extends StatefulWidget {
  final String userId;
  final String? userName;
  final List<TrophyWithEarned>? trophies;

  const TrophyShelfPage({
    super.key,
    required this.userId,
    this.userName,
    this.trophies,
  });

  @override
  State<TrophyShelfPage> createState() => _TrophyShelfPageState();
}

class _TrophyShelfPageState extends State<TrophyShelfPage>
    with TickerProviderStateMixin {
  final _api = ApiService();
  List<TrophyWithEarned> _all = [];
  bool _loading = true;
  String? _error;

  String? _filterKind; // null / 'medal' / 'trophy'
  String  _sortBy = 'tier'; // 'tier' | 'unlocked' | 'name'

  late final AnimationController _pulse;

  bool get _isOwn => AuthService().currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.trophies != null) {
      _all     = widget.trophies!;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final trophiesFuture = _api.getTrophiesForUser(widget.userId);
      final manualFuture   = _api.getUserManualTrophyAwards(widget.userId);
      final list = await trophiesFuture;
      List<TrophyWithEarned> manual = [];
      try {
        final raw = await manualFuture;
        final parsed = UserTrophyAwardsResponse.fromJson(raw);
        manual = [...parsed.championshipAwards, ...parsed.customAwards]
            .map((a) => TrophyWithEarned.fromManualAward(a))
            .toList();
      } catch (_) {}
      if (mounted) setState(() { _all = [...manual, ...list]; _loading = false; });
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException && e.statusCode == 403
            ? 'Esta galeria está privada.'
            : userFacingMessage(e);
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  List<TrophyWithEarned> get _filtered {
    var list = _all.where((t) {
      if (_filterKind == null) return true;
      return t.awardKind == _filterKind;
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'unlocked') {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
      }
      if (_sortBy == 'name') return a.name.compareTo(b.name);
      // tier: gold > silver > bronze > locked
      const order = {'gold': 0, 'silver': 1, 'bronze': 2, null: 3};
      if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
      return (order[a.earnedTier] ?? 3).compareTo(order[b.earnedTier] ?? 3);
    });
    return list;
  }

  int get _earnedCount => _all.where((t) => t.unlocked).length;
  int get _goldCount   => _all.where((t) => t.earnedTier == 'gold').length;

  // ── BUILD ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: const Center(child: CircularProgressIndicator(color: _C.green)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(backgroundColor: _C.surface, foregroundColor: _C.textPri),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: _C.textSec), textAlign: TextAlign.center),
              if (_error != 'Esta galeria está privada.') ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
              ],
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_all.isNotEmpty) SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(child: _buildFilters()),
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _all.isEmpty
                      ? 'Nenhum troféu cadastrado na academia.'
                      : 'Nenhuma premiação com este filtro.',
                  style: const TextStyle(color: _C.textSec),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            _buildGrid(filtered),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  // ── APP BAR ─────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _SortMenu(current: _sortBy, onChanged: (v) => setState(() => _sortBy = v)),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Stack(
            fit: StackFit.expand,
            children: [
              Container(color: _C.surface),
              CustomPaint(painter: _GridPainter(opacity: 0.04 + _pulse.value * 0.04)),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      _C.green.withValues(alpha: 0.6),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        title: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTANTE DE TROFÉUS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: _C.green.withValues(alpha: 0.85 + _pulse.value * 0.15),
                  height: 1,
                ),
              ),
              if (widget.userName != null && widget.userName!.isNotEmpty)
                Text(
                  widget.userName!,
                  style: const TextStyle(fontSize: 11, color: _C.textSec, letterSpacing: 0.5),
                ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
      ),
    );
  }

  // ── STATS ───────────────────────────────────────────────

  Widget _buildStats() {
    final total = _all.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(label: 'CONQUISTADOS', value: '$_earnedCount/$total', color: _C.green, flex: 1),
        ],
      ),
    );
  }

  // ── FILTERS ─────────────────────────────────────────────

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          _OctoChip(label: 'Todos',    selected: _filterKind == null,
              onTap: () => setState(() => _filterKind = null)),
          const SizedBox(width: 8),
          _OctoChip(label: 'Medalhas', icon: Icons.military_tech_rounded,
              selected: _filterKind == 'medal',
              onTap: () => setState(() => _filterKind = _filterKind == 'medal' ? null : 'medal')),
          const SizedBox(width: 8),
          _OctoChip(label: 'Troféus',  icon: Icons.emoji_events_rounded,
              selected: _filterKind == 'trophy',
              onTap: () => setState(() => _filterKind = _filterKind == 'trophy' ? null : 'trophy')),
        ],
      ),
    );
  }

  // ── GRID ────────────────────────────────────────────────

  Widget _buildGrid(List<TrophyWithEarned> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _TrophyCard(
            trophy: items[i],
            onTap: () => _showDetail(items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  // ── DETAIL SHEET ────────────────────────────────────────

  void _showDetail(TrophyWithEarned t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        trophy: t,
        isOwn: _isOwn,
        onIndicateOpponent: _isOwn && t.unlocked && !t.isManualAward && (t.academyId?.isNotEmpty ?? false)
            ? () => _indicateOpponent(t)
            : null,
      ),
    );
  }

  Future<void> _indicateOpponent(TrophyWithEarned t) async {
    Navigator.of(context).pop(); // fecha sheet
    final usageType = await _showUsageTypeDialog();
    if (usageType == null || !mounted) return;
    final apiUsage = usageType == 'planned' ? 'after_training' : 'before_training';
    final opponent = await OpponentPickerSheet.showWithUser(
      context, academyId: t.academyId!, currentUserId: widget.userId, allowSkip: false,
    );
    if (opponent == null || !mounted) return;
    final confirmed = await ExecutionConfirmSheet.show(
      context,
      techniqueName: t.techniqueName ?? t.name,
      opponentName: opponent.name ?? opponent.email,
    );
    if (!confirmed || !mounted) return;
    try {
      final res = await _api.postExecution(
        techniqueId: t.techniqueId, academyId: t.academyId!,
        opponentId: opponent.id, usageType: apiUsage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Aguardando confirmação.')),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<String?> _showUsageTypeDialog() => showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: const Text('A execução foi premeditada focando no troféu/posição do dia?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'planned'), child: const Text('Sim')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'natural'), child: const Text('Não, foi natural')),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  TROPHY CARD
// ─────────────────────────────────────────────────────────────

class _TrophyCard extends StatefulWidget {
  final TrophyWithEarned trophy;
  final VoidCallback onTap;
  const _TrophyCard({required this.trophy, required this.onTap});

  @override
  State<_TrophyCard> createState() => _TrophyCardState();
}

class _TrophyCardState extends State<_TrophyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + math.Random().nextInt(800)),
    );
    if (widget.trophy.unlocked) _shimmer.repeat(reverse: true);
  }

  @override
  void dispose() { _shimmer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t    = widget.trophy;
    final tier = _Tier.of(t);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: t.unlocked ? _C.card : _C.locked,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: t.unlocked
                  ? tier.color.withValues(alpha: 0.35 + _shimmer.value * 0.3)
                  : _C.borderS,
            ),
            boxShadow: t.unlocked
                ? [BoxShadow(color: tier.glow.withValues(alpha: _shimmer.value * 0.7), blurRadius: 14, spreadRadius: 1)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              _TrophyIcon(trophy: t, shimmer: _shimmer.value),
              const SizedBox(height: 8),
              // tier badge
              if (t.unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tier.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tier.label,
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tier.color),
                  ),
                )
              else
                const SizedBox(height: 16),
              const SizedBox(height: 6),
              // name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  t.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.unlocked ? _C.textPri : _C.textMut,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TROPHY ICON
// ─────────────────────────────────────────────────────────────

class _TrophyIcon extends StatelessWidget {
  final TrophyWithEarned trophy;
  final double shimmer;
  const _TrophyIcon({required this.trophy, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final t    = trophy;
    final tier = _Tier.of(t);
    final icon = t.isMedal ? Icons.military_tech_rounded : Icons.emoji_events_rounded;

    if (!t.unlocked) {
      return Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _C.borderS,
          shape: t.isMedal ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: t.isMedal ? null : BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 26, color: _C.textMut),
      );
    }

    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [
          tier.color.withValues(alpha: 0.22 + shimmer * 0.12),
          tier.color.withValues(alpha: 0.04),
        ]),
        shape: t.isMedal ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: t.isMedal ? null : BorderRadius.circular(12),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.55 + shimmer * 0.45),
          width: 1.5,
        ),
      ),
      child: Icon(icon, size: 28, color: tier.color),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DETAIL SHEET
// ─────────────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final TrophyWithEarned trophy;
  final bool isOwn;
  final VoidCallback? onIndicateOpponent;

  const _DetailSheet({required this.trophy, required this.isOwn, this.onIndicateOpponent});

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t    = trophy;
    final tier = _Tier.of(t);
    final icon = t.isMedal ? Icons.military_tech_rounded : Icons.emoji_events_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: t.unlocked ? tier.color.withValues(alpha: 0.4) : _C.border,
        ),
        boxShadow: t.unlocked
            ? [BoxShadow(color: tier.glow.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, -8))]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
          ),
          // icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: t.unlocked
                  ? RadialGradient(colors: [tier.color.withValues(alpha: 0.25), Colors.transparent])
                  : null,
              color: t.unlocked ? null : _C.borderS,
              shape: t.isMedal ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: t.isMedal ? null : BorderRadius.circular(18),
              border: Border.all(
                color: t.unlocked ? tier.color.withValues(alpha: 0.7) : _C.border, width: 2,
              ),
            ),
            child: Icon(icon, size: 40, color: t.unlocked ? tier.color : _C.textMut),
          ),
          const SizedBox(height: 14),
          // rarity + type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: t.unlocked ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${tier.label} · ${t.isMedal ? 'MEDALHA' : 'TROFÉU'}',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2,
                color: t.unlocked ? tier.color : _C.textMut,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // name
          Text(
            t.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: t.unlocked ? _C.textPri : _C.textSec, letterSpacing: 0.3,
            ),
          ),
          // technique name
          if (!t.isManualAward && t.techniqueName != null && t.techniqueName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(t.techniqueName!, style: const TextStyle(fontSize: 13, color: _C.textSec)),
          ],
          // manual award info
          if (t.isManualAward) ...[
            if (t.championshipEventName != null) ...[
              const SizedBox(height: 4),
              Text(t.championshipEventName!, style: const TextStyle(fontSize: 13, color: _C.textSec)),
            ],
            if (t.awardNote != null && t.awardNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t.awardNote!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _C.textSec, height: 1.4)),
            ],
          ],
          const SizedBox(height: 16),
          // progress rows (for non-manual, non-gold)
          if (!t.isManualAward && t.earnedTier != 'gold') ...[
            _ProgressSection(trophy: t),
            const SizedBox(height: 16),
          ],
          // pills row
          Wrap(
            spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
            children: [
              if (t.isManualAward)
                _Pill(icon: Icons.calendar_today_rounded, label: 'Concedido em ${_fmtDate(t.startDate)}', color: _C.purple),
              if (!t.isManualAward)
                _Pill(icon: Icons.date_range_rounded,
                    label: '${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate)}', color: _C.blue),
              if (!t.isManualAward)
                _Pill(icon: Icons.flag_rounded, label: 'Meta: ${t.targetCount}×', color: _C.green),
            ],
          ),
          // indicate opponent button
          if (onIndicateOpponent != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Indicar adversário'),
                onPressed: onIndicateOpponent,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.green,
                  side: const BorderSide(color: _C.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PROGRESS SECTION
// ─────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final TrophyWithEarned trophy;
  const _ProgressSection({required this.trophy});

  @override
  Widget build(BuildContext context) {
    final t = trophy;
    final target = t.targetCount;
    if (target <= 0) return const SizedBox.shrink();

    final bronze = t.bronzeCount + t.silverCount + t.goldCount;
    final silver = t.silverCount + t.goldCount;
    final gold   = t.goldCount;

    final hasBronze = t.earnedTier == 'bronze' || t.earnedTier == 'silver' || t.earnedTier == 'gold';
    final hasSilver = t.earnedTier == 'silver' || t.earnedTier == 'gold';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasBronze)
          _ProgressBar(label: 'Bronze', count: bronze, target: target, color: _C.green),
        if (!hasSilver)
          _ProgressBar(label: 'Prata',  count: silver, target: target, color: _C.blue),
        _ProgressBar(label: 'Ouro',   count: gold,   target: target, color: _C.gold),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final int count;
  final int target;
  final Color color;

  const _ProgressBar({required this.label, required this.count, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (count / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              const Spacer(),
              Text('$count / $target', style: const TextStyle(fontSize: 11, color: _C.textSec)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _C.borderS,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final int flex;

  const _StatCard({required this.label, required this.value, required this.color, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1.2, color: _C.textSec, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _OctoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _OctoChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _C.green.withValues(alpha: 0.15) : _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _C.green : _C.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? _C.green : _C.textSec),
              const SizedBox(width: 5),
            ],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? _C.green : _C.textSec)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _SortMenu({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: _C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _C.border)),
      icon: const Icon(Icons.tune_rounded, color: _C.textSec, size: 20),
      onSelected: onChanged,
      itemBuilder: (_) => [
        _item('tier',     'Tier',          Icons.auto_awesome_rounded),
        _item('unlocked', 'Conquistados',  Icons.lock_open_rounded),
        _item('name',     'Nome',          Icons.sort_by_alpha_rounded),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, String label, IconData icon) {
    final sel = current == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: sel ? _C.green : _C.textSec),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? _C.green : _C.textPri)),
          if (sel) ...[const Spacer(), const Icon(Icons.check_rounded, size: 14, color: _C.green)],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GRID BACKGROUND PAINTER
// ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double opacity;
  const _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.green.withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}
