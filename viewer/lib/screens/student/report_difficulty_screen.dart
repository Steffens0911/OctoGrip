import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Reportar dificuldade: escolher posição e opcional observação, POST /training_feedback.
class ReportDifficultyScreen extends StatefulWidget {
  final String userId;
  final String? academyId;

  const ReportDifficultyScreen({super.key, required this.userId, this.academyId});

  @override
  State<ReportDifficultyScreen> createState() => _ReportDifficultyScreenState();
}

class _ReportDifficultyScreenState extends State<ReportDifficultyScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  List<Position> _positions = [];
  Position? _selectedPosition;
  final _observationController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.academyId == null || widget.academyId!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Você precisa estar vinculado a uma academia para reportar dificuldade.';
      });
      return;
    }
    try {
      final list = await _api.getPositions(academyId: widget.academyId!);
      if (mounted) setState(() {
        _positions = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedPosition == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.postTrainingFeedback(
        userId: widget.userId,
        positionId: _selectedPosition!.id,
        observation: _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dificuldade registrada.'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar dificuldade')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _positions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Em qual posição você teve mais dificuldade no treino?',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Position>(
                          value: _selectedPosition,
                          decoration: const InputDecoration(
                            labelText: 'Posição',
                            border: OutlineInputBorder(),
                          ),
                          items: _positions
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.name),
                                  ))
                              .toList(),
                          onChanged: (p) => setState(() => _selectedPosition = p),
                          validator: (v) => v == null ? 'Escolha uma posição' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _observationController,
                          decoration: const InputDecoration(
                            labelText: 'Observação (opcional)',
                            hintText: 'Ex.: dificuldade para sair da guarda fechada',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 2,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _sending ? null : _submit,
                          child: Text(_sending ? 'Enviando...' : 'Enviar'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
