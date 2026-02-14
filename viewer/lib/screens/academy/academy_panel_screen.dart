import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/services/academy_service.dart';

/// Painel da academia: lista academias; ao tocar abre o detalhe (tema, ranking, dificuldades, relatório).
class AcademyPanelScreen extends StatefulWidget {
  const AcademyPanelScreen({super.key});

  @override
  State<AcademyPanelScreen> createState() => _AcademyPanelScreenState();
}

class _AcademyPanelScreenState extends State<AcademyPanelScreen> {
  final AcademyService _service = AcademyService();
  List<Academy> _academies = [];
  bool _loading = true;
  String? _error;

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
      final list = await _service.list();
      if (mounted) setState(() {
        _academies = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('AcademyServiceException: ', '');
      });
    }
  }

  Future<void> _openAcademy(Academy academy) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyDetailScreen(
          academy: academy,
          onUpdated: _load,
          onDeleted: () {
            Navigator.pop(context);
            _load();
          },
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _academies.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma academia cadastrada. Cadastre em Administração → Academias.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _academies.length,
                        itemBuilder: (context, i) {
                          final a = _academies[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.school, color: AppTheme.primary),
                              ),
                              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: (a.weeklyTechniqueName != null && a.weeklyTechniqueName!.isNotEmpty) ||
                                      (a.weeklyTheme != null && a.weeklyTheme!.isNotEmpty)
                                  ? Text(
                                      'Missão do dia: ${a.weeklyTechniqueName ?? a.weeklyTheme}',
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openAcademy(a),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
