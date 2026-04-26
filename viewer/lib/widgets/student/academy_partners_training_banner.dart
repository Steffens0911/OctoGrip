import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/widgets/app_feedback.dart';

/// Banner rotativo de parceiros da academia para a tela "Campo de treinamento".
class AcademyPartnersTrainingBanner extends StatefulWidget {
  final List<Partner> partners;

  const AcademyPartnersTrainingBanner({
    super.key,
    required this.partners,
  });

  @override
  State<AcademyPartnersTrainingBanner> createState() =>
      _AcademyPartnersTrainingBannerState();
}

class _AcademyPartnersTrainingBannerState
    extends State<AcademyPartnersTrainingBanner> {
  final _pageController = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _index = 0;

  bool get _canAutoAdvance => widget.partners.length > 1;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AcademyPartnersTrainingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partners.length != widget.partners.length) {
      _index = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (!_canAutoAdvance) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % widget.partners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openOffer(Partner partner) async {
    final raw = partner.url?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Não foi possível abrir a oferta.',
      type: AppFeedbackType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final partners = widget.partners;
    if (partners.isEmpty) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    const dotInactive = Color(0xFF2E3547);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 112,
          child: PageView.builder(
            controller: _pageController,
            itemCount: partners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _Card(
              partner: partners[i],
              accent: primary,
              onOpen: () => _openOffer(partners[i]),
            ),
          ),
        ),
        if (partners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(partners.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? primary : dotInactive,
                    borderRadius: BorderRadius.circular(active ? 3 : 6),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Partner partner;
  final VoidCallback onOpen;
  final Color accent;

  const _Card({
    required this.partner,
    required this.onOpen,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppTheme.textPrimaryOf(context);
    final secondaryText = AppTheme.textSecondaryOf(context);
    final description = (partner.description ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.premiumSurfaceElevatedDark,
              AppTheme.premiumBackgroundDark,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _PartnerAvatar(logoUrl: partner.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARCEIRO EM DESTAQUE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      partner.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: (partner.url != null && partner.url!.trim().isNotEmpty)
                      ? onOpen
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppTheme.premiumBackgroundDark,
                    disabledBackgroundColor: accent.withValues(alpha: 0.35),
                    disabledForegroundColor:
                        AppTheme.premiumBackgroundDark.withValues(alpha: 0.65),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Ver oferta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  final String? logoUrl;

  const _PartnerAvatar({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final hasLogo = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.premiumPrimary.withValues(alpha: 0.14),
      foregroundImage: hasLogo ? NetworkImage(url) : null,
      child: const Icon(Icons.handshake_outlined),
    );
  }
}
