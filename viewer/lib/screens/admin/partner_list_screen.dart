import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/screens/admin/partner_form_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Lista de parceiros da academia (CRUD pelo gestor/admin).
class PartnerListScreen extends StatefulWidget {
  final Academy academy;

  const PartnerListScreen({super.key, required this.academy});

  @override
  State<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends State<PartnerListScreen> {
  final ApiService _api = ApiService();
  static const int _pageSize = 50;
  List<Partner> _list = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  Future<void> _toggleHighlight(Partner partner) async {
    final current = partner.highlightOnLogin;
    try {
      await _api.updatePartner(
        partnerId: partner.id,
        academyId: widget.academy.id,
        highlightOnLogin: !current,
      );
      if (!mounted) return;
      setState(() {
        _list = _list
            .map(
              (p) => p.id == partner.id
                  ? Partner(
                      id: p.id,
                      academyId: p.academyId,
                      name: p.name,
                      description: p.description,
                      url: p.url,
                      logoUrl: p.logoUrl,
                      highlightOnLogin: !current,
                    )
                  : p,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
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
      final list = await _api.getPartners(widget.academy.id, offset: _offset, limit: _pageSize);
      if (mounted) {
        setState(() {
          if (reset) {
            _list = list;
            _loading = false;
          } else {
            _list = [..._list, ...list];
            _loadingMore = false;
          }
          _offset += list.length;
          _hasMore = list.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          if (reset) {
            _loading = false;
          } else {
            _loadingMore = false;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openForm([Partner? partner]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnerFormScreen(
          academy: widget.academy,
          partner: partner,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Partner partner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir parceiro'),
        content: Text('Excluir "${partner.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deletePartner(partner.id, widget.academy.id);
      if (mounted) _load();
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Parceiro excluído',
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Parceiros',
        subtitle: widget.academy.name,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum parceiro. Toque em + para criar.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                        itemCount: _list.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _list.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton.icon(
                                        onPressed: () => _load(reset: false),
                                        icon: const Icon(Icons.expand_more),
                                        label: const Text('Carregar mais'),
                                      ),
                              ),
                            );
                          }
                          final p = _list[i];
                          final subtitleParts = <String>[
                            if (p.highlightOnLogin) 'Pop-up inicial',
                            if ((p.description ?? '').trim().isNotEmpty) p.description!.trim(),
                            if ((p.description ?? '').trim().isEmpty && (p.url ?? '').trim().isNotEmpty) p.url!.trim(),
                          ];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                subtitleParts.join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: AuthService().canEditResources()
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: p.highlightOnLogin
                                              ? 'Remover deste pop-up inicial'
                                              : 'Destacar no pop-up inicial',
                                          icon: Icon(
                                            p.highlightOnLogin
                                                ? Icons.campaign
                                                : Icons.campaign_outlined,
                                            color: p.highlightOnLogin
                                                ? AppTheme.primary
                                                : AppTheme.textSecondaryOf(context),
                                          ),
                                          onPressed: () => _toggleHighlight(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppTheme.primary),
                                          onPressed: () => _openForm(p),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                          onPressed: () => _delete(p),
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () => _openForm(p),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: AuthService().canEditResources()
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
