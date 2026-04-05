import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/config.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/api_base_persist.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_error_message.dart';

/// Tela de login com e-mail e senha (layout landing escuro + wordmark Flow Roll).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _pageBg = Color(0xFF1E1D2B);
  static const Color _cardBg = Color(0xFF262433);
  static const Color _cardBorder = Color(0xFF3A384E);
  static const Color _fieldFill = Color(0xFF323046);
  static const Color _textMuted = Color(0xFFB4B0C8);
  static const Color _textOnField = Color(0xFFEAE8F2);
  static const Color _ctaGold = Color(0xFFF5CA3A);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiTunnelController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiTunnelController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    final r = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: Icon(icon, color: _textMuted, size: 22),
      labelStyle: const TextStyle(color: _textMuted),
      hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.55)),
      border: OutlineInputBorder(borderRadius: r),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: _cardBorder.withValues(alpha: 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
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
      AuthService().setLoggedIn(result.token, result.user);
      if (mounted && result.streakBonusPoints > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+${result.streakBonusPoints} pts — bónus por dias seguidos de login!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
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
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _cardBorder.withValues(alpha: 0.9)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/branding/flowroll_wordmark.png',
                          width: 220,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Entre com sua conta',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _textMuted,
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
                          style: const TextStyle(color: _textOnField),
                          decoration: _fieldDecoration(
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
                                  content: Text('A URL deve começar por https:// ou http://'),
                                ),
                              );
                              return;
                            }
                            persistApiBaseAndReload(u);
                          },
                          style: FilledButton.styleFrom(
                            foregroundColor: _textOnField,
                            backgroundColor: _fieldFill,
                          ),
                          child: const Text('Guardar URL da API e recarregar'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: _textOnField),
                        decoration: _fieldDecoration(
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
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        style: const TextStyle(color: _textOnField),
                        decoration: _fieldDecoration(
                          label: 'Senha',
                          icon: Icons.lock_outline,
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
                          backgroundColor: _ctaGold,
                          foregroundColor: const Color(0xFF1A1A1A),
                          disabledBackgroundColor: _ctaGold.withValues(alpha: 0.45),
                          disabledForegroundColor: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
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
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF1A1A1A),
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
