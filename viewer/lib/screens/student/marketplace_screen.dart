import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final _searchCtrl = TextEditingController();
  static const int _pageSize = 20;
  List<MarketplaceItem> _items = [];
  List<MarketplaceItem> _filtered = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _items
          : _items
              .where((it) =>
                  it.title.toLowerCase().contains(q) ||
                  (it.description?.toLowerCase().contains(q) ?? false))
              .toList();
    });
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final list = await _api.getMeMarketplaceItems(
        offset: _offset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = list;
          _loading = false;
        } else {
          _items = [..._items, ...list];
          _loadingMore = false;
        }
        _offset += list.length;
        _hasMore = list.length == _pageSize;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _loading = false;
        } else {
          _loadingMore = false;
        }
        _error = userFacingMessage(e);
      });
    }
  }

  static String _priceLabel(MarketplaceItem it) {
    final v = it.priceCents / 100.0;
    if ((it.currency).toUpperCase() == 'BRL') {
      return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(v);
    }
    return '${it.currency} ${v.toStringAsFixed(2)}';
  }

  Future<void> _openWhatsApp(MarketplaceItem it) async {
    final wa = it.whatsappUrl;
    if (wa == null || wa.isEmpty) return;
    _api.recordMarketplaceWhatsappClick(it.id);
    final uri = Uri.tryParse(wa.trim());
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
        onRefresh: () => _load(reset: true),
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar produto...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _applyFilter();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => _applyFilter(),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filtered.isEmpty
                              ? 1
                              : _filtered.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'Nenhum produto encontrado.'
                                      : 'Nenhum produto anunciado no momento.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                ),
                              );
                            }
                            if (index >= _filtered.length) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton.icon(
                                          onPressed: () => _load(reset: false),
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('Ver mais produtos'),
                                        ),
                                ),
                              );
                            }
                            final it = _filtered[index];
                            return _ItemCard(
                              item: it,
                              priceLabel: _priceLabel(it),
                              onWhatsApp: it.whatsappUrl != null &&
                                      it.whatsappUrl!.isNotEmpty
                                  ? () => _openWhatsApp(it)
                                  : null,
                            );
                          },
                        ),
                      ),
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
              child: CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.grey.shade600)),
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
