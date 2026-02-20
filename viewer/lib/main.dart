import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/screens/academy/academy_panel_screen.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';
import 'package:viewer/screens/auth/login_screen.dart';
import 'package:viewer/screens/student/student_home_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().init();
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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: AuthGate(onThemeToggle: _cycleTheme),
    );
  }
}

/// Gate: mostra LoginScreen ou MainShell conforme autenticação.
class AuthGate extends StatefulWidget {
  final void Function(BuildContext context) onThemeToggle;

  const AuthGate({super.key, required this.onThemeToggle});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  void _onAuthChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AuthService().onSessionInvalidated = _onAuthChange;
  }

  @override
  void dispose() {
    AuthService().onSessionInvalidated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().isLoggedIn) {
      return MainShell(
        onThemeToggle: widget.onThemeToggle,
        onLogout: () async {
          await AuthService().logout();
          if (mounted) _onAuthChange();
        },
      );
    }
    return LoginScreen(onLoginSuccess: _onAuthChange);
  }
}

/// Shell principal: navegação estilo Lovable.
class MainShell extends StatefulWidget {
  final void Function(BuildContext context) onThemeToggle;
  final VoidCallback onLogout;

  const MainShell({super.key, required this.onThemeToggle, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;
  int _inicioRefreshKey = 0;

  final _auth = AuthService();

  List<String> get _availableTabs {
    final role = _auth.currentUser?.role ?? 'aluno';
    if (role == 'aluno') {
      return ['Início'];
    } else if (role == 'administrador') {
      return ['Início', 'Painel', 'Administração'];
    } else {
      // professor, gerente_academia, supervisor
      return ['Início', 'Painel'];
    }
  }

  int get _maxIndex => _availableTabs.length - 1;

  String get _currentTitle {
    if (_selected >= _availableTabs.length) {
      return _availableTabs[0];
    }
    return _availableTabs[_selected];
  }

  Widget get _currentBody {
    final role = _auth.currentUser?.role ?? 'aluno';
    
    if (_selected == 0) {
      return StudentHomeScreen(refreshTrigger: _inicioRefreshKey);
    } else if (_selected == 1) {
      if (role == 'administrador') {
        return const AcademyPanelScreen();
      } else {
        return const AcademyPanelScreen();
      }
    } else if (_selected == 2) {
      return const AdminSectionScreen();
    }
    return StudentHomeScreen(refreshTrigger: _inicioRefreshKey);
  }

  @override
  void initState() {
    super.initState();
    AuthService().onImpersonationChange = () => setState(() { _inicioRefreshKey++; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selected > _maxIndex) {
        setState(() => _selected = 0);
      }
      AuthService().restoreImpersonation();
    });
  }

  @override
  void dispose() {
    AuthService().onImpersonationChange = null;
    super.dispose();
  }

  void _showImpersonateDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atuar como'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<UserModel>>(
            future: ApiService().getUsers(asRealUser: true),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar usuários: ${snapshot.error}');
              }
              final users = snapshot.data ?? [];
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Sair da simulação'),
                      leading: const Icon(Icons.person_off_outlined),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AuthService().setImpersonating(null);
                      },
                    ),
                    const Divider(),
                    ...users.map((u) => ListTile(
                      title: Text(u.name ?? u.email),
                      subtitle: Text(u.email),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AuthService().setImpersonating(u.id);
                      },
                    )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _auth.currentUser?.role ?? 'aluno';
    final tabs = _availableTabs;
    final isImpersonating = _auth.isImpersonating;
    final effectiveUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        actions: [
          if (_auth.isRealUserAdmin)
            IconButton(
              icon: const Icon(Icons.person_search_rounded),
              onPressed: _showImpersonateDialog,
              tooltip: 'Atuar como',
            ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => widget.onThemeToggle(context),
            tooltip: 'Alternar tema',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: widget.onLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Column(
        children: [
          if (isImpersonating && effectiveUser != null)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atuando como: ${effectiveUser.name ?? effectiveUser.email} (${effectiveUser.email})',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => AuthService().setImpersonating(null),
                        child: const Text('Sair da simulação'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: _currentBody),
        ],
      ),
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
                if (tabs.contains('Início'))
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Início',
                    selected: _selected == 0,
                    onTap: () => setState(() {
                      _selected = 0;
                      _inicioRefreshKey++;
                    }),
                  ),
                if (tabs.contains('Painel'))
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Painel',
                    selected: _selected == 1,
                    onTap: () => setState(() => _selected = 1),
                  ),
                if (tabs.contains('Administração'))
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
