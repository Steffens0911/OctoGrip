import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/screens/admin/marketplace_form_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class MarketplaceListScreen extends StatefulWidget {
  final bool localOnly;

  const MarketplaceListScreen({super.key, this.localOnly = false});

  @override
  State<MarketplaceListScreen> createState() => _MarketplaceListScreenState();
}

class _MarketplaceListScreenState extends State<MarketplaceListScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<MarketplaceItem> _all = [];
  List<MarketplaceItem> _filtered = [];
  bool _loading = true;
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

  void _applyFilters() {
    var list = _all;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((v) =>
              v.title.toLowerCase().contains(q) ||
              (v.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    setState(() => _filtered = list);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getMarketplaceItemsAdmin();
      if (!mounted) return;
      if (widget.localOnly) {
        final academyId = AuthService().currentUser?.academyId;
        if (academyId != null && academyId.isNotEmpty) {
          _all = items.where((v) => v.academyId == academyId).toList();
        } else {
          _all = [];
        }
      } else {
        _all = items;
      }
      _applyFilters();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _openForm([MarketplaceItem? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MarketplaceFormScreen(item: item),
      ),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(MarketplaceItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir anúncio'),
        content: Text('Excluir "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteMarketplaceItem(item.id);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Anúncio excluído.',
        type: AppFeedbackType.success,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  static String _priceShort(MarketplaceItem it) {
    final v = it.priceCents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AuthService().canEditResources();
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Loja / anúncios'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _all.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum anúncio. Toque em + para criar.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Buscar por título ou descrição',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => _applyFilters(),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: EdgeInsets.all(
                                  AppTheme.screenPadding(context)),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final it = _filtered[i];
                                final scope = it.academyName?.isNotEmpty == true
                                    ? it.academyName!
                                    : 'Academia ${it.academyId ?? ""}';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      it.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${_priceShort(it)} · $scope',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondaryOf(
                                                context),
                                          ),
                                    ),
                                    trailing: canEdit
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!it.isActive)
                                                const Icon(
                                                  Icons.visibility_off,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: AppTheme.primary,
                                                ),
                                                onPressed: () => _openForm(it),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => _delete(it),
                                              ),
                                            ],
                                          )
                                        : null,
                                    onTap: () => _openForm(it),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
