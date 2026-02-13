import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/screens/admin/user_form_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _api = ApiService();
  List<models.UserModel> _list = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getUsers();
      setState(() { _list = list; _loading = false; });
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

  Future<void> _openForm([models.UserModel? user]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormScreen(user: user)));
    _load();
  }

  Future<void> _delete(models.UserModel u) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir usuário'),
      content: Text('Excluir "${u.email}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteUser(u.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _list.isEmpty ? const Center(child: Text('Nenhum usuário. Toque em + para criar.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final u = _list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(u.email),
                      subtitle: Text(u.name ?? '—'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(u)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(u)),
                      ]),
                      onTap: () => _openForm(u),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}
