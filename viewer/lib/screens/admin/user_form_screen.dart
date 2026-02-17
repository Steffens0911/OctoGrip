import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

class UserFormScreen extends StatefulWidget {
  final models.UserModel? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static const List<MapEntry<String, String>> _graduations = [
    MapEntry('white', 'Branca'),
    MapEntry('blue', 'Azul'),
    MapEntry('purple', 'Roxa'),
    MapEntry('brown', 'Marrom'),
    MapEntry('black', 'Preta'),
  ];

  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _graduation;
  String? _academyId;
  List<Academy> _academies = [];
  bool _loadingAcademies = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _emailCtrl.text = widget.user!.email;
      _nameCtrl.text = widget.user!.name ?? '';
      _graduation = widget.user!.graduation?.isNotEmpty == true ? widget.user!.graduation : 'white';
      _academyId = widget.user!.academyId;
    } else {
      _graduation = 'white';
    }
    _loadAcademies();
  }

  Future<void> _loadAcademies() async {
    try {
      final list = await _api.getAcademies();
      if (mounted) setState(() {
        _academies = list;
        _loadingAcademies = false;
        if (_academyId == null && widget.user?.academyId != null) _academyId = widget.user!.academyId;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAcademies = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'E-mail é obrigatório');
      return;
    }
    final grad = _graduation?.trim();
    if (grad == null || grad.isEmpty) {
      setState(() => _error = 'Graduação (faixa) é obrigatória');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.user == null) {
        await _api.createUser(
          email: _emailCtrl.text.trim(),
          name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          graduation: grad,
          academyId: _academyId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário criado')));
          Navigator.pop(context);
        }
      } else {
        await _api.updateUser(
          widget.user!.id,
          name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          graduation: grad,
          academyId: _academyId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar usuário' : 'Novo usuário'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail'), enabled: !isEdit, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _graduation ?? 'white',
              decoration: const InputDecoration(labelText: 'Graduação (faixa) *'),
              items: _graduations.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _graduation = v ?? 'white'),
            ),
            const SizedBox(height: 16),
            _loadingAcademies ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                : DropdownButtonFormField<String>(
                    value: _academyId,
                    decoration: const InputDecoration(labelText: 'Academia'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                      ..._academies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() => _academyId = v),
                  ),
            if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
