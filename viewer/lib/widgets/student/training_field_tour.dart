import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/design/app_tokens.dart';

const _prefKey = 'training_field_tour_v1';

// ── Chaves globais para cada elemento-alvo ─────────────────────────────────
final tourKeyHeader   = GlobalKey(debugLabel: 'tour_header');
final tourKeyStreak   = GlobalKey(debugLabel: 'tour_streak');
final tourKeyStats    = GlobalKey(debugLabel: 'tour_stats');
final tourKeyMissions = GlobalKey(debugLabel: 'tour_missions');
final tourKeyTrophies = GlobalKey(debugLabel: 'tour_trophies');
final tourKeyConfirm  = GlobalKey(debugLabel: 'tour_confirm');

// ── Persistência ────────────────────────────────────────────────────────────
Future<bool> trainingFieldTourDone(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('${_prefKey}_$userId') ?? false;
}

Future<void> markTrainingFieldTourDone(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('${_prefKey}_$userId', true);
}

// ── Dados dos slides ─────────────────────────────────────────────────────────
class _TourStep {
  const _TourStep({
    required this.key,
    required this.color,
    required this.title,
    required this.body,
  });

  final GlobalKey key;
  final Color color;
  final String title;
  final String body;
}

final _steps = <_TourStep>[
  _TourStep(
    key: tourKeyHeader,
    color: const Color(0xFF6C63FF),
    title: 'Quanto você evoluiu hoje',
    body: 'Seu nível e XP ficam aqui, sempre atualizados. A tarefa em vídeo no topo pontua uma vez por dia — não perca.',
  ),
  _TourStep(
    key: tourKeyStreak,
    color: const Color(0xFFFF5722),
    title: 'Não quebre a corrente',
    body: 'Seu streak mostra quantos dias seguidos você está ativo. Bônus de pontos por não falhar — consistência é a chave.',
  ),
  _TourStep(
    key: tourKeyStats,
    color: const Color(0xFF00BCD4),
    title: 'Quanto você já treinou',
    body: 'Cada técnica confirmada aparece aqui. São os números que não mentem: frequência, estudos em vídeo e posições executadas.',
  ),
  _TourStep(
    key: tourKeyMissions,
    color: const Color(0xFF4CAF50),
    title: 'As técnicas desta semana',
    body: 'Cada bolinha da trilha é uma missão. Toque para ver o vídeo, praticá-la no treino e registrar sua execução. Conta XP também.',
  ),
  _TourStep(
    key: tourKeyTrophies,
    color: const Color(0xFFFFC107),
    title: 'Marcos da sua jornada',
    body: 'Cada troféu representa uma conquista real no tatame. Complete missões, suba de nível e veja a prateleira crescer.',
  ),
  _TourStep(
    key: tourKeyConfirm,
    color: const Color(0xFF9C27B0),
    title: 'O ciclo fecha aqui',
    body: 'Registrou uma técnica? Aguarde a confirmação do colega. Foi indicado como parceiro? Confirme a execução dele.',
  ),
];

// ── Ponto de entrada ─────────────────────────────────────────────────────────
void showTrainingFieldTour(BuildContext context) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (ctx) => _TourOverlay(
      onClose: () => entry?.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
}

// ── Overlay principal ─────────────────────────────────────────────────────────
class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  Rect? _spotlightRect;
  bool _scrolling = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep(_page));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _focusStep(int index) async {
    if (!mounted) return;
    setState(() => _scrolling = true);

    final step = _steps[index];
    final ctx = step.key.currentContext;

    if (ctx != null) {
      // Rola até o elemento ficar visível
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }

    if (!mounted) return;

    // Tenta obter o rect; se falhar (widget dinâmico ainda renderizando), retenta uma vez
    Rect? rect = _getRectOf(step.key);
    if (rect == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      rect = _getRectOf(step.key);
    }

    // Fallback: se ainda não encontrou, usa um rect central para não travar o tour
    if (rect == null) {
      final size = MediaQuery.sizeOf(context);
      rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.8,
        height: 60,
      );
    }

    setState(() {
      _spotlightRect = rect;
      _scrolling = false;
    });
  }

  Rect? _getRectOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  Future<void> _next() async {
    if (_page < _steps.length - 1) {
      setState(() {
        _page++;
        _spotlightRect = null; // limpa para sumir o spotlight antigo
      });
      await _focusStep(_page);
    } else {
      await _animController.reverse();
      widget.onClose();
    }
  }

  void _skip() {
    _animController.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_page];
    final isLast = _page == _steps.length - 1;
    final spotlight = _spotlightRect;
    final screenSize = MediaQuery.sizeOf(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Máscara escura + recorte spotlight ──
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlight: spotlight,
                  color: step.color,
                  radius: 14,
                ),
              ),
            ),

            // ── Toque fora = fechar (atrás do bubble) ──
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
              ),
            ),

            // ── Balão de conteúdo (por cima do handler) ──
            if (!_scrolling && spotlight != null)
              _buildBubble(step, spotlight, isLast, screenSize),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    _TourStep step,
    Rect spotlight,
    bool isLast,
    Size screenSize,
  ) {
    const bubbleWidth = 340.0;
    const bubbleEstHeight = 240.0;
    const gap = 14.0;
    const padding = 16.0;

    // Coloca abaixo se couber, OU se não houver espaço suficiente acima
    final spaceBelow = screenSize.height - spotlight.bottom;
    final spaceAbove = spotlight.top;
    final placeBelow = spaceBelow >= bubbleEstHeight + gap ||
        spaceAbove < bubbleEstHeight + gap + 24;

    double top = placeBelow
        ? spotlight.bottom + gap
        : spotlight.top - bubbleEstHeight - gap;

    // Garante que o bubble nunca sai da tela
    top = top.clamp(8.0, screenSize.height - bubbleEstHeight - 8.0);

    // Centraliza horizontalmente em relação ao spotlight, mas clampa nas bordas
    double left = spotlight.center.dx - bubbleWidth / 2;
    left = left.clamp(padding, screenSize.width - bubbleWidth - padding);

    return Positioned(
      top: top,
      left: left,
      width: bubbleWidth,
      child: _Bubble(
        step: step,
        index: _page,
        total: _steps.length,
        isLast: isLast,
        placeBelow: placeBelow,
        spotlightCenterX: spotlight.center.dx - left,
        onNext: _next,
        onSkip: _skip,
      ),
    );
  }
}

// ── Pintor do spotlight ──────────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.spotlight,
    required this.color,
    required this.radius,
  });

  final Rect? spotlight;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.80);

    if (spotlight == null) {
      canvas.drawRect(Offset.zero & size, maskPaint);
      return;
    }

    final inflated = spotlight!.inflate(6);
    final rRect = RRect.fromRectAndRadius(inflated, Radius.circular(radius + 4));

    // Máscara com recorte (even-odd)
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // Borda colorida ao redor do elemento
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rRect, borderPaint);

    // Brilho suave
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rRect, glowPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlight != spotlight || old.color != color;
}

// ── Bolha de texto ────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.placeBelow,
    required this.spotlightCenterX,
    required this.onNext,
    required this.onSkip,
  });

  final _TourStep step;
  final int index;
  final int total;
  final bool isLast;
  final bool placeBelow;
  final double spotlightCenterX;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    const arrowW = 18.0;
    // Clamp da seta dentro da borda arredondada do bubble
    final arrowX = spotlightCenterX.clamp(20.0, 340.0 - 20.0) - arrowW / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (placeBelow) _Arrow(left: arrowX, pointUp: true, color: step.color),
        _Card(
          step: step,
          index: index,
          total: total,
          isLast: isLast,
          onNext: onNext,
          onSkip: onSkip,
        ),
        if (!placeBelow) _Arrow(left: arrowX, pointUp: false, color: step.color),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.left,
    required this.pointUp,
    required this.color,
  });

  final double left;
  final bool pointUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: left),
      child: CustomPaint(
        size: const Size(18, 10),
        painter: _ArrowPainter(pointUp: pointUp, color: color),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointUp, required this.color});
  final bool pointUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.pointUp != pointUp || old.color != color;
}

class _Card extends StatelessWidget {
  const _Card({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final _TourStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: step.color.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: step.color.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título + contador
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    color: step.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              Text(
                '${index + 1}/$total',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Corpo
          Text(
            step.body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          // Dots
          Row(
            children: List.generate(total, (i) {
              final active = i == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 5),
                width: active ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? step.color
                      : Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Botões
          Row(
            children: [
              if (!isLast)
                GestureDetector(
                  onTap: onSkip,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      'Pular',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isLast ? 'Entendido!' : 'Próximo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
