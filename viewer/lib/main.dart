import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/academy/academy_panel_screen.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';
import 'package:viewer/screens/student/student_home_screen.dart';

void main() {
  runApp(const ViewerApp());
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JJB Viewer',
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}

/// Shell principal: drawer com Início, Painel da academia e Administração.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;

  static const _titles = ['JJB', 'Painel da academia', 'Administração'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selected.clamp(0, _titles.length - 1)]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _selected == 0 ? null : () => setState(() => _selected = 0),
                    child: const Text('Início'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _selected == 1 ? null : () => setState(() => _selected = 1),
                    child: const Text('Painel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _selected == 2 ? null : () => setState(() => _selected = 2),
                    child: const Text('Admin'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primary),
              child: Text(
                'JJB',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Início'),
              selected: _selected == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selected = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Painel da academia'),
              selected: _selected == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selected = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Administração'),
              selected: _selected == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selected = 2);
              },
            ),
          ],
        ),
      ),
      body: _selected == 0
          ? const StudentHomeScreen()
          : _selected == 1
              ? const AcademyPanelScreen()
              : const AdminSectionScreen(),
    );
  }
}
