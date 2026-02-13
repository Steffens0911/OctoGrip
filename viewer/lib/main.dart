import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/home_screen.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';

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

/// Shell principal: drawer com Início e Administração.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected == 0 ? 'JJB' : 'Administração'),
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
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Administração'),
              selected: _selected == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selected = 1);
              },
            ),
          ],
        ),
      ),
      body: _selected == 0 ? const HomeScreen() : const AdminSectionScreen(),
    );
  }
}
