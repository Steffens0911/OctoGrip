import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/face_recognition.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class ReviewFaceResultsScreen extends StatefulWidget {
  final String sessionId;
  final String jobId;

  const ReviewFaceResultsScreen({
    super.key,
    required this.sessionId,
    required this.jobId,
  });

  @override
  State<ReviewFaceResultsScreen> createState() =>
      _ReviewFaceResultsScreenState();
}

class _ReviewFaceResultsScreenState extends State<ReviewFaceResultsScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  FaceRecognitionJobStatusModel? _job;
  final Set<String> _confirmedStudentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final job = await _api.getFaceRecognitionJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
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
        _error = userFacingMessage(e);
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

  Uint8List? _decodeBase64(String base64Input) {
    if (base64Input.isEmpty) return null;
    try {
      return base64Decode(base64Input);
    } catch (_) {
      return null;
    }
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
          onRetry: _load,
        ),
      );
    }
    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.empty(
          message: 'Nenhum resultado disponível para este job.',
          onRetry: _load,
        ),
      );
    }
    if (job.status != 'completed') {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Revisar reconhecimento'),
        body: AppScreenState.empty(
          message: 'Processamento em andamento (status: ${job.status}).',
          onRetry: _load,
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
          Text('Identificados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (auto.isEmpty)
            const Text('Nenhum aluno identificado automaticamente.')
          else
            ...auto.map((r) => _buildItem(r, initiallyChecked: true)),
          const SizedBox(height: 16),
          Text('Confirmar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            const Text('Nenhuma sugestão para conferência.')
          else
            ...suggestions.map((r) => _buildItem(r, initiallyChecked: false)),
          const SizedBox(height: 16),
          Text('Não identificados',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${unknown.length} rostos não foram identificados. Verifique se todos os alunos têm foto cadastrada.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
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
