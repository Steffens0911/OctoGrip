import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/academy/academy_panel_screen.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';
import 'package:viewer/screens/student/student_home_screen.dart';
import 'package:viewer/services/theme_service.dart';

void main() {
  runApp(const ViewerApp());
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({super.key});

  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    ThemeService.load().then((mode) {
      if (mounted) setState(() => _themeMode = mode);
    });
  }

  void _cycleTheme(BuildContext context) {
    final resolved = Theme.of(context).brightness;
    setState(() => _themeMode = ThemeService.next(_themeMode, resolved));
    ThemeService.save(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JJB Viewer',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: MainShell(onThemeToggle: _cycleTheme),
    );
  }
}

/// Shell principal: navegação estilo Lovable.
class MainShell extends StatefulWidget {
  final void Function(BuildContext context) onThemeToggle;

  const MainShell({super.key, required this.onThemeToggle});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;
  int _inicioRefreshKey = 0;

  static const _titles = ['Início', 'Painel', 'Administração'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selected.clamp(0, _titles.length - 1)]),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => widget.onThemeToggle(context),
            tooltip: 'Alternar tema',
          ),
        ],
      ),
      body: _selected == 0
          ? StudentHomeScreen(refreshTrigger: _inicioRefreshKey)
          : _selected == 1
              ? const AcademyPanelScreen()
              : const AdminSectionScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Início',
                  selected: _selected == 0,
                  onTap: () => setState(() {
                    _selected = 0;
                    _inicioRefreshKey++;
                  }),
                ),
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Painel',
                  selected: _selected == 1,
                  onTap: () => setState(() => _selected = 1),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Admin',
                  selected: _selected == 2,
                  onTap: () => setState(() => _selected = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected ? AppTheme.primary : AppTheme.textMutedOf(context),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.primary : AppTheme.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
