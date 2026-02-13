import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/screens/admin/technique_form_screen.dart';

class TechniqueListScreen extends StatefulWidget {
  const TechniqueListScreen({super.key});

  @override
  State<TechniqueListScreen> createState() => _TechniqueListScreenState();
}

class _TechniqueListScreenState extends State<TechniqueListScreen> {
  final _api = ApiService();
  List<Technique> _list = [];
  List<Position> _positions = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_api.getTechniques(), _api.getPositions()]);
      setState(() {
        _list = results[0] as List<Technique>;
        _positions = results[1] as List<Position>;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Erro de conexão. A API está rodando em ${_api.baseUrl}?';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _positionName(String id) => _positions.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;

  Future<void> _openForm([Technique? t]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => TechniqueFormScreen(technique: t)));
    _load();
  }

  Future<void> _delete(Technique t) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir técnica'),
      content: Text('Excluir "${t.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteTechnique(t.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Técnica excluída')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Técnicas'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _list.isEmpty ? const Center(child: Text('Nenhuma técnica. Toque em + para criar.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final t = _list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(t.name),
                      subtitle: Text('${_positionName(t.fromPositionId)} → ${_positionName(t.toPositionId)}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(t)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(t)),
                      ]),
                      onTap: () => _openForm(t),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}
