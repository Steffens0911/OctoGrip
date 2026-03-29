import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/config.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/game_background.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/api_base_persist.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_error_message.dart';

/// Tela de login com e-mail e senha.
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiTunnelController.dispose();
    super.dispose();
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
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      const Icon(
                      Icons.sports_martial_arts_rounded,
                      size: 64,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                      'JJB Viewer',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                      'Entre com sua conta',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMutedOf(context),
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
                          decoration: const InputDecoration(
                            labelText: 'URL do túnel da API',
                            hintText: 'https://….trycloudflare.com',
                            prefixIcon: Icon(Icons.link),
                            border: OutlineInputBorder(),
                            isDense: true,
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
                          child: const Text('Guardar URL da API e recarregar'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'seu@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
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
                      const SizedBox(height: 20),
                      FilledButton(
                      onPressed: _loading || kApiBaseUrl.isEmpty
                          ? null
                          : () {
                        if (_formKey.currentState?.validate() ?? false) _login();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      ),
    );
  }
}
