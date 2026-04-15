import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Lista de produtos anunciados pela academia (contato via WhatsApp).
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _api = ApiService();
  List<MarketplaceItem> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await _api.getMeMarketplaceItems();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  static String _priceLabel(MarketplaceItem it) {
    final v = it.priceCents / 100.0;
    if ((it.currency).toUpperCase() == 'BRL') {
      return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$')
          .format(v);
    }
    return '${it.currency} ${v.toStringAsFixed(2)}';
  }

  Future<void> _openWhatsApp(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Loja da academia'),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                : ListView(
                    padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            'Nenhum produto anunciado no momento.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                          ),
                        )
                      else
                        ..._items.map((it) {
                          final wa = it.whatsappUrl;
                          return _ItemCard(
                            item: it,
                            priceLabel: _priceLabel(it),
                            onWhatsApp: wa != null && wa.isNotEmpty
                                ? () => _openWhatsApp(wa)
                                : null,
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final MarketplaceItem item;
  final String priceLabel;
  final VoidCallback? onWhatsApp;

  const _ItemCard({
    required this.item,
    required this.priceLabel,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final img = item.imageUrl;
    final resolved = img != null && img.isNotEmpty
        ? (img.startsWith('/') ? '${api.baseUrl}$img' : img)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (resolved != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.grey.shade600),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                ],
                if (onWhatsApp != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('Chamar no WhatsApp'),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Este anúncio não inclui WhatsApp.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
