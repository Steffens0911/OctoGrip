import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/screens/admin/partner_form_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Lista de parceiros da academia (CRUD pelo gestor/admin).
class PartnerListScreen extends StatefulWidget {
  final Academy academy;

  const PartnerListScreen({super.key, required this.academy});

  @override
  State<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends State<PartnerListScreen> {
  final ApiService _api = ApiService();
  List<Partner> _list = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getPartners(widget.academy.id);
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parceiro excluído')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parceiros — ${widget.academy.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final p = _list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                p.description ?? (p.url ?? ''),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: AuthService().canEditResources()
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppTheme.primary),
                                          onPressed: () => _openForm(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
