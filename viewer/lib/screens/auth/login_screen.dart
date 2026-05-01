import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/branding/app_brand.dart';
import 'package:viewer/config.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/network_diagnostics_service.dart';
import 'package:viewer/screens/debug/network_diagnostics_screen.dart';
import 'package:viewer/utils/api_base_persist.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_error_message.dart';

/// Tela de login com e-mail e senha (Memo / Central: superfície, borda fina, acento primário).
/// A senha pode ser mostrada ou ocultada com o ícone ao lado do campo (sem segunda confirmação).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiTunnelController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiTunnelController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final muted = AppTheme.textMutedOf(context);
    final r = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      prefixIcon: Icon(icon, color: muted, size: 22),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.55)),
      border: OutlineInputBorder(borderRadius: r),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _login() async {
    if (_loading || kApiBaseUrl.isEmpty) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final api = ApiService();
      final result = await api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await AuthService().setLoggedIn(result.token, result.user);
      if (mounted && result.streakBonusPoints > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+${result.streakBonusPoints} pts — bônus por dias seguidos de login!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      NetworkDiagnosticsService.recordError(
        e,
        stackTrace: st,
        context: 'Login',
      );
      if (mounted) {
        setState(() => _error = userFacingMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardBg = theme.cardTheme.color ?? cs.surfaceContainerHighest;
    final cardBorder = AppTheme.borderOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cardBorder.withValues(alpha: 0.95),
                  ),
                  boxShadow: theme.brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          AppBrand.logoAsset,
                          width: 192,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Entre com sua conta',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMutedOf(context),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (kApiBaseUrl.isEmpty) ...[
                        const SizedBox(height: 20),
                        const AppErrorMessage(
                          message: kWebTrycloudflareMissingApiBaseMessage,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiTunnelController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                          decoration: _fieldDecoration(
                            context,
                            label: 'URL do túnel da API',
                            hint: 'https://….trycloudflare.com',
                            icon: Icons.link,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            final u = _apiTunnelController.text.trim();
                            if (u.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cole a URL do cloudflared da API.'),
                                ),
                              );
                              return;
                            }
                            if (!u.startsWith('https://') && !u.startsWith('http://')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('A URL deve começar com https:// ou http://'),
                                ),
                              );
                              return;
                            }
                            persistApiBaseAndReload(u);
                          },
                          style: FilledButton.styleFrom(
                            foregroundColor: AppTheme.textPrimaryOf(context),
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                          child: const Text('Salvar URL da API e recarregar'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                        decoration: _fieldDecoration(
                          context,
                          label: 'E-mail',
                          hint: 'seu@email.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                          return validateEmail(v);
                        },
                        enabled: !_loading && kApiBaseUrl.isNotEmpty,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                        decoration: _fieldDecoration(
                          context,
                          label: 'Senha',
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textMutedOf(context),
                              size: 22,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Informe a senha';
                          return null;
                        },
                        enabled: !_loading && kApiBaseUrl.isNotEmpty,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        AppErrorMessage(message: _error!),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NetworkDiagnosticsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.health_and_safety_rounded),
                            label: const Text('Abrir diagnóstico técnico'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _loading || kApiBaseUrl.isEmpty
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ?? false) {
                                  _login();
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          disabledBackgroundColor:
                              cs.primary.withValues(alpha: 0.45),
                          disabledForegroundColor:
                              cs.onPrimary.withValues(alpha: 0.55),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.6,
                          ),
                        ),
                        child: _loading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
