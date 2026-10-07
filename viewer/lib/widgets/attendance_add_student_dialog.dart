import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy_student_list_item.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

/// Acento mint (chamada / print de referência).
const Color _kAccentGreen = Color(0xFF4ECF8A);

/// Modal de presença manual na chamada (multi-selecção).
///
/// Lista qualquer pessoa vinculada à academia, não só alunos — o critério de
/// presença é o vínculo com a academia, não o papel.
class AttendanceAddStudentDialog extends StatefulWidget {
  const AttendanceAddStudentDialog({
    super.key,
    required this.api,
    required this.academyId,
    required this.presentUserIds,
    required this.onConfirm,
  });

  final ApiService api;
  final String academyId;
  final Set<String> presentUserIds;

  /// Devolve os registos criados (vazio se todos já estavam presentes).
  final Future<List<AttendanceRecordModel>> Function(List<String> studentIds)
      onConfirm;

  @override
  State<AttendanceAddStudentDialog> createState() =>
      _AttendanceAddStudentDialogState();
}

class _AttendanceAddStudentDialogState extends State<AttendanceAddStudentDialog> {
  final _search = TextEditingController();
  List<AcademyStudentListItem> _allStudents = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String? _loadError;
  String? _submitError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    unawaited(_loadStudents());
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list =
          await widget.api.getAcademyStudentsListAll(widget.academyId.trim());
      final filtered = list
          .where((s) => !widget.presentUserIds.contains(s.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _allStudents = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = userFacingMessage(e);
      });
    }
  }

  List<AcademyStudentListItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _allStudents;
    return _allStudents.where((s) {
      final name = (s.name ?? '').toLowerCase();
      final role = (s.role ?? '').trim();
      final roleLabel = role.isEmpty ? '' : _roleLabel(role).toLowerCase();
      return name.contains(q) || (roleLabel.isNotEmpty && roleLabel.contains(q));
    }).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _submitError = null;
    });
  }

  String _beltLabel(String? belt) {
    if (belt == null || belt.isEmpty) return 'Sem faixa';
    switch (belt.toLowerCase()) {
      case 'white':
        return 'Faixa branca';
      case 'blue':
        return 'Faixa azul';
      case 'purple':
        return 'Faixa roxa';
      case 'brown':
        return 'Faixa marrom';
      case 'black':
        return 'Faixa preta';
      default:
        return belt;
    }
  }

  /// Rótulo do papel — só exibido para quem não é aluno.
  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'professor':
        return 'Professor';
      case 'gerente_academia':
        return 'Gerente';
      case 'supervisor':
        return 'Supervisor';
      case 'administrador':
        return 'Administrador';
      default:
        return role;
    }
  }

  /// Linha secundária: faixa para alunos; papel (+ faixa, se houver) para o resto.
  /// "Sem faixa" só faz sentido para aluno — para um gerente seria ruído.
  String _subtitle(AcademyStudentListItem s) {
    final role = (s.role ?? '').trim().toLowerCase();
    if (role.isEmpty || role == 'aluno') return _beltLabel(s.belt);
    final label = _roleLabel(role);
    final belt = (s.belt ?? '').trim();
    return belt.isEmpty ? label : '$label · ${_beltLabel(belt)}';
  }

  String _initials(AcademyStudentListItem s) {
    final n = (s.name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final a = parts[0];
      final b = parts[1];
      final ca = a.isNotEmpty ? a[0] : '';
      final cb = b.isNotEmpty ? b[0] : '';
      return ('$ca$cb').toUpperCase();
    }
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final created = await widget.onConfirm(_selectedIds.toList());
      if (!mounted) return;
      if (created.isEmpty) {
        AppFeedback.show(
          context,
          message:
              'Nenhuma presença nova — as pessoas selecionadas já estavam presentes.',
          type: AppFeedbackType.warning,
        );
      } else {
        AppFeedback.show(
          context,
          message: 'Presença registada.',
          type: AppFeedbackType.success,
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF252b3b) : AppTheme.surfaceOf(context);
    final borderColor = AppTheme.borderOf(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_submitting) return;
          Navigator.of(context).pop();
        },
      },
      child: Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
          height:
              (MediaQuery.sizeOf(context).height * 0.72).clamp(400.0, 620.0),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adicionar presença',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selecione uma ou mais pessoas',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  enabled: !_submitting && !_loading && _loadError == null,
                  decoration: InputDecoration(
                    hintText: 'Buscar pessoa...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1e2435) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.error),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _submitting ? null : () => unawaited(_loadStudents()),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_allStudents.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: 48, color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(height: 12),
                          Text(
                            'Todos já estão presentes',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma pessoa encontrada',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final s = _filtered[i];
                              final selected = _selectedIds.contains(s.id);
                              final title = (s.name ?? '').trim().isNotEmpty
                                  ? s.name!.trim()
                                  : s.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: selected
                                      ? _kAccentGreen.withValues(alpha: 0.14)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap:
                                        _submitting ? null : () => _toggleSelection(s.id),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          if (selected)
                                            Container(
                                              width: 4,
                                              height: 56,
                                              decoration: const BoxDecoration(
                                                color: _kAccentGreen,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(9),
                                                  bottomLeft: Radius.circular(9),
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: selected ? 8 : 12,
                                                right: 8,
                                                top: 8,
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  _StudentAvatar(
                                                    api: widget.api,
                                                    avatarUrl: s.avatarUrl,
                                                    initials: _initials(s),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          title,
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.w600,
                                                                color: selected
                                                                    ? _kAccentGreen
                                                                    : AppTheme
                                                                        .textPrimaryOf(
                                                                            context),
                                                              ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          _subtitle(s),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    AppTheme.textSecondaryOf(
                                                                        context),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Checkbox(
                                                    value: selected,
                                                    activeColor: _kAccentGreen,
                                                    checkColor: const Color(0xFF1e2435),
                                                    side: BorderSide(color: borderColor),
                                                    onChanged: _submitting
                                                        ? null
                                                        : (_) =>
                                                            _toggleSelection(s.id),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                _AttendanceDialogFooter(
                  selectedCount: _selectedIds.length,
                  submitting: _submitting,
                  confirmEnabled: !_submitting &&
                      _selectedIds.isNotEmpty &&
                      !_loading &&
                      _loadError == null,
                  onCancel: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  onConfirm:
                      (_submitting || _selectedIds.isEmpty || _loading || _loadError != null)
                          ? null
                          : () => unawaited(_submit()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rodapé do modal: em ecrãs estreitos empilha os botões para evitar overflow horizontal.
class _AttendanceDialogFooter extends StatelessWidget {
  const _AttendanceDialogFooter({
    required this.selectedCount,
    required this.submitting,
    required this.confirmEnabled,
    required this.onCancel,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool submitting;
  final bool confirmEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  static const double _narrowMaxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final narrow =
        MediaQuery.sizeOf(context).width < _narrowMaxWidth;

    final selection = selectedCount > 0
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$selectedCount selecionado(s)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _kAccentGreen,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final cancelButton = OutlinedButton(
      onPressed: onCancel,
      child: const Text('Cancelar'),
    );

    final confirmButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _kAccentGreen,
        foregroundColor: const Color(0xFF1e2435),
      ),
      onPressed: confirmEnabled ? onConfirm : null,
      child: submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text('Confirmar presença'),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        selection,
        if (narrow) ...[
          cancelButton,
          const SizedBox(height: 8),
          confirmButton,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: cancelButton),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: confirmButton),
            ],
          ),
      ],
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.api,
    required this.avatarUrl,
    required this.initials,
  });

  final ApiService api;
  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final raw = avatarUrl?.trim();
    final uri = raw != null && raw.isNotEmpty
        ? (raw.startsWith('/') ? Uri.parse('${api.baseUrl}$raw') : Uri.tryParse(raw))
        : null;

    return CircleAvatar(
      radius: 22,
      backgroundColor: _kAccentGreen.withValues(alpha: 0.2),
      foregroundImage:
          uri != null ? NetworkImage(uri.toString()) : null,
      child: uri == null
          ? Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _kAccentGreen,
                fontSize: 14,
              ),
            )
          : null,
    );
  }
}
