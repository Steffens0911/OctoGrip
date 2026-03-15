import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/position_form_screen.dart';
import 'package:viewer/utils/error_message.dart';

class PositionListScreen extends StatefulWidget {
  final String academyId;

  const PositionListScreen({super.key, required this.academyId});

  @override
  State<PositionListScreen> createState() => _PositionListScreenState();
}

class _PositionListScreenState extends State<PositionListScreen> {
  final _api = ApiService();
  List<Position> _list = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getPositions(academyId: widget.academyId);
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openForm([Position? p]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => PositionFormScreen(academyId: widget.academyId, position: p)));
    if (mounted) await _load();
  }

  Future<void> _delete(Position p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir posição'),
      content: Text('Excluir "${p.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deletePosition(p.id, academyId: widget.academyId);
      if (mounted) await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posição excluída')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posições'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _list.isEmpty ? const Center(child: Text('Nenhuma posição. Toque em + para criar.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final p = _list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.description ?? ''),
                      trailing: AuthService().canEditResources() ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(p)),
                        IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(p)),
                      ]) : null,
                      onTap: () => _openForm(p),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: AuthService().canEditResources() ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
    );
  }
}
