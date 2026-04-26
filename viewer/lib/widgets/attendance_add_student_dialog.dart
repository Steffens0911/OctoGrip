import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Diálogo com busca e lista de alunos da academia para presença manual.
class AttendanceAddStudentDialog extends StatefulWidget {
  const AttendanceAddStudentDialog({
    super.key,
    required this.api,
    required this.academyId,
    required this.presentUserIds,
    required this.onPick,
  });

  final ApiService api;
  final String? academyId;
  final Set<String> presentUserIds;
  final Future<void> Function(String userId) onPick;

  @override
  State<AttendanceAddStudentDialog> createState() => _AttendanceAddStudentDialogState();
}

class _AttendanceAddStudentDialogState extends State<AttendanceAddStudentDialog> {
  static const int _usersQueryLimit = 200;

  final _search = TextEditingController();
  List<UserModel> _allStudents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    unawaited(_loadUsers());
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _allStudents.where((u) {
      if (q.isEmpty) return true;
      final name = (u.name ?? '').toLowerCase();
      return u.email.toLowerCase().contains(q) || name.contains(q);
    }).toList();
  }

  void _applyFilter() => setState(() {});

  Future<List<UserModel>> _fetchUsers() async {
    final academyId = widget.academyId?.trim();
    final hasAcademyId = academyId != null && academyId.isNotEmpty;
    try {
      return await widget.api.getUsers(
        academyId: hasAcademyId ? academyId : null,
        offset: 0,
        limit: _usersQueryLimit,
      );
    } on ApiException catch (e) {
      // Em "atuar como", alguns cenários retornam 403 para usuário efetivo.
      if (e.statusCode == 403 && AuthService().isRealUserAdmin) {
        return widget.api.getUsers(
          academyId: hasAcademyId ? academyId : null,
          asRealUser: true,
          offset: 0,
          limit: _usersQueryLimit,
        );
      }
      rethrow;
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final list = await _fetchUsers();
      final students = list.where((u) => u.role == 'aluno').toList();
      if (mounted) {
        setState(() {
          _allStudents = students;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar presença'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar aluno',
                hintText: 'Nome ou e-mail',
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade400,
                      ),
                ),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final u = _filtered[i];
                    final already = widget.presentUserIds.contains(u.id);
                    final name = (u.name ?? '').trim();
                    final title = name.isNotEmpty ? name : u.email;
                    return ListTile(
                      enabled: !already,
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: already
                          ? const Text('Já presente')
                          : Text(
                              u.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: already
                          ? null
                          : () => unawaited(widget.onPick(u.id)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        TextButton(onPressed: () => unawaited(_loadUsers()), child: const Text('Atualizar')),
      ],
    );
  }
}
