import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/screens/student/library_screen.dart';
import 'package:viewer/screens/student/progress_screen.dart';
import 'package:viewer/screens/student/report_difficulty_screen.dart';
import 'package:viewer/services/api_service.dart';

/// Tela inicial da área do aluno: seletor de usuário (MVP), missões da semana e atalhos.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _api = ApiService();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  MissionWeek? _missionWeek;
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
      _missionWeek = null;
    });
    try {
      final users = await _api.getUsers();
      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
        _loading = false;
      });
      if (_selectedUser != null) _loadMissionWeek();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMissionWeek() async {
    if (_selectedUser == null) return;
    setState(() => _error = null);
    try {
      final week = await _api.getMissionWeek(
        userId: _selectedUser!.id,
        academyId: _selectedUser!.academyId,
      );
      if (mounted) setState(() => _missionWeek = week);
    } catch (e) {
      if (mounted) setState(() => _missionWeek = null);
      if (e.toString().contains('404')) return;
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _openLesson(LessonViewData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewScreen(data: data),
      ),
    );
    _loadMissionWeek();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _users.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        if (_selectedUser != null) await _loadMissionWeek();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Área do aluno',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildUserSelector(),
            const SizedBox(height: 20),
            if (_missionWeek != null) _buildMissionWeekSection(),
            if (_missionWeek == null && !_loading && _selectedUser != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nenhuma missão da semana no momento.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            if (_missionWeek == null && _selectedUser != null) const SizedBox(height: 16),
            _buildShortcuts(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário (MVP)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<UserModel>(
              value: _selectedUser,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _users
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text('${u.name ?? u.email} (${u.email})'),
                      ))
                  .toList(),
              onChanged: (u) {
                setState(() {
                  _selectedUser = u;
                  _missionWeek = null;
                });
                _loadMissionWeek();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionWeekSection() {
    final entries = _missionWeek!.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Missões da semana',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...entries.map((slot) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMissionCard(slot.periodLabel, slot.mission),
            )),
      ],
    );
  }

  Widget _buildMissionCard(String periodLabel, MissionToday? m) {
    if (m == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.grey.shade400, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nenhuma missão neste período',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final data = LessonViewData(
      lessonId: m.lessonId,
      missionId: m.missionId,
      title: m.lessonTitle.isNotEmpty ? m.lessonTitle : m.techniqueName,
      description: m.description,
      videoUrl: m.videoUrl,
      userId: _selectedUser!.id,
      techniqueName: m.techniqueName,
      positionName: m.positionName,
      estimatedDurationSeconds: m.estimatedDurationSeconds,
      alreadyCompleted: m.alreadyCompleted,
    );
    return Card(
      child: InkWell(
        onTap: () => _openLesson(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      periodLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (m.alreadyCompleted)
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                m.missionTitle.isNotEmpty ? m.missionTitle : m.lessonTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (m.techniqueName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  m.techniqueName,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
              if (m.estimatedDurationSeconds != null && m.estimatedDurationSeconds! > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '~${m.estimatedDurationSeconds! ~/ 60} min',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openLesson(data),
                icon: Icon(m.alreadyCompleted ? Icons.visibility : Icons.play_arrow, size: 20),
                label: Text(m.alreadyCompleted ? 'Ver novamente' : 'Começar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcuts() {
    if (_selectedUser == null) return const SizedBox.shrink();
    final userId = _selectedUser!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShortcutTile(
          icon: Icons.menu_book,
          title: 'Biblioteca de lições',
          subtitle: 'Ver todas as lições',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LibraryScreen(userId: userId),
            ),
          ),
        ),
        _ShortcutTile(
          icon: Icons.trending_up,
          title: 'Meu progresso',
          subtitle: 'Todas as missões cumpridas',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProgressScreen(userId: userId),
            ),
          ),
        ),
        _ShortcutTile(
          icon: Icons.warning_amber_rounded,
          title: 'Reportar dificuldade',
          subtitle: 'Marcar posição difícil no treino',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDifficultyScreen(userId: userId),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
