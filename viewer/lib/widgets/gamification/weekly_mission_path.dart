import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission_today.dart';

/// Tamanho mínimo recomendado para alvos tocáveis (Material / acessibilidade).
const double kWeeklyPathMinTapSize = 48;

/// Caminho horizontal tipo ●──●──● para as missões semanais (slots da API).
///
/// Estados por slot:
/// - **Concluída**: círculo com ✓; segmento à direita preenchido se esta missão está feita.
/// - **Disponível**: contorno destacado + play; toque abre a lição (com haptic leve).
/// - **Sem missão**: cadeado.
///
/// [celebrateMissionId]: ao voltar da lição com missão recém-concluída, o nó correspondente
/// faz um pulso de escala (micro-animação).
class WeeklyMissionPath extends StatefulWidget {
  const WeeklyMissionPath({
    super.key,
    required this.slots,
    this.onMissionTap,
    this.celebrateMissionId,
    this.onCelebrateComplete,
    this.semanticsLabel = 'Caminho das missões da semana',
  });

  final List<MissionWeekSlot> slots;
  final void Function(MissionToday mission, String periodLabel)? onMissionTap;
  /// Missão que acabou de ser concluída (dispara animação uma vez).
  final String? celebrateMissionId;
  final VoidCallback? onCelebrateComplete;
  final String semanticsLabel;

  @override
  State<WeeklyMissionPath> createState() => _WeeklyMissionPathState();
}

class _WeeklyMissionPathState extends State<WeeklyMissionPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrateC;
  late final Animation<double> _celebrateScale;
  String? _animatingMissionId;

  @override
  void initState() {
    super.initState();
    _celebrateC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _celebrateScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_celebrateC);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartCelebrateFromProp();
    });
  }

  void _maybeStartCelebrateFromProp() {
    final id = widget.celebrateMissionId;
    if (id == null || id.isEmpty) return;
    _startCelebrateIfEligible(id);
  }

  @override
  void didUpdateWidget(covariant WeeklyMissionPath oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.celebrateMissionId;
    if (id == null || id.isEmpty || _celebrateC.isAnimating) return;
    final propChanged = id != oldWidget.celebrateMissionId;
    final slotsBecameAvailable =
        widget.slots.isNotEmpty && oldWidget.slots.isEmpty;
    if (propChanged || slotsBecameAvailable) {
      _startCelebrateIfEligible(id);
    }
  }

  Future<void> _startCelebrateIfEligible(String missionId) async {
    final ok = widget.slots.any(
      (s) =>
          s.mission?.missionId == missionId &&
          (s.mission?.alreadyCompleted ?? false),
    );
    if (!ok || !mounted || _celebrateC.isAnimating) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      widget.onCelebrateComplete?.call();
      return;
    }
    setState(() => _animatingMissionId = missionId);
    try {
      await _celebrateC.forward();
    } finally {
      if (mounted) {
        _celebrateC.reset();
        setState(() => _animatingMissionId = null);
        widget.onCelebrateComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    _celebrateC.dispose();
    super.dispose();
  }

  double _scaleFor(MissionToday? m) {
    final mid = m?.missionId;
    if (_animatingMissionId == null || mid == null) return 1.0;
    if (mid != _animatingMissionId) return 1.0;
    return _celebrateScale.value;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: widget.semanticsLabel,
      child: AnimatedBuilder(
        animation: _celebrateScale,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PathRow(
                slots: widget.slots,
                onMissionTap: widget.onMissionTap,
                scaleFor: _scaleFor,
              ),
              const SizedBox(height: 8),
              _TechniqueRow(slots: widget.slots),
              const SizedBox(height: 10),
              _StatusRow(
                slots: widget.slots,
                onMissionTap: widget.onMissionTap,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.slots,
    this.onMissionTap,
    required this.scaleFor,
  });

  final List<MissionWeekSlot> slots;
  final void Function(MissionToday mission, String periodLabel)? onMissionTap;
  final double Function(MissionToday? m) scaleFor;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      if (i > 0) {
        final leftDone = slots[i - 1].mission?.alreadyCompleted ?? false;
        children.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: _Segment(filled: leftDone),
            ),
          ),
        );
      }
      children.add(
        _PathNode(
          slot: slots[i],
          onMissionTap: onMissionTap,
          scale: scaleFor(slots[i].mission),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final done = Colors.green.shade600;
    final scheme = Theme.of(context).colorScheme;
    final pending = Color.alphaBlend(
      scheme.outline.withValues(alpha: 0.55),
      scheme.surface,
    );
    return LayoutBuilder(
      builder: (context, c) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            height: 4,
            width: c.maxWidth,
            decoration: BoxDecoration(
              color: filled ? done : pending,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _PathNode extends StatelessWidget {
  const _PathNode({
    required this.slot,
    this.onMissionTap,
    this.scale = 1.0,
  });

  final MissionWeekSlot slot;
  final void Function(MissionToday mission, String periodLabel)? onMissionTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final m = slot.mission;
    final completed = m?.alreadyCompleted ?? false;
    final hasMission = m != null;

    Widget node;
    if (!hasMission) {
      node = _circle(
        context,
        child: Icon(Icons.lock_outline_rounded,
            size: 20, color: AppTheme.textMutedOf(context)),
        border: AppTheme.borderOf(context),
        fill: AppTheme.surfaceOf(context),
      );
    } else if (completed) {
      node = _circle(
        context,
        child: const Icon(Icons.check_rounded, size: 22, color: Colors.white),
        border: Colors.green.shade700,
        fill: Colors.green.shade600,
      );
    } else {
      node = _circle(
        context,
        child: Icon(Icons.play_arrow_rounded,
            size: 24, color: Theme.of(context).colorScheme.primary),
        border: Theme.of(context).colorScheme.primary,
        fill: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        width: 2.5,
      );
    }

    node = Transform.scale(
      scale: scale,
      child: node,
    );

    final canTap = hasMission && onMissionTap != null;
    if (canTap) {
      node = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!MediaQuery.disableAnimationsOf(context)) {
              HapticFeedback.selectionClick();
            }
            onMissionTap!(m, slot.periodLabel);
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: kWeeklyPathMinTapSize,
            height: kWeeklyPathMinTapSize,
            child: Center(child: node),
          ),
        ),
      );
    } else {
      node = SizedBox(
        width: kWeeklyPathMinTapSize,
        height: kWeeklyPathMinTapSize,
        child: Center(child: node),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: node,
    );
  }

  Widget _circle(
    BuildContext context, {
    required Widget child,
    required Color border,
    required Color fill,
    double width = 2,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: width),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

/// Nome da técnica por slot, alinhado às colunas do caminho (mesma estrutura de [Expanded] + largura fixa).
class _TechniqueRow extends StatelessWidget {
  const _TechniqueRow({required this.slots});

  final List<MissionWeekSlot> slots;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondaryOf(context),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
        );
    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      if (i > 0) {
        children.add(
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox.shrink(),
            ),
          ),
        );
      }
      final m = slots[i].mission;
      final text = m == null
          ? '—'
          : (m.techniqueName.isNotEmpty
              ? m.techniqueName
              : (m.lessonTitle.isNotEmpty ? m.lessonTitle : slots[i].periodLabel));
      children.add(
        SizedBox(
          width: kWeeklyPathMinTapSize,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.slots,
    this.onMissionTap,
  });

  final List<MissionWeekSlot> slots;
  final void Function(MissionToday mission, String periodLabel)? onMissionTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      if (i > 0) {
        children.add(const Expanded(child: SizedBox.shrink()));
      }
      children.add(
        SizedBox(
          width: kWeeklyPathMinTapSize,
          child: _StatusCell(
            slot: slots[i],
            onMissionTap: onMissionTap,
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.slot,
    this.onMissionTap,
  });

  final MissionWeekSlot slot;
  final void Function(MissionToday mission, String periodLabel)? onMissionTap;

  @override
  Widget build(BuildContext context) {
    final m = slot.mission;
    final hasMission = m != null;
    final completed = m?.alreadyCompleted ?? false;

    late final IconData icon;
    late final Color color;
    late final String label;

    if (!hasMission) {
      icon = Icons.lock_outline_rounded;
      color = AppTheme.textMutedOf(context);
      label = 'Bloqueado';
    } else if (completed) {
      icon = Icons.check_rounded;
      color = Colors.green.shade700;
      label = 'Feito';
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      color = Theme.of(context).colorScheme.primary;
      label = 'Treinar';
    }

    final canTap = hasMission && onMissionTap != null;
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
        ),
      ],
    );

    if (!canTap) {
      return Semantics(
        label: '${slot.periodLabel}: $label',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kWeeklyPathMinTapSize),
          child: Center(child: inner),
        ),
      );
    }

    return Semantics(
      label: '${slot.periodLabel}: $label. Toque para abrir.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!MediaQuery.disableAnimationsOf(context)) {
              HapticFeedback.selectionClick();
            }
            onMissionTap!(m, slot.periodLabel);
          },
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kWeeklyPathMinTapSize,
              minHeight: kWeeklyPathMinTapSize,
            ),
            child: Center(child: inner),
          ),
        ),
      ),
    );
  }
}
