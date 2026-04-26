import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/screens/admin/global_partner_form_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class GlobalPartnerListScreen extends StatefulWidget {
  const GlobalPartnerListScreen({super.key});

  @override
  State<GlobalPartnerListScreen> createState() => _GlobalPartnerListScreenState();
}

class _GlobalPartnerListScreenState extends State<GlobalPartnerListScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<GlobalPartner> _list = [];

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
      final list = await _api.getGlobalPartnersAdmin();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _openForm([GlobalPartner? partner]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalPartnerFormScreen(partner: partner),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(GlobalPartner partner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir parceiro global'),
        content: Text('Excluir "${partner.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteGlobalPartner(partner.id);
      if (mounted) _load();
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Parceiro global excluído',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(
        title: 'Parceiros globais',
        subtitle: 'Banner da Central (todas as academias)',
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
                        'Nenhum parceiro global. Toque em + para criar.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                        itemCount: _list.length,
                        itemBuilder: (context, index) {
                          final p = _list[index];
                          final subtitle = <String>[
                            if (!p.isActive) 'Inativo',
                            if (p.featuredOrder != null) 'Ordem ${p.featuredOrder}',
                            if ((p.offerText ?? '').trim().isNotEmpty) p.offerText!.trim(),
                            if ((p.offerText ?? '').trim().isEmpty && (p.description ?? '').trim().isNotEmpty)
                              p.description!.trim(),
                          ].join(' • ');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primary),
                                    onPressed: () => _openForm(p),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                    onPressed: () => _delete(p),
                                  ),
                                ],
                              ),
                              onTap: () => _openForm(p),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
