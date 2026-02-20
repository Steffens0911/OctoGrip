import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

class PositionFormScreen extends StatefulWidget {
  final String academyId;
  final Position? position;

  const PositionFormScreen({super.key, required this.academyId, this.position});

  @override
  State<PositionFormScreen> createState() => _PositionFormScreenState();
}

class _PositionFormScreenState extends State<PositionFormScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Position> _allPositions = [];
  bool _loadingPositions = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.position != null) {
      _nameCtrl.text = widget.position!.name;
      _descCtrl.text = widget.position!.description ?? '';
    }
    _loadPositions();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPositions() async {
    try {
      final list = await _api.getPositions(academyId: widget.academyId);
      if (mounted) setState(() {
        _allPositions = list..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _loadingPositions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  void _onNameChanged() => setState(() {});

  List<Position> get _filteredPositions {
    final query = _nameCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return _allPositions.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome é obrigatório');
      return;
    }
    
    final nameTrimmed = _nameCtrl.text.trim();
    
    // Verificar possível duplicata ao criar nova posição
    if (widget.position == null) {
      final duplicate = _allPositions.firstWhere(
        (p) => p.name.toLowerCase().trim() == nameTrimmed.toLowerCase(),
        orElse: () => Position(id: '', name: '', slug: ''),
      );
      if (duplicate.id.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Posição já existe'),
            content: Text('Já existe uma posição chamada "${duplicate.name}".\n\nDeseja criar mesmo assim?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Criar mesmo assim'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }
    
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.position == null) {
        await _api.createPosition(
          academyId: widget.academyId,
          name: nameTrimmed,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      } else {
        await _api.updatePosition(
          widget.position!.id,
          academyId: widget.academyId,
          name: nameTrimmed,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _saving = false; });
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
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Guarda fechada',
                helperText: 'Digite para ver posições similares',
              ),
            ),
            if (_nameCtrl.text.trim().isNotEmpty && _filteredPositions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posições encontradas (${_filteredPositions.length}):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._filteredPositions.take(5).map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (_filteredPositions.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... e mais ${_filteredPositions.length - 5}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
