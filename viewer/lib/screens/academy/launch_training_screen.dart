import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_session.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Tela para o professor lançar um treino (equivale à enquete do WhatsApp).
class LaunchTrainingScreen extends StatefulWidget {
  final String academyId;
  final VoidCallback? onLaunched;

  const LaunchTrainingScreen({
    super.key,
    required this.academyId,
    this.onLaunched,
  });

  @override
  State<LaunchTrainingScreen> createState() => _LaunchTrainingScreenState();
}

class _LaunchTrainingScreenState extends State<LaunchTrainingScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  List<TrainingTemplate> _templates = [];
  bool _loadingTemplates = true;
  bool _saving = false;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  int _toleranceMinutes = 15;
  final TextEditingController _labelController = TextEditingController();
  bool _saveAsTemplate = false;

  static const _toleranceOptions = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    // Default: amanhã
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _loadTemplates();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final raw = await _api.getTrainingTemplates(widget.academyId);
      if (mounted) {
        setState(() {
          _templates = raw.map(TrainingTemplate.fromJson).toList();
          _loadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  void _applyTemplate(TrainingTemplate t) {
    final parts = t.startTime.split(':');
    setState(() {
      _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _toleranceMinutes = t.toleranceMinutes;
      if (t.label != null) _labelController.text = t.label!;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _launch() async {
    if (_saving) return;
    setState(() => _saving = true);
    final classDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final label = _labelController.text.trim();
    try {
      // Salvar como favorito se marcado
      if (_saveAsTemplate) {
        await _api.createTrainingTemplate(
          widget.academyId,
          label: label.isEmpty ? null : label,
          startTime: startTime,
          toleranceMinutes: _toleranceMinutes,
        );
      }
      await _api.createTrainingSession(
        widget.academyId,
        classDate: classDate,
        startTime: startTime,
        toleranceMinutes: _toleranceMinutes,
        label: label.isEmpty ? null : label,
      );
      if (!mounted) return;
      AppFeedback.show(context, message: 'Treino lançado!', type: AppFeedbackType.success);
      widget.onLaunched?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _deleteTemplate(TrainingTemplate t) async {
    try {
      await _api.deleteTrainingTemplate(t.id);
      if (!mounted) return;
      await _loadTemplates();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Lançar treino'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingTemplates)
                const Center(child: CircularProgressIndicator())
              else if (_templates.isNotEmpty) ...[
                Text(
                  'Favoritos',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _templates
                      .map(
                        (t) => InputChip(
                          label: Text(t.displayName),
                          onPressed: () => _applyTemplate(t),
                          onDeleted: () => _deleteTemplate(t),
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do treino (opcional)',
                          hintText: 'ex: Adulto Gi, Kids, NoGi...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_outlined),
                        label: Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _toleranceMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Tolerância para bater presença',
                          border: OutlineInputBorder(),
                        ),
                        items: _toleranceOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m == 1 ? '1 minuto' : '$m minutos após o início',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _toleranceMinutes = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Salvar como favorito'),
                        subtitle: const Text('Aparece nos chips acima para lançar rápido.'),
                        value: _saveAsTemplate,
                        onChanged: (v) => setState(() => _saveAsTemplate = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _launch,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_saving ? 'Lançando...' : 'Lançar treino'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
