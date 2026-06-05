import 'package:flutter/material.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Formulário para criar um campeonato externo.
class ChampionshipEventFormScreen extends StatefulWidget {
  const ChampionshipEventFormScreen({super.key, required this.academyId});
  final String academyId;

  @override
  State<ChampionshipEventFormScreen> createState() =>
      _ChampionshipEventFormScreenState();
}

class _ChampionshipEventFormScreenState
    extends State<ChampionshipEventFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime _eventDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createChampionshipEvent(
        academyId: widget.academyId,
        name: _nameCtrl.text.trim(),
        eventDate:
            '${_eventDate.year}-${_eventDate.month.toString().padLeft(2, '0')}-${_eventDate.day.toString().padLeft(2, '0')}',
        location: _locationCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_eventDate.day.toString().padLeft(2, '0')}/${_eventDate.month.toString().padLeft(2, '0')}/${_eventDate.year}';

    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Novo Campeonato'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do campeonato *',
                hintText: 'Ex: IBJJF São Paulo 2026',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nome obrigatório';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.m),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Local (opcional)',
                hintText: 'Ex: São Paulo, SP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data do evento *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(dateLabel),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar campeonato'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
