import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Tela para editar o ajuste de pontos dos alunos de uma academia.
class AcademyPointsEditScreen extends StatefulWidget {
  final String academyId;
  final String academyName;

  const AcademyPointsEditScreen({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  @override
  State<AcademyPointsEditScreen> createState() =>
      _AcademyPointsEditScreenState();
}

class _AcademyPointsEditScreenState extends State<AcademyPointsEditScreen> {
  final _api = ApiService();
  List<UserModel> _users = [];
  final Map<String, int> _points = {};
  final Map<String, TextEditingController> _adjustmentControllers = {};
  bool _loading = true;
  String? _error;
  final Set<String> _savingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _adjustmentControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _api.getUsers(academyId: widget.academyId);
      for (final u in users) {
        _adjustmentControllers[u.id] = TextEditingController(
          text: (u.pointsAdjustment).toString(),
        );
      }
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
      final pointsByUser = await _api.getAcademyUserPoints(widget.academyId);
      if (mounted) {
        setState(() {
          _points.clear();
          _points.addAll(pointsByUser);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveAdjustment(UserModel user) async {
    final ctrl = _adjustmentControllers[user.id];
    if (ctrl == null) return;
    final val = int.tryParse(ctrl.text.trim()) ?? 0;
    setState(() => _savingIds.add(user.id));
    try {
      await _api.updateUser(user.id, pointsAdjustment: val);
      final data = await _api.getUserPoints(user.id);
      if (mounted) {
        setState(() {
          _savingIds.remove(user.id);
          _points[user.id] = data['points'] as int? ?? 0;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajuste salvo')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _savingIds.remove(user.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userFacingMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar pontos dos alunos'),
            Text(
              widget.academyName,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum aluno nesta academia.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final total = _points[u.id] ?? 0;
                          final ctrl = _adjustmentControllers[u.id];
                          final saving = _savingIds.contains(u.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.name ?? u.email,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Total: $total pts',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Ajuste',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.save),
                                    onPressed: saving
                                        ? null
                                        : () => _saveAdjustment(u),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
