import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/academy/attendance_frequency_screen.dart';
import 'package:viewer/screens/academy/attendance_history_screen.dart';
import 'package:viewer/screens/academy/attendance_session_screen.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AcademyAttendanceHubScreen extends StatelessWidget {
  const AcademyAttendanceHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(
        title: 'Chamada e frequência',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.qr_code_rounded, color: AppTheme.primary),
              ),
              title: const Text(
                'Chamada (QR)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Iniciar chamada e ver presenças em tempo real'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceSessionScreen()),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.history_rounded, color: AppTheme.primary),
              ),
              title: const Text(
                'Histórico de chamadas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ver sessões, corrigir presenças (adicionar ou remover)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.insights_rounded, color: AppTheme.primary),
              ),
              title: const Text(
                'Frequência',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Minhas sessões no período e frequência dos alunos da academia'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceFrequencyScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

