import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy_student_list_item.dart';
import 'package:viewer/models/face_recognition.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class ReviewFaceResultsScreen extends StatefulWidget {
  final String sessionId;
  final String jobId;
  final String? academyId;

  const ReviewFaceResultsScreen({
    super.key,
    required this.sessionId,
    required this.jobId,
    this.academyId,
  });

  @override
  State<ReviewFaceResultsScreen> createState() =>
      _ReviewFaceResultsScreenState();
}

class _ReviewFaceResultsScreenState extends State<ReviewFaceResultsScreen> {
  final _api = ApiService();

  /// Reconsulta o estado do job enquanto estiver pending/processing (fila Celery).
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPollAttempts = 90;

  Timer? _pollTimer;
  int _pollAttempts = 0;
  bool _hasReceivedJobOnce = false;

  bool _loading = true;
  bool _saving = false;
  bool _loadingStudents = false;
  String? _error;
  FaceRecognitionJobStatusModel? _job;
  final Set<String> _confirmedStudentIds = <String>{};
  List<AcademyStudentListItem> _students = [];
  final Map<int, String> _unknownAssignments = {};

  /// Sugestões (baixa confiança): confirmar checkbox e/ou escolher outro aluno na busca.
  final Map<int, String> _suggestionManualPick = {};
  final Map<int, bool> _suggestionUseSuggested = {};
  final Map<int, String?> _prevSuggestionEff = {};

  /// Pré-visualização da foto enviada (só conferência; vem da API como JPEG base64).
  Uint8List? _trainingPhotoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool manualRetry = false}) async {
    if (manualRetry) {
      _pollAttempts = 0;
      _pollTimer?.cancel();
    }

    if (!_hasReceivedJobOnce || manualRetry) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final job = await _api.getFaceRecognitionJob(widget.jobId);
      if (!mounted) return;

      _pollTimer?.cancel();

      if (job.status == 'failed') {
        setState(() {
          _loading = false;
          _hasReceivedJobOnce = true;
          _job = job;
          _trainingPhotoBytes = null;
          _error = job.errorMessage?.trim().isNotEmpty == true
              ? job.errorMessage
              : 'O processamento da foto falhou. Tente enviar outra imagem.';
        });
        return;
      }

      if (job.status == 'pending' || job.status == 'processing') {
        _pollAttempts++;
        if (_pollAttempts > _maxPollAttempts) {
          setState(() {
            _loading = false;
            _hasReceivedJobOnce = true;
            _job = job;
            _trainingPhotoBytes = null;
            _error =
                'O processamento ultrapassou o tempo esperado (vários minutos). '
                'O trabalho em segundo plano (Celery) pode não estar a correr ou não consegue falar com o Redis. '
                'Confirme que o contentor celery-worker está ativo, que REDIS_URL é igual na API e no worker e '
                'que FACE_JOBS_DIR está no mesmo volume partilhado (ver README / docs/DEPLOY_COOLIFY_CONTABO.md).';
          });
          return;
        }

        setState(() {
          _loading = false;
          _hasReceivedJobOnce = true;
          _job = job;
          _trainingPhotoBytes = null;
        });
        _pollTimer = Timer(_pollInterval, () {
          if (mounted) _load();
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
        _hasReceivedJobOnce = true;
        _trainingPhotoBytes =
            _decodeTrainingPhotoPreview(job.referencePhotoBase64);
        _suggestionManualPick.clear();
        _suggestionUseSuggested.clear();
        _prevSuggestionEff.clear();
        _confirmedStudentIds
          ..clear()
          ..addAll(
            job.results
                .where(
                    (r) => r.status == 'auto_identified' && r.student != null)
                .map((r) => r.student!.id),
          );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasReceivedJobOnce = true;
        _trainingPhotoBytes = null;
        _error = userFacingMessage(e);
      });
      return;
    }

    final aid = widget.academyId;
    if (aid != null && aid.isNotEmpty) {
      setState(() => _loadingStudents = true);
      _api.getAcademyStudentsListAll(aid).then((list) {
        if (!mounted) return;
        setState(() {
          _students = list;
          _loadingStudents = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _loadingStudents = false);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _api.confirmFaceRecognition(
        sessionId: widget.sessionId,
        jobId: widget.jobId,
        confirmedStudentIds: _confirmedStudentIds.toList(),
      );
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Presenças salvas com sucesso.',
        type: AppFeedbackType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  void _onUnknownAssigned(int faceIndex, String? studentId) {
    setState(() {
      final prev = _unknownAssignments[faceIndex];
      if (prev != null) _confirmedStudentIds.remove(prev);
      if (studentId != null) {
        _unknownAssignments[faceIndex] = studentId;
        _confirmedStudentIds.add(studentId);
      } else {
        _unknownAssignments.remove(faceIndex);
      }
    });
  }

  void _syncSuggestionFace(int faceIndex, FaceRecognitionResultModel r) {
    final sug = r.student?.id;
    if (sug == null) return;
    final manual = _suggestionManualPick[faceIndex];
    final use = _suggestionUseSuggested[faceIndex] ?? false;
    final next = manual ?? (use ? sug : null);
    final prev = _prevSuggestionEff[faceIndex];
    if (prev == next) return;
    if (prev != null) _confirmedStudentIds.remove(prev);
    if (next != null) _confirmedStudentIds.add(next);
    _prevSuggestionEff[faceIndex] = next;
  }

  void _onSuggestionToggleSuggested(
      int faceIndex, FaceRecognitionResultModel r, bool value) {
    setState(() {
      _suggestionUseSuggested[faceIndex] = value;
      _syncSuggestionFace(faceIndex, r);
    });
  }

  void _onSuggestionManualPick(
      int faceIndex, FaceRecognitionResultModel r, String? studentId) {
    setState(() {
      if (studentId == null || studentId.isEmpty) {
        _suggestionManualPick.remove(faceIndex);
      } else {
        _suggestionManualPick[faceIndex] = studentId;
        _suggestionUseSuggested[faceIndex] = false;
      }
      _syncSuggestionFace(faceIndex, r);
    });
  }

  Uint8List? _decodeBase64(String base64Input) {
    if (base64Input.isEmpty) return null;
    try {
      return base64Decode(base64Input);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeTrainingPhotoPreview(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    return _decodeBase64(b64);
  }

  Widget _buildTrainingPhotoSection(BuildContext context) {
    final bytes = _trainingPhotoBytes;
    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();

    final maxH = MediaQuery.sizeOf(context).height * 0.38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foto do treino',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Apenas para conferência neste ecrã.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(FaceRecognitionResultModel result,
      {required bool initiallyChecked}) {
    final student = result.student;
    final studentId = student?.id;
    final selected =
        studentId != null && _confirmedStudentIds.contains(studentId);
    final canToggle = studentId != null;
    final crop = _decodeBase64(result.faceCropBase64);
    final confidenceLabel = '${(result.confidence * 100).toStringAsFixed(0)}%';
    final confidenceColor = result.status == 'auto_identified'
        ? Colors.green
        : result.status == 'suggestion'
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: crop == null
            ? const CircleAvatar(child: Icon(Icons.person_outline))
            : CircleAvatar(backgroundImage: MemoryImage(crop)),
        title: Text(student?.name ?? 'Não identificado'),
        subtitle: Text(
          [
            if (student?.belt != null && student!.belt!.isNotEmpty)
              'Faixa ${student.belt}',
            'Confiança $confidenceLabel',
          ].join(' · '),
        ),
        trailing: canToggle
            ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _confirmedStudentIds.add(studentId);
                    } else {
                      _confirmedStudentIds.remove(studentId);
                    }
                  });
                },
              )
            : Chip(
                label: const Text('Unknown'),
                backgroundColor: confidenceColor.withValues(alpha: 0.15),
              ),
        onTap: canToggle
            ? () {
                setState(() {
                  if (selected) {
                    _confirmedStudentIds.remove(studentId);
                  } else {
                    _confirmedStudentIds.add(studentId);
                  }
                });
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.loading(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.error(
          message: _error!,
          onRetry: () => _load(manualRetry: true),
        ),
      );
    }
    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.empty(
          message: 'Nenhum resultado disponível para este job.',
          onRetry: () => _load(manualRetry: true),
        ),
      );
    }

    if (job.status == 'pending' || job.status == 'processing') {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.screenPadding(context) * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'A processar a foto…',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Estado: ${job.status}. Isto costuma levar poucos segundos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => _load(manualRetry: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recarregar agora'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (job.status != 'completed') {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.empty(
          message: 'Estado inesperado: ${job.status}.',
          onRetry: () => _load(manualRetry: true),
        ),
      );
    }

    final auto =
        job.results.where((r) => r.status == 'auto_identified').toList();
    final suggestions =
        job.results.where((r) => r.status == 'suggestion').toList();
    final unknown = job.results.where((r) => r.status == 'unknown').toList();

    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.screenPadding(context),
          AppTheme.screenPadding(context),
          AppTheme.screenPadding(context),
          96,
        ),
        children: [
          _buildTrainingPhotoSection(context),
          Text('Identificados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (auto.isEmpty)
            const Text('Nenhum aluno identificado automaticamente.')
          else
            ...auto.map((r) => _buildItem(r, initiallyChecked: true)),
          const SizedBox(height: 16),
          if (_loadingStudents &&
              (suggestions.isNotEmpty || unknown.isNotEmpty))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          Text('Confirmar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            const Text('Nenhuma sugestão para conferência.')
          else ...[
            Text(
              'Confira a sugestão ou busque outro aluno para este rosto.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 8),
            ...suggestions.map(
              (r) => _SuggestionFaceItem(
                result: r,
                students: _students,
                useSuggested: _suggestionUseSuggested[r.faceIndex] ?? false,
                manualStudentId: _suggestionManualPick[r.faceIndex],
                decodeBase64: _decodeBase64,
                onToggleSuggested: (v) =>
                    _onSuggestionToggleSuggested(r.faceIndex, r, v),
                onManualPick: (sid) =>
                    _onSuggestionManualPick(r.faceIndex, r, sid),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Não identificados',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (unknown.isNotEmpty)
            Text(
              '${unknown.length} rosto${unknown.length > 1 ? 's' : ''} não ${unknown.length > 1 ? 'foram' : 'foi'} identificado${unknown.length > 1 ? 's' : ''} automaticamente. '
              'Selecione o aluno correspondente ou deixe em branco.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            )
          else
            Text(
              'Nenhum rosto desconhecido.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          if (unknown.isNotEmpty) const SizedBox(height: 8),
          ...unknown.map(
            (r) => _UnknownFaceItem(
              result: r,
              students: _students,
              assignedStudentId: _unknownAssignments[r.faceIndex],
              onAssigned: (sid) => _onUnknownAssigned(r.faceIndex, sid),
              decodeBase64: _decodeBase64,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Salvar presenças (${_confirmedStudentIds.length} alunos)'),
        ),
      ),
    );
  }
}

class _SuggestionFaceItem extends StatefulWidget {
  const _SuggestionFaceItem({
    required this.result,
    required this.students,
    required this.useSuggested,
    required this.manualStudentId,
    required this.decodeBase64,
    required this.onToggleSuggested,
    required this.onManualPick,
  });

  final FaceRecognitionResultModel result;
  final List<AcademyStudentListItem> students;
  final bool useSuggested;
  final String? manualStudentId;
  final Uint8List? Function(String) decodeBase64;
  final ValueChanged<bool> onToggleSuggested;
  final ValueChanged<String?> onManualPick;

  @override
  State<_SuggestionFaceItem> createState() => _SuggestionFaceItemState();
}

class _SuggestionFaceItemState extends State<_SuggestionFaceItem> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _labelForId(widget.manualStudentId));
  }

  @override
  void didUpdateWidget(_SuggestionFaceItem old) {
    super.didUpdateWidget(old);
    if (old.manualStudentId != widget.manualStudentId) {
      final next = _labelForId(widget.manualStudentId);
      if (_ctrl.text != next) {
        _ctrl.text = next;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _labelForId(String? id) {
    if (id == null) return '';
    final s = widget.students.where((s) => s.id == id).firstOrNull;
    return s != null ? _studentLabel(s) : '';
  }

  String _studentLabel(AcademyStudentListItem s) {
    final belt =
        (s.belt != null && s.belt!.isNotEmpty) ? ' · Faixa ${s.belt}' : '';
    return '${s.name ?? ''}$belt';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final student = r.student;
    final crop = widget.decodeBase64(r.faceCropBase64);
    final confidenceLabel = '${(r.confidence * 100).toStringAsFixed(0)}%';
    final blockedByManual = widget.manualStudentId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            crop == null
                ? const CircleAvatar(child: Icon(Icons.person_outline))
                : CircleAvatar(backgroundImage: MemoryImage(crop)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (student?.name != null &&
                          student!.name!.trim().isNotEmpty)
                        student.name!.trim(),
                      if (student?.belt != null &&
                          student!.belt!.trim().isNotEmpty)
                        'Faixa ${student.belt}',
                      'Confiança $confidenceLabel',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      blockedByManual
                          ? 'Sugestão (substituída pela busca)'
                          : 'Confirmar esta sugestão',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: blockedByManual ? false : widget.useSuggested,
                    onChanged: blockedByManual
                        ? null
                        : (v) =>
                            widget.onToggleSuggested(v ?? false),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<AcademyStudentListItem>(
                    textEditingController: _ctrl,
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return widget.students.take(8);
                      return widget.students
                          .where((s) =>
                              (s.name?.toLowerCase().contains(q) ?? false))
                          .take(8);
                    },
                    displayStringForOption: _studentLabel,
                    onSelected: (picked) {
                      widget.onManualPick(picked.id);
                    },
                    fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: widget.students.isEmpty
                              ? 'Carregando alunos...'
                              : 'Buscar aluno…',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: ctrl.text.isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    ctrl.clear();
                                    widget.onManualPick(null);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) {
                          if (v.isEmpty) widget.onManualPick(null);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnknownFaceItem extends StatefulWidget {
  final FaceRecognitionResultModel result;
  final List<AcademyStudentListItem> students;
  final String? assignedStudentId;
  final ValueChanged<String?> onAssigned;
  final Uint8List? Function(String) decodeBase64;

  const _UnknownFaceItem({
    required this.result,
    required this.students,
    required this.assignedStudentId,
    required this.onAssigned,
    required this.decodeBase64,
  });

  @override
  State<_UnknownFaceItem> createState() => _UnknownFaceItemState();
}

class _UnknownFaceItemState extends State<_UnknownFaceItem> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _labelForId(widget.assignedStudentId));
  }

  @override
  void didUpdateWidget(_UnknownFaceItem old) {
    super.didUpdateWidget(old);
    // Sincronizar se o pai limpou a atribuição externamente
    if (old.assignedStudentId != widget.assignedStudentId &&
        widget.assignedStudentId == null &&
        _ctrl.text.isNotEmpty) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _labelForId(String? id) {
    if (id == null) return '';
    final s = widget.students.where((s) => s.id == id).firstOrNull;
    return s != null ? _studentLabel(s) : '';
  }

  String _studentLabel(AcademyStudentListItem s) {
    final belt = (s.belt != null && s.belt!.isNotEmpty) ? ' · Faixa ${s.belt}' : '';
    return '${s.name ?? ''}$belt';
  }

  @override
  Widget build(BuildContext context) {
    final crop = widget.decodeBase64(widget.result.faceCropBase64);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            crop == null
                ? const CircleAvatar(child: Icon(Icons.person_outline))
                : CircleAvatar(backgroundImage: MemoryImage(crop)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não identificado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<AcademyStudentListItem>(
                    textEditingController: _ctrl,
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return widget.students.take(8);
                      return widget.students
                          .where((s) =>
                              (s.name?.toLowerCase().contains(q) ?? false))
                          .take(8);
                    },
                    displayStringForOption: _studentLabel,
                    onSelected: (student) {
                      widget.onAssigned(student.id);
                    },
                    fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: widget.students.isEmpty
                              ? 'Carregando alunos...'
                              : 'Buscar aluno...',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: ctrl.text.isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    ctrl.clear();
                                    widget.onAssigned(null);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) {
                          if (v.isEmpty) widget.onAssigned(null);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
