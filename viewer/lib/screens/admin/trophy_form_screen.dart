import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/features/trophies/data/mappers/trophy_mapper.dart';
import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Formulário criar/editar troféu. Ao editar regras sensíveis, avisa impacto nas conquistas.
class TrophyFormScreen extends StatefulWidget {
  const TrophyFormScreen({
    super.key,
    required this.academyId,
    this.trophy,
  });

  final String academyId;
  final TrophyEntity? trophy;

  @override
  State<TrophyFormScreen> createState() => _TrophyFormScreenState();
}

class _TrophyFormScreenState extends State<TrophyFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormBuilderState>();
  List<Technique> _techniques = [];
  bool _loadingTech = true;
  bool _saving = false;
  String? _error;
  /// Novo registo: padrão medalha (período curto permitido). Troféu especial exige duração mínima.
  String _awardKind = 'medal';

  String? _initialTechniqueId;
  String? _initialStartIso;
  String? _initialEndIso;
  int? _initialTarget;
  String? _initialAwardKind;
  int? _initialMinDuration;
  int? _initialMaxCountPerOpponent;

  @override
  void initState() {
    super.initState();
    final t = widget.trophy;
    if (t != null) {
      _initialTechniqueId = t.techniqueId;
      _initialStartIso = t.startDateIso;
      _initialEndIso = t.endDateIso;
      _initialTarget = t.targetCount;
      _initialAwardKind = t.awardKind;
      _initialMinDuration = t.minDurationDays;
      _initialMaxCountPerOpponent = t.maxCountPerOpponent;
      _awardKind = t.awardKind;
    } else {
      _awardKind = 'medal';
    }
    _loadTechniques();
  }

  Future<void> _loadTechniques() async {
    setState(() => _loadingTech = true);
    try {
      _api.invalidateCache('GET:${_api.baseUrl}/techniques');
      final list = await _api.getTechniques(academyId: widget.academyId, cacheBust: true);
      if (mounted) {
        setState(() {
          _techniques = list
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _loadingTech = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTech = false);
    }
  }

  bool _sensitiveChanged(Map<String, dynamic> values) {
    if (widget.trophy == null) return false;
    final techniqueId = values['techniqueId'] as String?;
    final start = values['startDate'] as DateTime?;
    final end = values['endDate'] as DateTime?;
    final target = int.tryParse(values['targetCount'] as String? ?? '');
    final kind = values['awardKind'] as String? ?? 'trophy';
    int? minDur;
    if (kind == 'trophy') {
      minDur = int.tryParse((values['minDurationDays'] as String?) ?? '30') ?? 30;
    }
    if (techniqueId != _initialTechniqueId) return true;
    if (start != null && toApiDate(start) != _initialStartIso) return true;
    if (end != null && toApiDate(end) != _initialEndIso) return true;
    if (target != null && target != _initialTarget) return true;
    if (kind != _initialAwardKind) return true;
    if (kind == 'trophy' && minDur != _initialMinDuration) return true;
    final maxRaw = (values['maxCountPerOpponent'] as String?)?.trim() ?? '';
    final maxVal = maxRaw.isEmpty ? null : int.tryParse(maxRaw);
    if (maxVal != _initialMaxCountPerOpponent) return true;
    return false;
  }

  Future<bool> _confirmSensitiveEdit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar regras do troféu'),
        content: const Text(
          'Alterar período, técnica, meta ou tipo pode mudar quem já conquistou ouro, prata ou bronze. '
          'Deseja continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() != true) return;
    if (_techniques.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Cadastre técnicas antes.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    final values = _formKey.currentState!.value;
    if (_sensitiveChanged(values)) {
      final ok = await _confirmSensitiveEdit();
      if (!mounted) return;
      if (!ok) return;
    }

    final name = values['name'] as String;
    final techniqueId = values['techniqueId'] as String;
    final startDateValue = values['startDate'] as DateTime;
    final endDateValue = values['endDate'] as DateTime;
    if (endDateValue.isBefore(startDateValue)) {
      AppFeedback.show(
        context,
        message: 'A data fim deve ser igual ou posterior à data início.',
        type: AppFeedbackType.error,
      );
      return;
    }
    final kind = values['awardKind'] as String? ?? 'trophy';
    int? minDurationDays;
    if (kind == 'trophy') {
      minDurationDays = int.tryParse((values['minDurationDays'] as String?) ?? '30') ?? 30;
      final durationDays = endDateValue.difference(startDateValue).inDays;
      if (durationDays < minDurationDays) {
        AppFeedback.show(
          context,
          message: 'Troféu exige duração mínima de $minDurationDays dias. Período informado: $durationDays dias.',
          type: AppFeedbackType.error,
        );
        return;
      }
    }
    final targetCount = int.parse(values['targetCount'] as String);
    final minRewardLevelToUnlock =
        int.tryParse((values['minRewardLevelToUnlock'] as String?)?.trim() ?? '0') ??
            0;
    final minGraduationToUnlock = values['minGraduationToUnlock'] as String?;
    final startDate = toApiDate(startDateValue);
    final endDate = toApiDate(endDateValue);
    final maxCountRaw = (values['maxCountPerOpponent'] as String?)?.trim() ?? '';
    int? maxCountPerOpponent;
    if (maxCountRaw.isNotEmpty) {
      maxCountPerOpponent = int.tryParse(maxCountRaw);
      if (maxCountPerOpponent == null || maxCountPerOpponent < 1) {
        AppFeedback.show(
          context,
          message: 'Limite por adversário deve ser um inteiro ≥ 1 ou vazio.',
          type: AppFeedbackType.error,
        );
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Map<String, dynamic> map;
      if (widget.trophy == null) {
        map = await _api.createTrophy(
          academyId: widget.academyId,
          techniqueId: techniqueId,
          name: name.trim(),
          startDate: startDate,
          endDate: endDate,
          targetCount: targetCount,
          awardKind: kind,
          minDurationDays: kind == 'trophy' ? minDurationDays : null,
          minRewardLevelToUnlock:
              minRewardLevelToUnlock < 0 ? 0 : minRewardLevelToUnlock,
          minGraduationToUnlock:
              (minGraduationToUnlock != null && minGraduationToUnlock.isNotEmpty)
                  ? minGraduationToUnlock
                  : null,
          maxCountPerOpponent: maxCountPerOpponent,
        );
      } else {
        map = await _api.updateTrophy(
          widget.trophy!.id,
          techniqueId: techniqueId,
          name: name.trim(),
          startDate: startDate,
          endDate: endDate,
          targetCount: targetCount,
          awardKind: kind,
          minDurationDays: kind == 'trophy' ? minDurationDays : null,
          minRewardLevelToUnlock: minRewardLevelToUnlock,
          minGraduationToUnlock:
              (minGraduationToUnlock != null && minGraduationToUnlock.isNotEmpty)
                  ? minGraduationToUnlock
                  : null,
          maxCountPerOpponent: maxCountPerOpponent,
          setMaxCountPerOpponent: true,
        );
      }
      if (!mounted) return;
      final entity = TrophyMapper.toEntity(
        TrophyDto.fromJson(map, academyId: widget.academyId),
      );
      AppFeedback.show(
        context,
        message: widget.trophy == null ? 'Premiação criada.' : 'Alterações salvas.',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context, entity);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _saving = false;
        });
      }
    }
  }

  DateTime _parseStart() {
    final t = widget.trophy;
    if (t == null) return DateTime.now();
    try {
      return DateTime.parse(t.startDateIso.length >= 10 ? t.startDateIso.substring(0, 10) : t.startDateIso);
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _parseEnd() {
    final t = widget.trophy;
    if (t == null) return DateTime.now().add(const Duration(days: 30));
    try {
      return DateTime.parse(t.endDateIso.length >= 10 ? t.endDateIso.substring(0, 10) : t.endDateIso);
    } catch (_) {
      return DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trophy;
    final firstTech = _techniques.isNotEmpty ? _techniques.first.id : '';

    return Scaffold(
      appBar: AppStandardAppBar(
        title: t == null ? 'Novo troféu' : 'Editar troféu',
      ),
      body: _loadingTech
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FormBuilder(
                key: _formKey,
                initialValue: t == null
                    ? {
                        'name': '',
                        'techniqueId': firstTech,
                        'awardKind': 'medal',
                        'minDurationDays': '30',
                        'minRewardLevelToUnlock': '0',
                        'minGraduationToUnlock': null,
                        'startDate': DateTime.now(),
                        'endDate': DateTime.now().add(const Duration(days: 30)),
                        'targetCount': '10',
                        'maxCountPerOpponent': '',
                      }
                    : {
                        'name': t.name,
                        'techniqueId': t.techniqueId,
                        'awardKind': t.awardKind,
                        'minDurationDays': (t.minDurationDays ?? 30).toString(),
                        'minRewardLevelToUnlock':
                            t.minRewardLevelToUnlock.toString(),
                        'minGraduationToUnlock': t.minGraduationToUnlock,
                        'startDate': _parseStart(),
                        'endDate': _parseEnd(),
                        'targetCount': t.targetCount.toString(),
                        'maxCountPerOpponent': t.maxCountPerOpponent?.toString() ?? '',
                      },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormBuilderDropdown<String>(
                      name: 'awardKind',
                      decoration: const InputDecoration(labelText: 'Tipo de premiação'),
                      items: const [
                        DropdownMenuItem(value: 'medal', child: Text('Medalha (ordinária)')),
                        DropdownMenuItem(value: 'trophy', child: Text('Troféu (especial, longo prazo)')),
                      ],
                      onChanged: (v) {
                        setState(() => _awardKind = v ?? 'trophy');
                      },
                    ),
                    AppSpacing.verticalM,
                    if (_awardKind == 'trophy')
                      FormBuilderTextField(
                        name: 'minDurationDays',
                        decoration: const InputDecoration(
                          labelText: 'Duração mínima (dias)',
                          hintText: 'Ex: 30 (1 mês)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(errorText: 'Informe a duração mínima em dias'),
                          FormBuilderValidators.integer(errorText: 'Deve ser um número inteiro'),
                          FormBuilderValidators.min(1, errorText: 'Mínimo 1 dia'),
                        ]),
                      ),
                    if (_awardKind == 'trophy') AppSpacing.verticalM,
                    FormBuilderTextField(
                      name: 'name',
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'Ex: Arm Lock',
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Nome é obrigatório'),
                      ]),
                    ),
                    AppSpacing.verticalM,
                    FormBuilderDropdown<String>(
                      name: 'techniqueId',
                      decoration: const InputDecoration(labelText: 'Técnica'),
                      items: _techniques
                          .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
                          .toList(),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Selecione uma técnica'),
                      ]),
                    ),
                    AppSpacing.verticalM,
                    FormBuilderTextField(
                      name: 'minRewardLevelToUnlock',
                      decoration: const InputDecoration(
                        labelText: 'Nível para desbloquear',
                        hintText: '0 = sem exigência de nível',
                      ),
                      keyboardType: TextInputType.number,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.integer(errorText: 'Deve ser um número inteiro'),
                        FormBuilderValidators.min(0, errorText: 'Mínimo 0'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    FormBuilderDropdown<String?>(
                      name: 'minGraduationToUnlock',
                      decoration: const InputDecoration(
                        labelText: 'Faixa mínima para desbloquear',
                        hintText: 'Nenhuma = todos podem competir',
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Nenhuma')),
                        DropdownMenuItem(value: 'white', child: Text('Branca')),
                        DropdownMenuItem(value: 'blue', child: Text('Azul')),
                        DropdownMenuItem(value: 'purple', child: Text('Roxa')),
                        DropdownMenuItem(value: 'brown', child: Text('Marrom')),
                        DropdownMenuItem(value: 'black', child: Text('Preta')),
                      ],
                    ),
                    AppSpacing.verticalM,
                    FormBuilderDateTimePicker(
                      name: 'startDate',
                      inputType: InputType.date,
                      format: brDateFormat,
                      locale: const Locale('pt', 'BR'),
                      decoration: const InputDecoration(
                        labelText: 'Data início',
                        hintText: 'dd/MM/aaaa',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Data início é obrigatória'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    FormBuilderDateTimePicker(
                      name: 'endDate',
                      inputType: InputType.date,
                      format: brDateFormat,
                      locale: const Locale('pt', 'BR'),
                      decoration: const InputDecoration(
                        labelText: 'Data fim',
                        hintText: 'dd/MM/aaaa',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Data fim é obrigatória'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    FormBuilderTextField(
                      name: 'targetCount',
                      decoration: const InputDecoration(labelText: 'Meta de execuções (ex: 10)'),
                      keyboardType: TextInputType.number,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Meta é obrigatória'),
                        FormBuilderValidators.integer(errorText: 'Deve ser um número inteiro'),
                        FormBuilderValidators.min(1, errorText: 'Meta deve ser pelo menos 1'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    FormBuilderTextField(
                      name: 'maxCountPerOpponent',
                      decoration: const InputDecoration(
                        labelText: 'Máx. execuções contáveis por adversário (opcional)',
                        hintText: 'Vazio = padrão (sem limite; bronze = brancos distintos)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
