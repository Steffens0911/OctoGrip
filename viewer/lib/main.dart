import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/widgets/game_background.dart';
import 'package:viewer/screens/academy/academy_panel_screen.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';
import 'package:viewer/screens/auth/login_screen.dart';
import 'package:viewer/screens/student/student_home_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AuthService().init();
  runApp(
    ProviderScope(
      child: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: const ViewerApp(),
      ),
    ),
  );
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({super.key});

  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  /// Padrão escuro até carregar preferência (login e primeiro frame).
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useGameFont = true;

  @override
  void initState() {
    super.initState();
    ThemeService.load().then((mode) {
      if (mounted) setState(() => _themeMode = mode);
    });
    ThemeService.loadUseGameFont().then((useGameFont) {
      if (mounted) setState(() => _useGameFont = useGameFont);
    });
  }

  /// Alterna entre temas claro/escuro/sistema usando ThemeService.
  /// Usa o brilho atual da plataforma quando o modo é "system" para alternar
  /// de fato entre claro e escuro.
  Future<void> _cycleTheme(BuildContext context) async {
    final resolvedBrightness = MediaQuery.platformBrightnessOf(context);
    setState(() {
      _themeMode = ThemeService.next(_themeMode, resolvedBrightness);
    });
    await ThemeService.save(_themeMode);
  }

  Future<void> _cycleFont() async {
    setState(() => _useGameFont = !_useGameFont);
    await ThemeService.saveUseGameFont(_useGameFont);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JJB Viewer',
      theme: _useGameFont ? AppTheme.memoLight : AppTheme.memoLightSans,
      darkTheme: _useGameFont ? AppTheme.memoDark : AppTheme.memoDarkSans,
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
      home: AuthGate(
        onThemeToggle: _cycleTheme,
        onFontToggle: _cycleFont,
      ),
    );
  }
}

/// Gate: mostra LoginScreen ou MainShell conforme autenticação via Provider.
class AuthGate extends StatelessWidget {
  final void Function(BuildContext context) onThemeToggle;
  final VoidCallback onFontToggle;

  const AuthGate({
    super.key,
    required this.onThemeToggle,
    required this.onFontToggle,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isLoggedIn) {
      return MainShell(
        onThemeToggle: onThemeToggle,
        onFontToggle: onFontToggle,
        onLogout: () async {
          await auth.logout();
        },
      );
    }
    return const LoginScreen();
  }
}

/// Shell principal: navegação estilo Lovable com Provider para estado de auth.
class MainShell extends StatefulWidget {
  final void Function(BuildContext context) onThemeToggle;
  final VoidCallback onFontToggle;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.onThemeToggle,
    required this.onFontToggle,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;
  int _inicioRefreshKey = 0;
  String? _lastEffectiveUserId;
  /// Último contador vindo da [StudentHomeScreen] (badge na aba Missões).
  int _pendingConfirmationsNavBadge = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService().restoreImpersonation();
    });
  }

  List<String> _availableTabs(AuthService auth) {
    final role = auth.currentUser?.role ?? 'aluno';
    if (role == 'administrador') {
      return ['Missões', 'Painel', 'Admin'];
    }
    return ['Missões', 'Painel'];
  }

  Widget _missionsHome() {
    return StudentHomeScreen(
      refreshTrigger: _inicioRefreshKey,
      onPendingConfirmationsCountChanged: (count) {
        if (!mounted) return;
        setState(() => _pendingConfirmationsNavBadge = count);
      },
    );
  }

  Widget _currentBody(AuthService auth, List<String> tabs) {
    if (_selected == 0) {
      return _missionsHome();
    } else if (_selected == 1) {
      return const AcademyPanelScreen();
    } else if (_selected == 2) {
      return const AdminSectionScreen();
    }
    return _missionsHome();
  }

  void _showImpersonateDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atuar como'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity, maxHeight: 400),
          child: FutureBuilder<({List<UserModel> users, List<Academy> academies})>(
            future: () async {
              final users = await ApiService().getUsers(asRealUser: true);
              List<Academy> academies = [];
              try {
                academies = await ApiService().getAcademies(asRealUser: true);
              } catch (_) {}
              return (users: users, academies: academies);
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar: ${snapshot.error}');
              }
              final data = snapshot.data!;
              return _ImpersonateDialogContent(
                users: data.users,
                academies: data.academies,
                onSelect: (userId) async {
                  Navigator.pop(ctx);
                  await AuthService().setImpersonating(userId);
                },
                onExitSimulation: () async {
                  Navigator.pop(ctx);
                  await AuthService().setImpersonating(null);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tabs = _availableTabs(auth);
    final isImpersonating = auth.isImpersonating;
    final effectiveUser = auth.currentUser;
    final effectiveId = effectiveUser?.id;
    if (effectiveId != _lastEffectiveUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
          _lastEffectiveUserId = effectiveId;
          _inicioRefreshKey++;
          _pendingConfirmationsNavBadge = 0;
        });
        }
      });
    }

    if (_selected >= tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = 0);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected < tabs.length ? tabs[_selected] : tabs[0]),
        actions: [
          if (auth.isRealUserAdmin)
            IconButton(
              icon: const Icon(Icons.person_search_rounded),
              onPressed: _showImpersonateDialog,
              tooltip: 'Atuar como',
            ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: widget.onFontToggle,
            tooltip: 'Alternar fonte',
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => widget.onThemeToggle(context),
            tooltip: 'Alternar tema claro/escuro',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: widget.onLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: GameBackground(
        child: Column(
          children: [
            if (isImpersonating && effectiveUser != null)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atuando como: ${effectiveUser.name ?? effectiveUser.email}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                effectiveUser.email,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
            Expanded(child: _currentBody(auth, tabs)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
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
                if (tabs.contains('Missões'))
                  _NavItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Missões',
                    selected: _selected == 0,
                    badgeCount: _pendingConfirmationsNavBadge > 0
                        ? _pendingConfirmationsNavBadge
                        : null,
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
                if (tabs.contains('Admin'))
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
  /// Se não nulo e > 0, exibe [Badge] no ícone (ex.: confirmações pendentes).
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    Widget iconWidget = Icon(
      icon,
      size: 24,
      color: selected ? primary : onSurfaceVariant,
    );
    final bc = badgeCount;
    if (bc != null && bc > 0) {
      iconWidget = Badge(
        label: Text(
          bc > 99 ? '99+' : '$bc',
          style: const TextStyle(fontSize: 10),
        ),
        child: iconWidget,
      );
    }
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
              color: selected ? primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? primary : onSurfaceVariant,
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

class _ImpersonateDialogContent extends StatefulWidget {
  final List<UserModel> users;
  final List<Academy> academies;
  final void Function(String userId) onSelect;
  final VoidCallback onExitSimulation;

  const _ImpersonateDialogContent({
    required this.users,
    required this.academies,
    required this.onSelect,
    required this.onExitSimulation,
  });

  @override
  State<_ImpersonateDialogContent> createState() => _ImpersonateDialogContentState();
}

class _ImpersonateDialogContentState extends State<_ImpersonateDialogContent> {
  String _filterText = '';
  String? _selectedAcademyId;

  List<UserModel> get _filteredUsers {
    var list = widget.users;
    if (_selectedAcademyId != null && _selectedAcademyId!.isNotEmpty) {
      list = list.where((u) => u.academyId == _selectedAcademyId).toList();
    }
    final query = _filterText.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((u) {
        final name = (u.name ?? '').toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Sair da simulação'),
            leading: const Icon(Icons.person_off_outlined),
            onTap: widget.onExitSimulation,
          ),
          const Divider(),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nome ou e-mail',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (v) => setState(() => _filterText = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _selectedAcademyId,
            decoration: const InputDecoration(
              labelText: 'Academia',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
              ...widget.academies.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
            ],
            onChanged: (v) => setState(() => _selectedAcademyId = v),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nenhum usuário encontrado.',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            )
          else
            ...filtered.map((u) => ListTile(
                  title: Text(u.name ?? u.email),
                  subtitle: Text(u.email),
                  onTap: () => widget.onSelect(u.id),
                )),
        ],
      ),
    );
  }
}
