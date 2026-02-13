import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';

class PositionFormScreen extends StatefulWidget {
  final Position? position;

  const PositionFormScreen({super.key, this.position});

  @override
  State<PositionFormScreen> createState() => _PositionFormScreenState();
}

class _PositionFormScreenState extends State<PositionFormScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.position != null) {
      _nameCtrl.text = widget.position!.name;
      _slugCtrl.text = widget.position!.slug;
      _descCtrl.text = widget.position!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _slugCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome e slug são obrigatórios');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.position == null) {
        await _api.createPosition(
          name: _nameCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      } else {
        await _api.updatePosition(
          widget.position!.id,
          name: _nameCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo')));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _saving = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('TimeoutException')
            ? 'A requisição expirou (15 s). Verifique se a API está rodando em ${_api.baseUrl}'
            : 'Erro de conexão. A API está rodando em ${_api.baseUrl}?';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.position == null ? 'Nova posição' : 'Editar posição'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 16),
            TextField(controller: _slugCtrl, decoration: const InputDecoration(labelText: 'Slug')),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descrição (opcional)'), maxLines: 2),
            if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
