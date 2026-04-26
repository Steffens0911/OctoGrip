import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/widgets/app_feedback.dart';

class FeaturedPartnersBanner extends StatefulWidget {
  final List<GlobalPartner> partners;

  const FeaturedPartnersBanner({
    super.key,
    required this.partners,
  });

  @override
  State<FeaturedPartnersBanner> createState() => _FeaturedPartnersBannerState();
}

class _FeaturedPartnersBannerState extends State<FeaturedPartnersBanner> {
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
  void didUpdateWidget(covariant FeaturedPartnersBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partners.length != widget.partners.length) {
      _index = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
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

  Future<void> _openOffer(GlobalPartner p) async {
    final raw = (p.externalUrl?.trim().isNotEmpty ?? false)
        ? p.externalUrl!.trim()
        : null;
    if (raw == null) return;

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
    final tagColor = primary;
    final dotActive = primary;
    const dotInactive = Color(0xFF2E3547);

    const bg1 = AppTheme.premiumSurfaceElevatedDark;
    const bg2 = AppTheme.premiumBackgroundDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            itemCount: partners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _Card(
              partner: partners[i],
              tagColor: tagColor,
              bg1: bg1,
              bg2: bg2,
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
                    color: active ? dotActive : dotInactive,
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
  final GlobalPartner partner;
  final VoidCallback onOpen;
  final Color tagColor;
  final Color bg1;
  final Color bg2;

  const _Card({
    required this.partner,
    required this.onOpen,
    required this.tagColor,
    required this.bg1,
    required this.bg2,
  });

  @override
  Widget build(BuildContext context) {
    final name = partner.name.trim();
    final offer = (partner.offerText ?? '').trim();
    final buttonText = (partner.buttonLabel ?? '').trim().isNotEmpty
        ? (partner.buttonLabel ?? '').trim()
        : 'Ver oferta';

    final primaryText = AppTheme.textPrimaryOf(context);
    final secondaryText = AppTheme.textSecondaryOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg1, bg2],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                        color: tagColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (offer.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        offer,
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
                  onPressed: onOpen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tagColor,
                    foregroundColor: AppTheme.premiumBackgroundDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(buttonText),
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

